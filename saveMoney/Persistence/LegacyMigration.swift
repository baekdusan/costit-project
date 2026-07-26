import Foundation
import SwiftData
import CryptoKit
import WidgetKit

// UserDefaults(PropertyListEncoder 기반)에 저장되어 있던 기존 데이터를
// SwiftData로 이전한다. 멱등(idempotent)하게 동작:
//   - 레거시 데이터의 fingerprint(SHA256)가 마지막 이전 시점과 같으면 즉시 종료
//   - 다르면 다시 실행 — 레코드 단위 dedup(externalID + 내용 비교)이라 중복 생성 없음
//   - 실패해도 원본 UserDefaults 데이터는 보존 (rollback 안전망)
//   - 성공 후 즉시 UserDefaults를 삭제하지 않음 (사용자 1~2 버전 후 정리)
//
// fingerprint 방식인 이유: 과거 1회성 bool 플래그(v1)는 "테스트 빌드 설치 → 구버전으로
// 복귀 후 데이터 추가 → 다시 업데이트" 시나리오에서 플래그가 이미 켜져 있어
// 구버전에서 추가된 데이터가 영영 이전되지 않는 버그가 있었다.
enum LegacyMigration {
    private enum Keys {
        static let finList = "finlist"
        static let rFinList = "rfinList"
        static let fixedFinList = "fixedFinList"
        static let profile = "profile"
        static let salaryData = "salarydata"

        static let fingerprint = "migration.userdefaults_to_swiftdata.fingerprint"
    }

    // 이전 로직의 버전. fingerprint에 함께 섞으므로, 이 값을 올리면 모든 기기가 한 번 더 이전한다.
    // 디코더나 dedup 규칙을 고쳐서 "예전에 못 옮긴 데이터를 다시 시도해야 할 때"만 올린다.
    //
    // 디코딩이 실패했다고 매 실행 재시도하지 않는 이유: 삭제 tombstone이 없어 "사용자가 지운 지출"과
    // "아직 이전되지 않은 지출"을 구분할 수 없다. 재이전이 반복되면 사용자가 지운 내역이 계속
    // 되살아난다 — 깨진 blob은 어차피 같은 코드로는 못 읽으므로 재시도해도 결과가 같다.
    private static let logicVersion = "v1"

    // 이전 단계의 결과. 두 실패를 구분하는 것이 핵심이다:
    //  - decodeFailed: blob 자체를 못 읽음. 같은 코드로 재시도해도 결과가 같으므로 완료로 기록한다
    //    (기록하지 않으면 매 실행 재이전이 돌아 사용자가 지운 지출이 되살아난다).
    //  - aborted: 기존 레코드 조회 실패처럼 다음 실행에서 성공할 수 있는 중단. 완료로 기록하면
    //    원본이 UserDefaults에 남아 있는데도 레거시 데이터가 영영 이전되지 않는다.
    private struct Outcome {
        var decodeFailed = false
        var aborted = false

        mutating func merge(_ other: Outcome) {
            decodeFailed = decodeFailed || other.decodeFailed
            aborted = aborted || other.aborted
        }
    }

    static func runIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        let current = legacyFingerprint(defaults)
        guard defaults.string(forKey: Keys.fingerprint) != current else { return }

        // 마이그레이션 작업은 background context에서 처리.
        let context = ModelContext(container)

        do {
            var outcome = Outcome()
            outcome.merge(migrateFinList(key: Keys.finList, isRevenue: false, into: context, defaults: defaults))
            outcome.merge(migrateFinList(key: Keys.rFinList, isRevenue: true, into: context, defaults: defaults))
            outcome.merge(migrateFixedExpenditures(into: context, defaults: defaults))
            // 프로필/정산기간의 디코딩 실패는 재시도 대상에서 뺀다. 이 둘 때문에 fingerprint 기록을
            // 막으면 매 실행마다 지출 목록 전체가 재이전되는데, 삭제 tombstone이 없어 "사용자가 지운
            // 지출"과 "아직 이전되지 않은 지출"을 구분할 수 없다 → 지운 내역이 계속 되살아난다.
            // 프로필·급여일은 온보딩/프로필 수정으로 언제든 복구되지만 지출 부활은 되돌릴 수 없다.
            // (단 조회 실패로 인한 중단은 아래 aborted로 따로 전달된다)
            outcome.aborted = migrateProfile(into: context, defaults: defaults).aborted || outcome.aborted
            outcome.aborted = migrateSalaryPeriod(into: context, defaults: defaults).aborted || outcome.aborted

            try context.save()

            // fingerprint를 기록하면 다음 실행부터 guard에 걸려 재시도하지 않는다.
            // 따라서 "다시 시도하면 결과가 달라질 수 있는" 실패에서는 기록하지 않는다:
            //  - aborted: 기존 레코드 조회 실패 등 일시적 오류로 이번 이전을 건너뛴 경우.
            //    기록해버리면 레거시 지출이 원본은 남아 있는데도 영영 이전되지 않는다.
            //  - isEphemeralFallback: 스토어를 못 열어 in-memory로 동작 중 → 이전 결과가 앱 종료와
            //    함께 사라지는데 완료로 기록하면 마찬가지로 영영 이전되지 않는다.
            //
            // 반면 디코딩 실패(decodeFailed)는 기록을 막지 않는다. 막으면 매 실행 전량 재이전이 돌고
            // 사용자가 지운 지출이 실행마다 되살아난다. 깨진 blob은 같은 코드로 다시 읽어도 결과가
            // 같으므로, 재시도는 디코더를 고친 버전에서 logicVersion을 올려 수행한다.
            if outcome.aborted || PersistenceController.isEphemeralFallback {
                print("[LegacyMigration] 이번 이전을 완료로 확정하지 않음(aborted=\(outcome.aborted), ephemeral=\(PersistenceController.isEphemeralFallback)) — 다음 실행에서 재시도")
            } else {
                if outcome.decodeFailed {
                    print("[LegacyMigration] 일부 blob 디코딩 실패 — 완료로 기록(재시도는 logicVersion 상향 시)")
                }
                defaults.set(current, forKey: Keys.fingerprint)
            }

            // 위젯이 표시하는 지출·프로필·정산 기간이 방금 채워졌으므로 타임라인을 갱신한다
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // 실패 시 컨텍스트만 폐기. UserDefaults는 그대로 → 다음 실행에서 재시도.
            print("[LegacyMigration] 실패: \(error)")
        }
    }

    // 레거시 UserDefaults 데이터 전체의 SHA256. 어떤 키든 내용이 바뀌면 값이 달라진다.
    private static func legacyFingerprint(_ defaults: UserDefaults) -> String {
        var hasher = SHA256()
        // 로직 버전을 함께 섞는다 — 이 값을 올리면 레거시 데이터가 그대로여도 fingerprint가 달라져
        // 모든 기기가 한 번 더 이전을 시도한다(디코더·dedup 규칙을 고쳤을 때의 재시도 경로)
        hasher.update(data: Data("logic:\(logicVersion);".utf8))
        for key in [Keys.finList, Keys.rFinList, Keys.fixedFinList, Keys.profile, Keys.salaryData] {
            let data = defaults.data(forKey: key) ?? Data()
            // 키 이름 + 길이를 prefix로 넣어 blob 경계 모호성 제거
            hasher.update(data: Data("\(key):\(data.count);".utf8))
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 안전 디코딩

    // 손상된 항목 1건이 배열 전체 디코딩을 실패시키지 않도록 항목 단위로 감싸서 디코딩
    private struct Failable<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    // 최상위 blob 디코딩 실패와 개별 항목 손상을 구분해서 알린다.
    // 전자는 포맷 불일치처럼 "다음 버전에서 고쳐 다시 시도할 수 있는" 실패라 재시도 여지를 남겨야 하고,
    // 후자는 재시도해도 같은 결과라 건너뛴다.
    private static func decodeList<T: Decodable>(_ type: T.Type, from data: Data) -> (values: [T], failed: Bool) {
        guard let wrapped = try? PropertyListDecoder().decode([Failable<T>].self, from: data) else {
            print("[LegacyMigration] \(T.self) 목록 전체 디코딩 실패 (\(data.count) bytes)")
            return ([], true)
        }
        let values = wrapped.compactMap(\.value)
        if values.count < wrapped.count {
            print("[LegacyMigration] 손상된 항목 \(wrapped.count - values.count)건 건너뜀 (\(T.self))")
        }
        return (values, false)
    }

    // MARK: - Decoders for legacy types

    // 과거 모델은 IUO/Optional 혼재. UserDefaults에는 PropertyListEncoder로 저장됐고,
    // CodingKeys는 when/towhat/how, id/day/towhat/how, nickName/outLay/period, startDate/endDate.
    private struct LegacyFin: Codable {
        var when: Date
        var towhat: String
        var how: Int

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            when = try c.decode(Date.self, forKey: .when)
            towhat = try c.decode(String.self, forKey: .towhat)
            how = try c.decodeIfPresent(Int.self, forKey: .how) ?? 0
        }

        enum CodingKeys: String, CodingKey { case when, towhat, how }
    }

    private struct LegacyFixed: Codable {
        var id: String
        var day: Int
        var towhat: String
        var how: Int

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            day = try c.decodeIfPresent(Int.self, forKey: .day) ?? 1
            towhat = try c.decodeIfPresent(String.self, forKey: .towhat) ?? ""
            how = try c.decodeIfPresent(Int.self, forKey: .how) ?? 0
        }

        enum CodingKeys: String, CodingKey { case id, day, towhat, how }
    }

    // 합성 Decodable은 키가 하나만 없어도 통째로 throw한다(프로퍼티 기본값을 쓰지 않음).
    // 구버전이 period 없이 저장한 blob 하나 때문에 목표 지출액·급여일이 통째로 유실되므로
    // LegacyFin/LegacyFixed와 동일하게 decodeIfPresent 기반으로 관대하게 읽는다.
    private struct LegacyProfile: Codable {
        var nickName: String = "User"
        var outLay: Int = 0
        var period: String = SalaryDay.firstDay

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            nickName = try c.decodeIfPresent(String.self, forKey: .nickName) ?? "User"
            outLay = try c.decodeIfPresent(Int.self, forKey: .outLay) ?? 0
            period = try c.decodeIfPresent(String.self, forKey: .period) ?? SalaryDay.firstDay
        }

        enum CodingKeys: String, CodingKey { case nickName, outLay, period }
    }

    // 한쪽 날짜만 읽혀도 기간 정보를 버리지 않는다 — 빠진 쪽은 rollover가 곧 교정한다.
    private struct LegacySalary: Codable {
        var startDate: Date
        var endDate: Date

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let start = try c.decodeIfPresent(Date.self, forKey: .startDate)
            let end = try c.decodeIfPresent(Date.self, forKey: .endDate)
            guard start != nil || end != nil else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "startDate/endDate 모두 없음")
                )
            }
            startDate = start ?? Date().startOfThisMonth
            endDate = end ?? Date().endOfThisMonth
        }

        enum CodingKeys: String, CodingKey { case startDate, endDate }
    }

    // MARK: - Migration steps

    // 같은 레거시 레코드는 어느 기기에서 이전해도 같은 externalID를 갖는다.
    // → CloudKit으로 두 기기가 각자 마이그레이션해도 externalID 기준 dedup 가능.
    private static func legacyID(for item: LegacyFin, isRevenue: Bool) -> String {
        "legacy:\(isRevenue ? "r" : "e"):\(Int(item.when.timeIntervalSince1970)):\(item.how):\(item.towhat)"
    }

    // 내용 기반 매칭 키. 소수초를 버린 시각을 쓰는 이유는 legacyID가 초 단위이기 때문 —
    // 소수초를 포함한 채 이전된 구버전 레코드와 절삭해서 저장하는 현재 레코드가
    // 서로 다른 키가 되면 재실행 때 같은 지출이 두 건으로 늘어난다.
    private static func contentKey(when: Date, towhat: String, how: Int) -> String {
        "\(Int(when.timeIntervalSince1970)):\(how):\(towhat)"
    }

    // 반환값: 최상위 디코딩 실패 여부 (true면 이번 이전을 "완료"로 확정하면 안 됨)
    private static func migrateFinList(key: String, isRevenue: Bool, into context: ModelContext, defaults: UserDefaults) -> Outcome {
        guard let data = defaults.data(forKey: key) else { return Outcome() }
        let decoded = decodeList(LegacyFin.self, from: data)
        if decoded.failed { return Outcome(decodeFailed: true, aborted: false) }

        // 기존 레코드를 한 번만 읽어 메모리에서 대조한다. 과거엔 레코드마다 fetch를 돌렸는데,
        // externalID에 인덱스가 없고(CloudKit 제약) predicate가 OR 복합이라 사실상 매번 전체
        // 스캔이었다 — 수천 건을 가진 사용자는 첫 실행이 didFinishLaunching에서 수 초간
        // 블로킹되어 런치 워치독에 걸릴 수 있었다.
        // fetch 실패를 빈 배열로 삼키면 안 된다 — 인덱스와 usedIDs가 비어 dedup 근거를 잃고,
        // 이미 이전된 레코드 전량이 같은 externalID로 다시 삽입된다(중복 + 식별키 충돌).
        // 읽지 못했으면 이번 실행을 완료로 확정하지 않고 다음 실행에서 재시도한다.
        guard let existing = try? context.fetch(FetchDescriptor<FinDataEntity>(
            predicate: #Predicate { $0.isRevenue == isRevenue }
        )) else {
            print("[LegacyMigration] 기존 \(isRevenue ? "수입" : "지출") 조회 실패 — 이번 이전 건너뜀")
            return Outcome(decodeFailed: false, aborted: true)
        }

        var idIndex: [String: [Int]] = [:]
        var contentIndex: [String: [Int]] = [:]
        for (offset, entity) in existing.enumerated() {
            idIndex[entity.externalID, default: []].append(offset)
            contentIndex[contentKey(when: entity.when, towhat: entity.towhat, how: entity.how), default: []].append(offset)
        }

        // 이미 이전된 레코드는 "하나씩 소진"한다. 단순히 존재 여부만 보면 같은 날 같은 금액으로
        // 두 번 적은 지출("커피 4500" ×2)이 한 건으로 합쳐져 유실된다.
        var consumed = Set<Int>()
        func claim(_ candidates: [Int]?) -> Bool {
            guard let candidates else { return false }
            for offset in candidates where !consumed.contains(offset) {
                consumed.insert(offset)
                return true
            }
            return false
        }

        // externalID는 앱 전체가 "레코드 하나를 가리키는 키"로 쓴다 —
        // AddFinView의 편집(externalID로 fetch)과 PersistenceController.deleteFin이 모두 .first를 집는다.
        // legacyID는 내용에서 파생되므로, 같은 내용의 레거시 레코드를 claim()으로 둘 다 살리면
        // externalID가 겹쳐 "A를 수정했는데 B가 바뀌고, B를 지웠는데 A가 지워지는" 상태가 된다.
        // → 이미 쓰인 ID면 순번을 붙여 유일성을 지킨다. (첫 건은 기존 legacyID 그대로라 호환)
        var usedIDs = Set(existing.map(\.externalID))
        func uniqueID(from base: String) -> String {
            guard usedIDs.contains(base) else {
                usedIDs.insert(base)
                return base
            }
            var seq = 2
            while usedIDs.contains("\(base)#\(seq)") { seq += 1 }
            let id = "\(base)#\(seq)"
            usedIDs.insert(id)
            return id
        }

        for item in decoded.values {
            let extID = legacyID(for: item, isRevenue: isRevenue)
            // externalID 매칭이 먼저 — 이전 후 사용자가 앱에서 수정한 레코드가 원본으로 되살아나지 않게.
            // 내용 매칭은 과거 dual-write 기간(FinRepository)에 UUID externalID로 저장된 동일 레코드용.
            if claim(idIndex[extID]) { continue }
            if claim(contentIndex[contentKey(when: item.when, towhat: item.towhat, how: item.how)]) { continue }

            // 기간 경계(23:59:59)와 소수초 때문에 어느 정산 기간에도 속하지 않는 레코드가
            // 생기지 않도록, 저장 경로(AddFinView)와 동일하게 소수초를 버린다
            context.insert(FinDataEntity(
                when: item.when.truncatingSubseconds,
                towhat: item.towhat,
                how: item.how,
                isRevenue: isRevenue,
                externalID: uniqueID(from: extID)
            ))
        }
        return Outcome()
    }

    private static func migrateFixedExpenditures(into context: ModelContext, defaults: UserDefaults) -> Outcome {
        guard let data = defaults.data(forKey: Keys.fixedFinList) else { return Outcome() }
        let decoded = decodeList(LegacyFixed.self, from: data)
        if decoded.failed { return Outcome(decodeFailed: true, aborted: false) }

        // 지출 목록과 같은 이유로 기존 레코드는 한 번만 읽는다.
        // 조회 실패를 빈 결과로 삼키면 dedup 근거를 잃고 고정지출 전량이 같은 externalID로
        // 다시 삽입되므로, 실패하면 이번 이전을 건너뛰고 다음 실행에서 재시도한다.
        guard let existingFixed = try? context.fetch(FetchDescriptor<FixedExpenditureEntity>()) else {
            print("[LegacyMigration] 기존 고정지출 조회 실패 — 이번 이전 건너뜀")
            return Outcome(decodeFailed: false, aborted: true)
        }
        let existingIDs = Set(existingFixed.map(\.externalID))

        var insertedIDs = Set<String>()
        for item in decoded.values {
            let extID = item.id
            if existingIDs.contains(extID) || insertedIDs.contains(extID) { continue }
            insertedIDs.insert(extID)

            context.insert(FixedExpenditureEntity(
                externalID: item.id,
                day: item.day,
                towhat: item.towhat,
                how: item.how
            ))
        }
        return Outcome()
    }

    // 반환값: 최상위 디코딩 실패 여부 (migrateFinList와 동일 — true면 fingerprint를 기록하지 않아
    // 다음 버전에서 다시 시도할 수 있다. 프로필 blob만 손상된 사용자가 목표 지출액·급여일을
    // 영영 되찾지 못하는 것을 막는다)
    private static func migrateProfile(into context: ModelContext, defaults: UserDefaults) -> Outcome {
        // 기존 ProfileEntity가 이미 있으면 skip.
        // 조회 실패(throw)를 try?로 삼켜 "없음"으로 취급하면 안 된다 — 이미 프로필이 있는데도
        // 레거시 사본을 하나 더 만들고, canonical이 그 사본을 고르면 사용자가 설정한 예산·급여일이
        // 옛 값으로 되돌아가 이전 기간 지출이 화면에서 사라진다.
        var descriptor = FetchDescriptor<ProfileEntity>()
        descriptor.fetchLimit = 1
        guard let existing = try? context.fetch(descriptor) else {
            print("[LegacyMigration] 기존 프로필 조회 실패 — 이번 이전 건너뜀")
            return Outcome(decodeFailed: false, aborted: true)
        }
        if existing.first != nil { return Outcome() }

        // 레거시 프로필이 없으면 아무것도 만들지 않는다.
        // 과거엔 기본값(“User”/0원/“1일”) 프로필을 무조건 삽입했는데, 그 결과
        //  (a) 신규 설치에서도 프로필이 존재해 온보딩 표시 판정이 망가지고
        //  (b) 기기 교체 시 CloudKit에서 내려올 진짜 프로필과 중복되어, 정렬 없는 .first가
        //      더미를 골라 사용자의 목표 지출액·급여일이 사라진 것처럼 보였다.
        guard let data = defaults.data(forKey: Keys.profile) else { return Outcome() }
        guard let legacy = try? PropertyListDecoder().decode(LegacyProfile.self, from: data) else {
            print("[LegacyMigration] 프로필 디코딩 실패 (\(data.count) bytes)")
            return Outcome(decodeFailed: true, aborted: false)
        }

        context.insert(ProfileEntity(
            nickName: legacy.nickName,
            outLay: legacy.outLay,
            period: legacy.period
        ))
        return Outcome()
    }

    private static func migrateSalaryPeriod(into context: ModelContext, defaults: UserDefaults) -> Outcome {
        // 프로필과 같은 이유로 조회 실패와 "행 없음"을 구분한다
        var descriptor = FetchDescriptor<SalaryPeriodEntity>()
        descriptor.fetchLimit = 1
        guard let existing = try? context.fetch(descriptor) else {
            print("[LegacyMigration] 기존 정산 기간 조회 실패 — 이번 이전 건너뜀")
            return Outcome(decodeFailed: false, aborted: true)
        }
        if existing.first != nil { return Outcome() }

        // 프로필과 같은 이유로, 레거시 기간 정보가 없으면 만들지 않는다.
        // (기본 슬롯을 넣으면 start=end=삽입 시각이라 곧바로 rollover가 발동해
        //  더미 프로필의 “1일” 기준으로 정산 기간이 덮어써졌다)
        // 엔티티가 없을 때의 표시는 각 화면의 SalaryDate() 폴백이 담당하고,
        // 실제 생성은 온보딩 완료 시 MainView.handleProfileInput이 한다.
        guard let data = defaults.data(forKey: Keys.salaryData) else { return Outcome() }
        guard let decoded = try? PropertyListDecoder().decode(LegacySalary.self, from: data) else {
            print("[LegacyMigration] 정산 기간 디코딩 실패 (\(data.count) bytes)")
            return Outcome(decodeFailed: true, aborted: false)
        }

        context.insert(SalaryPeriodEntity(
            startDate: decoded.startDate,
            endDate: decoded.endDate
        ))
        return Outcome()
    }
}
