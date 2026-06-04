import Foundation
import SwiftData
import CryptoKit

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
        static let firstOpen = "firstOpen"

        static let migrated = "migration.userdefaults_to_swiftdata.v1"   // (구) 1회성 플래그 — 더 이상 판정에 사용하지 않음
        static let fingerprint = "migration.userdefaults_to_swiftdata.fingerprint"
    }

    static func runIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        let current = legacyFingerprint(defaults)
        guard defaults.string(forKey: Keys.fingerprint) != current else { return }

        // 마이그레이션 작업은 background context에서 처리.
        let context = ModelContext(container)

        do {
            migrateFinList(key: Keys.finList, isRevenue: false, into: context, defaults: defaults)
            migrateFinList(key: Keys.rFinList, isRevenue: true, into: context, defaults: defaults)
            migrateFixedExpenditures(into: context, defaults: defaults)
            migrateProfile(into: context, defaults: defaults)
            migrateSalaryPeriod(into: context, defaults: defaults)

            try context.save()
            defaults.set(current, forKey: Keys.fingerprint)
            defaults.set(true, forKey: Keys.migrated)
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

    private static func decodeList<T: Decodable>(_ type: T.Type, from data: Data) -> [T] {
        let wrapped = (try? PropertyListDecoder().decode([Failable<T>].self, from: data)) ?? []
        let values = wrapped.compactMap(\.value)
        if values.count < wrapped.count {
            print("[LegacyMigration] 손상된 항목 \(wrapped.count - values.count)건 건너뜀 (\(T.self))")
        }
        return values
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

    private static func migrateFinList(key: String, isRevenue: Bool, into context: ModelContext, defaults: UserDefaults) {
        guard let data = defaults.data(forKey: key) else { return }
        for item in decodeList(LegacyFin.self, from: data) {
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
    }

    private static func migrateFixedExpenditures(into context: ModelContext, defaults: UserDefaults) {
        guard let data = defaults.data(forKey: Keys.fixedFinList) else { return }
        for item in decodeList(LegacyFixed.self, from: data) {
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
    }

    private static func migrateProfile(into context: ModelContext, defaults: UserDefaults) {
        // 기존 ProfileEntity가 이미 있으면 skip
        var descriptor = FetchDescriptor<ProfileEntity>()
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.first != nil { return }

        let legacy: LegacyProfile
        if let data = defaults.data(forKey: Keys.profile),
           let decoded = try? PropertyListDecoder().decode(LegacyProfile.self, from: data) {
            legacy = decoded
        } else {
            legacy = LegacyProfile()
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

        guard let data = defaults.data(forKey: Keys.salaryData),
              let decoded = try? PropertyListDecoder().decode(LegacySalary.self, from: data) else {
            // 없으면 default 슬롯 1개만 만들어둠 (앱 첫 실행이거나 정보 없을 때)
            context.insert(SalaryPeriodEntity())
            return
        }

        context.insert(SalaryPeriodEntity(
            startDate: decoded.startDate,
            endDate: decoded.endDate
        ))
    }
}
