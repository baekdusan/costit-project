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

// MARK: - 싱글턴 엔티티의 결정적 선택
// ProfileEntity/SalaryPeriodEntity는 논리적으로 1개지만, CloudKit 동기화가 끝나기 전에
// 다른 기기가 각자 생성하면 여러 벌이 될 수 있다(@Attribute(.unique)는 CloudKit에서 사용 불가).
// 이때 무정렬 .first를 쓰면 실행마다 다른 행이 뽑혀 목표 지출액·급여일이 뒤바뀌고,
// 급여일이 튈 때마다 이전 기간 지출이 화면에서 사라진 것처럼 보인다.

extension Collection where Element == ProfileEntity {
    // 사용자가 실제로 입력한 프로필(예산 > 0)을 우선하고, 그 안에서도 항상 같은 행을 고른다.
    // 마이그레이션이 남긴 기본값 프로필("User"/0원)이 섞여 있어도 진짜 프로필이 선택된다.
    var canonical: ProfileEntity? {
        self.max { ($0.outLay, $0.nickName) < ($1.outLay, $1.nickName) }
    }
}

extension Collection where Element == SalaryPeriodEntity {
    // 같은 이유로 결정적 선택 — 가장 최근에 시작한 기간을 쓴다.
    var canonical: SalaryPeriodEntity? {
        self.max { ($0.startDate, $0.endDate) < ($1.startDate, $1.endDate) }
    }
}
