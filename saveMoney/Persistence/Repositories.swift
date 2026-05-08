import Foundation
import SwiftData

// 기존 ViewController에서 사용하던 [finData], [FixedExpenditure], profile, salaryDate 형태로
// SwiftData를 읽고/쓰는 어댑터. UI를 SwiftUI로 옮기기 전까지 UIKit 코드와 새 데이터 레이어를
// 다리역할로 연결한다.
//
// SwiftUI 화면으로 전환되는 시점에는 @Query / @Environment(\.modelContext) 직접 사용으로
// 대체될 예정. 이 파일은 마이그레이션 기간의 임시 호환층.

@MainActor
final class FinRepository {
    private let container: ModelContainer
    private var context: ModelContext { ModelContext(container) }

    init(container: ModelContainer = PersistenceController.shared) {
        self.container = container
    }

    // MARK: Fetch

    func fetchAllExpenses() -> [finData] {
        fetchFin(isRevenue: false)
    }

    func fetchAllRevenues() -> [finData] {
        fetchFin(isRevenue: true)
    }

    private func fetchFin(isRevenue: Bool) -> [finData] {
        let predicate = #Predicate<FinDataEntity> { $0.isRevenue == isRevenue }
        let descriptor = FetchDescriptor<FinDataEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.when, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map { finData(when: $0.when, towhat: $0.towhat, how: $0.how) }
    }

    func fetchFixedExpenditures() -> [FixedExpenditure] {
        let descriptor = FetchDescriptor<FixedExpenditureEntity>(
            sortBy: [SortDescriptor(\.day)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.map {
            FixedExpenditure(id: $0.externalID, day: $0.day, towhat: $0.towhat, how: $0.how)
        }
    }

    func fetchProfile() -> profile {
        let descriptor = FetchDescriptor<ProfileEntity>()
        if let entity = (try? context.fetch(descriptor))?.first {
            return profile(nickName: entity.nickName, outLay: entity.outLay, period: entity.period)
        }
        return profile()
    }

    func fetchSalaryPeriod() -> salaryDate {
        let descriptor = FetchDescriptor<SalaryPeriodEntity>()
        if let entity = (try? context.fetch(descriptor))?.first {
            return salaryDate(startDate: entity.startDate, endDate: entity.endDate)
        }
        return salaryDate()
    }

    // MARK: Save (전체 교체 방식 — 기존 UserDefaults 패턴과 호환)

    func saveExpenses(_ list: [finData]) {
        replaceFin(list, isRevenue: false)
    }

    func saveRevenues(_ list: [finData]) {
        replaceFin(list, isRevenue: true)
    }

    private func replaceFin(_ list: [finData], isRevenue: Bool) {
        let ctx = context
        let predicate = #Predicate<FinDataEntity> { $0.isRevenue == isRevenue }
        let descriptor = FetchDescriptor<FinDataEntity>(predicate: predicate)
        if let existing = try? ctx.fetch(descriptor) {
            for entity in existing { ctx.delete(entity) }
        }
        for item in list {
            ctx.insert(FinDataEntity(
                when: item.when,
                towhat: item.towhat,
                how: item.how,
                isRevenue: isRevenue
            ))
        }
        try? ctx.save()
    }

    func saveFixedExpenditures(_ list: [FixedExpenditure]) {
        let ctx = context
        let descriptor = FetchDescriptor<FixedExpenditureEntity>()
        if let existing = try? ctx.fetch(descriptor) {
            for entity in existing { ctx.delete(entity) }
        }
        for item in list {
            ctx.insert(FixedExpenditureEntity(
                externalID: item.id,
                day: item.day,
                towhat: item.towhat,
                how: item.how
            ))
        }
        try? ctx.save()
    }

    func saveProfile(_ value: profile) {
        let ctx = context
        let descriptor = FetchDescriptor<ProfileEntity>()
        let entity: ProfileEntity
        if let existing = (try? ctx.fetch(descriptor))?.first {
            entity = existing
        } else {
            entity = ProfileEntity()
            ctx.insert(entity)
        }
        entity.nickName = value.nickName
        entity.outLay = value.outLay
        entity.period = value.period
        try? ctx.save()
    }

    func saveSalaryPeriod(_ value: salaryDate) {
        let ctx = context
        let descriptor = FetchDescriptor<SalaryPeriodEntity>()
        let entity: SalaryPeriodEntity
        if let existing = (try? ctx.fetch(descriptor))?.first {
            entity = existing
        } else {
            entity = SalaryPeriodEntity()
            ctx.insert(entity)
        }
        entity.startDate = value.startDate
        entity.endDate = value.endDate
        try? ctx.save()
    }
}
