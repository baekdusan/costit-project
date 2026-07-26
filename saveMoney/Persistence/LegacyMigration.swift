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

    static func runIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        let current = legacyFingerprint(defaults)
        guard defaults.string(forKey: Keys.fingerprint) != current else { return }

        // 마이그레이션 작업은 background context에서 처리.
        let context = ModelContext(container)

        do {
            var decodeFailed = false
            decodeFailed = migrateFinList(key: Keys.finList, isRevenue: false, into: context, defaults: defaults) || decodeFailed
            decodeFailed = migrateFinList(key: Keys.rFinList, isRevenue: true, into: context, defaults: defaults) || decodeFailed
            decodeFailed = migrateFixedExpenditures(into: context, defaults: defaults) || decodeFailed
            migrateProfile(into: context, defaults: defaults)
            migrateSalaryPeriod(into: context, defaults: defaults)

            try context.save()

            // fingerprint를 기록하면 다음 실행부터 guard에 걸려 재시도조차 하지 않는다.
            // 따라서 "이전이 영속적으로 완료됐다"고 확신할 때만 기록한다.
            //  - decodeFailed: 데이터가 있는데 통째로 디코딩 실패 → 다음 버전에서 재시도할 여지를 남긴다
            //  - isEphemeralFallback: 스토어를 못 열어 in-memory로 동작 중 → 이전 결과가 앱 종료와 함께
            //    사라지는데 완료로 기록하면 원본이 UserDefaults에 남아 있어도 영영 이전되지 않는다
            if decodeFailed || PersistenceController.isEphemeralFallback {
                print("[LegacyMigration] 이전이 영속되지 않음(decodeFailed=\(decodeFailed), ephemeral=\(PersistenceController.isEphemeralFallback)) — fingerprint 미기록")
            } else {
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

    private struct LegacyProfile: Codable {
        var nickName: String = "User"
        var outLay: Int = 0
        var period: String = "1일"
    }

    private struct LegacySalary: Codable {
        var startDate: Date
        var endDate: Date
    }

    // MARK: - Migration steps

    // 같은 레거시 레코드는 어느 기기에서 이전해도 같은 externalID를 갖는다.
    // → CloudKit으로 두 기기가 각자 마이그레이션해도 externalID 기준 dedup 가능.
    private static func legacyID(for item: LegacyFin, isRevenue: Bool) -> String {
        "legacy:\(isRevenue ? "r" : "e"):\(Int(item.when.timeIntervalSince1970)):\(item.how):\(item.towhat)"
    }

    // 반환값: 최상위 디코딩 실패 여부 (true면 이번 이전을 "완료"로 확정하면 안 됨)
    private static func migrateFinList(key: String, isRevenue: Bool, into context: ModelContext, defaults: UserDefaults) -> Bool {
        guard let data = defaults.data(forKey: key) else { return false }
        let decoded = decodeList(LegacyFin.self, from: data)
        if decoded.failed { return true }

        for item in decoded.values {
            let extID = legacyID(for: item, isRevenue: isRevenue)
            // externalID 외에 내용(when/towhat/how)도 비교 — 과거 dual-write 기간(FinRepository)에
            // UUID externalID로 저장된 동일 레코드가 재이전 시 중복 생성되지 않도록.
            let when = item.when
            let towhat = item.towhat
            let how = item.how
            let predicate = #Predicate<FinDataEntity> {
                $0.externalID == extID ||
                ($0.isRevenue == isRevenue && $0.when == when && $0.towhat == towhat && $0.how == how)
            }
            var descriptor = FetchDescriptor<FinDataEntity>(predicate: predicate)
            descriptor.fetchLimit = 1
            if (try? context.fetch(descriptor))?.first != nil { continue }

            context.insert(FinDataEntity(
                when: item.when,
                towhat: item.towhat,
                how: item.how,
                isRevenue: isRevenue,
                externalID: extID
            ))
        }
        return false
    }

    private static func migrateFixedExpenditures(into context: ModelContext, defaults: UserDefaults) -> Bool {
        guard let data = defaults.data(forKey: Keys.fixedFinList) else { return false }
        let decoded = decodeList(LegacyFixed.self, from: data)
        if decoded.failed { return true }

        for item in decoded.values {
            let extID = item.id
            let predicate = #Predicate<FixedExpenditureEntity> { $0.externalID == extID }
            var descriptor = FetchDescriptor<FixedExpenditureEntity>(predicate: predicate)
            descriptor.fetchLimit = 1
            if (try? context.fetch(descriptor))?.first != nil { continue }

            context.insert(FixedExpenditureEntity(
                externalID: item.id,
                day: item.day,
                towhat: item.towhat,
                how: item.how
            ))
        }
        return false
    }

    private static func migrateProfile(into context: ModelContext, defaults: UserDefaults) {
        // 기존 ProfileEntity가 이미 있으면 skip
        var descriptor = FetchDescriptor<ProfileEntity>()
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.first != nil { return }

        // 레거시 프로필이 없으면 아무것도 만들지 않는다.
        // 과거엔 기본값(“User”/0원/“1일”) 프로필을 무조건 삽입했는데, 그 결과
        //  (a) 신규 설치에서도 프로필이 존재해 온보딩 표시 판정이 망가지고
        //  (b) 기기 교체 시 CloudKit에서 내려올 진짜 프로필과 중복되어, 정렬 없는 .first가
        //      더미를 골라 사용자의 목표 지출액·급여일이 사라진 것처럼 보였다.
        guard let data = defaults.data(forKey: Keys.profile),
              let legacy = try? PropertyListDecoder().decode(LegacyProfile.self, from: data) else {
            return
        }

        context.insert(ProfileEntity(
            nickName: legacy.nickName,
            outLay: legacy.outLay,
            period: legacy.period
        ))
    }

    private static func migrateSalaryPeriod(into context: ModelContext, defaults: UserDefaults) {
        var descriptor = FetchDescriptor<SalaryPeriodEntity>()
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.first != nil { return }

        // 프로필과 같은 이유로, 레거시 기간 정보가 없으면 만들지 않는다.
        // (기본 슬롯을 넣으면 start=end=삽입 시각이라 곧바로 rollover가 발동해
        //  더미 프로필의 “1일” 기준으로 정산 기간이 덮어써졌다)
        // 엔티티가 없을 때의 표시는 각 화면의 SalaryDate() 폴백이 담당하고,
        // 실제 생성은 온보딩 완료 시 MainView.handleProfileInput이 한다.
        guard let data = defaults.data(forKey: Keys.salaryData),
              let decoded = try? PropertyListDecoder().decode(LegacySalary.self, from: data) else {
            return
        }

        context.insert(SalaryPeriodEntity(
            startDate: decoded.startDate,
            endDate: decoded.endDate
        ))
    }
}
