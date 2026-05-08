import Foundation
import SwiftData

// UserDefaults(PropertyListEncoder 기반)에 저장되어 있던 기존 데이터를
// SwiftData로 1회 이전한다. 멱등(idempotent)하게 동작:
//   - 이미 마이그레이션 완료 플래그가 있으면 즉시 종료
//   - 실패해도 원본 UserDefaults 데이터는 보존 (rollback 안전망)
//   - 성공 후 즉시 UserDefaults를 삭제하지 않음 (사용자 1~2 버전 후 정리)
enum LegacyMigration {
    private enum Keys {
        static let finList = "finlist"
        static let rFinList = "rfinList"
        static let fixedFinList = "fixedFinList"
        static let profile = "profile"
        static let salaryData = "salarydata"
        static let firstOpen = "firstOpen"

        static let migrated = "migration.userdefaults_to_swiftdata.v1"
    }

    static func runIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Keys.migrated) else { return }

        // 마이그레이션 작업은 background context에서 처리.
        let context = ModelContext(container)

        do {
            try migrateExpenses(into: context, defaults: defaults)
            try migrateRevenues(into: context, defaults: defaults)
            try migrateFixedExpenditures(into: context, defaults: defaults)
            try migrateProfile(into: context, defaults: defaults)
            try migrateSalaryPeriod(into: context, defaults: defaults)

            try context.save()
            defaults.set(true, forKey: Keys.migrated)
        } catch {
            // 실패 시 컨텍스트만 폐기. UserDefaults는 그대로 → 다음 실행에서 재시도.
            print("[LegacyMigration] 실패: \(error)")
        }
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

    private static func migrateExpenses(into context: ModelContext, defaults: UserDefaults) throws {
        guard let data = defaults.data(forKey: Keys.finList) else { return }
        let list = (try? PropertyListDecoder().decode([LegacyFin].self, from: data)) ?? []
        for item in list {
            // 동일 (when, towhat, how, isRevenue=false) 가 이미 있으면 skip
            let predicate = #Predicate<FinDataEntity> {
                $0.isRevenue == false &&
                $0.when == item.when &&
                $0.towhat == item.towhat &&
                $0.how == item.how
            }
            var descriptor = FetchDescriptor<FinDataEntity>(predicate: predicate)
            descriptor.fetchLimit = 1
            if (try? context.fetch(descriptor))?.first != nil { continue }

            context.insert(FinDataEntity(
                when: item.when,
                towhat: item.towhat,
                how: item.how,
                isRevenue: false
            ))
        }
    }

    private static func migrateRevenues(into context: ModelContext, defaults: UserDefaults) throws {
        guard let data = defaults.data(forKey: Keys.rFinList) else { return }
        let list = (try? PropertyListDecoder().decode([LegacyFin].self, from: data)) ?? []
        for item in list {
            let predicate = #Predicate<FinDataEntity> {
                $0.isRevenue == true &&
                $0.when == item.when &&
                $0.towhat == item.towhat &&
                $0.how == item.how
            }
            var descriptor = FetchDescriptor<FinDataEntity>(predicate: predicate)
            descriptor.fetchLimit = 1
            if (try? context.fetch(descriptor))?.first != nil { continue }

            context.insert(FinDataEntity(
                when: item.when,
                towhat: item.towhat,
                how: item.how,
                isRevenue: true
            ))
        }
    }

    private static func migrateFixedExpenditures(into context: ModelContext, defaults: UserDefaults) throws {
        guard let data = defaults.data(forKey: Keys.fixedFinList) else { return }
        let list = (try? PropertyListDecoder().decode([LegacyFixed].self, from: data)) ?? []
        for item in list {
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

    private static func migrateProfile(into context: ModelContext, defaults: UserDefaults) throws {
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

    private static func migrateSalaryPeriod(into context: ModelContext, defaults: UserDefaults) throws {
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
