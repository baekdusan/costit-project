import Foundation
import SwiftData

// MARK: - SwiftData Models
// CloudKit 동기화를 위해 모든 프로퍼티는 optional 또는 default 값을 가져야 함.
// 또한 모든 관계(있다면)는 optional이어야 하고, @Attribute(.unique)는 사용 불가.

@Model
final class FinDataEntity {
    var when: Date = Date()
    var towhat: String = ""
    var how: Int = 0
    // 지출(false) / 수입(true)
    var isRevenue: Bool = false
    // 안정적 식별자 (마이그레이션 멱등성 보장용)
    var externalID: String = UUID().uuidString

    init(when: Date = Date(),
         towhat: String = "",
         how: Int = 0,
         isRevenue: Bool = false,
         externalID: String = UUID().uuidString) {
        self.when = when
        self.towhat = towhat
        self.how = how
        self.isRevenue = isRevenue
        self.externalID = externalID
    }
}

@Model
final class FixedExpenditureEntity {
    var externalID: String = UUID().uuidString
    var day: Int = 1
    var towhat: String = ""
    var how: Int = 0

    init(externalID: String = UUID().uuidString,
         day: Int = 1,
         towhat: String = "",
         how: Int = 0) {
        self.externalID = externalID
        self.day = day
        self.towhat = towhat
        self.how = how
    }
}

@Model
final class ProfileEntity {
    // 현재 미사용 — 추후 CloudKit 중복 dedup용으로 예약 (항상 "default").
    // CloudKit 스키마가 이미 배포됐으므로 제거 금지.
    var slot: String = "default"
    var nickName: String = "User"
    var outLay: Int = 0
    var period: String = "1일"

    init(slot: String = "default",
         nickName: String = "User",
         outLay: Int = 0,
         period: String = "1일") {
        self.slot = slot
        self.nickName = nickName
        self.outLay = outLay
        self.period = period
    }
}

@Model
final class SalaryPeriodEntity {
    // ProfileEntity.slot과 동일한 예약 프로퍼티 — 제거 금지
    var slot: String = "default"
    var startDate: Date = Date()
    var endDate: Date = Date()

    init(slot: String = "default",
         startDate: Date = Date(),
         endDate: Date = Date()) {
        self.slot = slot
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - 값 모델 변환
// 뷰/위젯의 "엔티티 없으면 기본값" fallback이 전부 Profile()/SalaryDate() 기본값을
// 단일 소스로 쓰도록 하는 변환 헬퍼 (예: profiles.first?.asProfile ?? Profile())

extension ProfileEntity {
    var asProfile: Profile {
        Profile(nickName: nickName, outLay: outLay, period: period)
    }
}

extension SalaryPeriodEntity {
    var asSalaryDate: SalaryDate {
        SalaryDate(startDate: startDate, endDate: endDate)
    }
}
