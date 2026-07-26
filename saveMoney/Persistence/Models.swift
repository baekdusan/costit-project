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
    // 사용자가 실제로 입력한 프로필을 우선하고, 그 안에서는 내용으로 결정적으로 고른다.
    //
    // persistentModelID를 키로 쓰지 않는 이유: 문자열 표현에 프로세스마다 달라지는 토큰이 섞여 있어
    // "결정적"이라는 전제가 성립하지 않는다(앱과 위젯이 서로 다른 사본을 고를 수 있다).
    // 반대로 내용을 키로 쓰면 편집 때 선택이 옮겨갈 수 있는데, 그건 쓰기 쪽에서 막는다 —
    // 프로필을 저장할 때 사본 전체를 같은 값으로 맞추므로(MainView.handleProfileInput)
    // 어느 사본이 뽑히든 값이 같아진다. 삭제 없이 불일치를 없애는 방식이다.
    var canonical: ProfileEntity? {
        let entered = self.filter { $0.outLay > 0 || $0.nickName != Profile().nickName }
        let pool = entered.isEmpty ? Array(self) : entered
        return pool.max { ($0.outLay, $0.nickName, $0.period) < ($1.outLay, $1.nickName, $1.period) }
    }
}

extension Collection where Element == SalaryPeriodEntity {
    // 같은 이유로 내용 기반 결정적 선택 — 쓰기 쪽(rolloverSalaryPeriodIfNeeded)이 사본 전체를
    // 같은 값으로 맞추므로 어느 것이 뽑혀도 결과가 같다.
    var canonical: SalaryPeriodEntity? {
        self.max { ($0.startDate, $0.endDate) < ($1.startDate, $1.endDate) }
    }
}
