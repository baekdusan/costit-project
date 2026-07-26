import Foundation
import UserNotifications

// MARK: - 날짜 산술

extension Date {

    // 모든 날짜 산술은 양력(gregorian) 고정 — 디바이스 캘린더 설정(불교력 등)과 무관하게 동작.
    // 캐시된 let이 아닌 computed로 두는 이유: Calendar는 생성 시점의 타임존을 스냅샷하므로
    // 수명이 긴 프로세스(위젯)에서 타임존 변경을 따라가지 못하는 회귀를 피하기 위함.
    private var gregorian: Calendar { Calendar(identifier: .gregorian) }

    // 어떤 하루의 시작
    var startOfDay: Date {
        return gregorian.startOfDay(for: self)
    }

    // 소수점 이하 초를 버린 시각.
    // 정산 기간의 end는 정확히 23:59:59.000인데 Date()는 소수초를 갖고 있어,
    // 기간 마지막 1초 안에 저장한 지출이 `when <= end` 필터에서 빠지고
    // 다음 기간 시작(다음날 00:00)보다는 이르러 어느 기간에도 속하지 않게 된다.
    var truncatingSubseconds: Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded(.down))
    }

    // 이번 달의 시작
    var startOfThisMonth: Date {
        let calendar = gregorian
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    // 이번 달의 끝
    var endOfThisMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return gregorian.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 이 날짜가 속한 달에서 monthOffset개월 이동한 달의 "day일 00:00".
    // 그 달에 day일이 없으면(2월의 30일 등) 그 달의 마지막 날로 클램프한다.
    //
    // 과거 구현은 "그 달 1일 + (day-1)일"이라 없는 날짜가 다음 달로 넘쳤다.
    // 예) 급여일 30일 + 3월 1일 기준 → 지난 급여일이 3월 2일로 계산되어
    // 정산 기간이 [3/2 ~ 3/29]가 되고, 2월 28일·3월 1일 지출이 어느 기간에도
    // 속하지 않아 화면에서 사라졌다. 클램프하면 기간이 빈틈없이 이어진다.
    func salaryDayStart(_ day: Int, monthOffset: Int = 0) -> Date {
        let calendar = gregorian
        guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startOfThisMonth),
              let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count else {
            return startOfDay
        }
        let clampedDay = min(max(day, 1), daysInMonth)
        return calendar.date(byAdding: .day, value: clampedDay - 1, to: monthStart) ?? monthStart
    }

    // 날짜를 문자열로 변경 ("MM. dd.")
    func toString() -> String {
        AppDateFormatters.monthDay.string(from: self)
    }

    func onlydate() -> String {
        AppDateFormatters.dayOnly.string(from: self)
    }
}

// MARK: - 공통 포매터 / 상수

// 표시/숫자 추출용 공통 포매터 캐시 (호출마다 DateFormatter를 새로 만들던 안티패턴 제거).
// 참고: 과거의 TimeZone(identifier: "ko-KR")은 잘못된 식별자라 항상 nil(no-op)이었음 → 미지정 유지.
// 디바이스가 비양력 캘린더(불교력 등)여도 양력 숫자가 나오도록 캘린더를 고정한다.
// DateFormatter는 스레드 세이프하지 않지만 사용처가 전부 메인 스레드 경로라 안전.
enum AppDateFormatters {
    static let monthDay = make("MM. dd.")         // Date.toString
    static let dayOnly = make("d")                // Date.onlydate
    static let shortDate = make("yy. MM. dd")     // SearchView 셀
    static let editDate = make("yy. M. d.")       // AddFinView 날짜 버튼
    // (급여 기간 계산은 문자열 파싱 대신 Calendar 산술을 쓰도록 바뀌어 "dd" 포매터는 제거됨 —
    //  날짜 산술을 문자열 왕복으로 하던 것 자체가 문제였다. 참고: timeZone을 대입하지 않은
    //  DateFormatter는 캐시해도 시스템 타임존 변경을 따라가므로 캐시 자체는 안전하다.
    //  타임존 스냅샷 문제가 있는 쪽은 Calendar다 — Date 확장의 gregorian이 computed인 이유)

    private static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter
    }
}

// UserDefaults 키 (레거시 데이터 키는 LegacyMigration.Keys가 별도 관리)
enum AppKeys {
    static let firstOpen = "firstOpen"
}

#if DEBUG
// 디자인 검증/캡처 자동화용 환경 변수 키 (SceneDelegate DEBUG 블록 참고)
enum LaunchEnvKeys {
    static let showScreen = "SHOW_SCREEN"
    static let seedDemoData = "SEED_DEMO_DATA"
}
#endif

// MARK: - 급여 기간

// 급여일 문자열 상수 — FirstOpenView의 선택지 생성과 급여 기간 파싱이 같은 값을 공유.
// ProfileEntity.period의 default "1일"도 이 값과 동일해야 함.
enum SalaryDay {
    static let firstDay = "1일"
    static let lastDay = "마지막 날"
    static func day(_ n: Int) -> String { "\(n)일" }
}

struct SalaryDate {
    var startDate: Date = Date().startOfThisMonth
    var endDate: Date = Date().endOfThisMonth
}

extension SalaryDate {
    // 급여일 문자열("1일", "29일", "마지막 날")로 한 달 정산 기간 계산 (기존 mainVC.setSalaryDate)
    // 불변식 1: start는 급여일 00:00, end는 다음 급여일 직전(-1초).
    //          start가 하루의 끝이면 그 날 지출이 기간 필터($0.when >= start)에서 통째로 빠진다.
    // 불변식 2: 연속한 두 기간 사이에 빈틈이 없다 — 어떤 지출도 "어느 기간에도 없는" 상태가 되지 않는다.
    static func period(forSalaryDay salary: String, now: Date = Date()) -> SalaryDate {
        let day = salaryDayNumber(from: salary)
        let thisPeriodStart = now.salaryDayStart(day)

        // 일(day) 숫자가 아니라 시각으로 비교한다 — 급여일이 없는 달(2월의 30일 등)은
        // salaryDayStart가 말일로 클램프하므로, 숫자 비교(today >= 30)로는 이번 달 급여일이
        // 지났는데도 영영 "아직 안 됨"으로 판정되어 기간이 어긋난다.
        if now >= thisPeriodStart {
            return SalaryDate(startDate: thisPeriodStart,
                              endDate: now.salaryDayStart(day, monthOffset: 1).addingTimeInterval(-1))
        }
        return SalaryDate(startDate: now.salaryDayStart(day, monthOffset: -1),
                          endDate: thisPeriodStart.addingTimeInterval(-1))
    }

    // "1일"→1, "29일"→29, "마지막 날"→31(salaryDayStart가 각 달 말일로 클램프).
    // 구버전이 남겼을 수 있는 "마지막날"(공백 없음) 같은 변형도 말일로 해석한다 —
    // 숫자가 없다는 이유로 1일로 떨어지면 기존 사용자의 정산 기간이 통째로 어긋나
    // 이전 기간 지출이 화면에서 사라진다.
    private static func salaryDayNumber(from salary: String) -> Int {
        if salary.contains("마지막") { return 31 }
        let digits = salary.filter { $0.isASCII && $0.isNumber }
        guard let day = Int(digits), day >= 1 else { return 1 }
        return min(day, 31)
    }
}

// MARK: - 값 모델

struct Profile {
    var nickName: String = "User"
    var outLay: Int = 0
    var period: String = SalaryDay.firstDay
}

struct FixedExpenditureItem {
    var id: String = UUID().uuidString
    var day: Int
    var towhat: String
    var how: Int
}

// MARK: - 숫자/문자열 변환

extension String {
    // 파싱 실패(비숫자·Int 범위 초과) 시 0 폴백. 입력 필드는 currencyInputFormatted가
    // ASCII 숫자만 남기고 자릿수도 제한하므로 화면 입력 경로에서는 실패하지 않는다 — 방어용 폴백.
    func toInt() -> Int {
        if self.contains(",") {
            return Int(self.split(separator: ",").joined()) ?? 0
        } else {
            return Int(self) ?? 0
        }
    }
}

extension Int {
    // locale을 고정하는 이유: toDecimal()의 출력이 화면 표시로만 끝나지 않고
    // 입력 필드 prefill(AddFinView/FirstOpenView) → currencyInputFormatted → toInt()로
    // 되돌아온다. 그룹 구분자가 "."인 로케일(독일 등)에서는 이 왕복에서 금액이 훼손된다.
    private static let decimalFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = Locale(identifier: "ko_KR")
        return nf
    }()

    func toDecimal() -> String {
        Int.decimalFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - 고정 지출 알림

extension UNUserNotificationCenter {
    func addNotificationRequest(to name: String, by alert: FixedExpenditureItem) {
        let content = UNMutableNotificationContent()

        // "내일"이라고 못 박지 않는다 — 매월 반복 트리거는 (일, 시)만 지정할 수 있어
        // 1일 지출의 알림은 28일에 오고, 30·31일 지출도 달에 따라 하루 이상 앞설 수 있다.
        // 지출일을 그대로 알려주면 어느 날 발화하든 안내가 정확하다.
        let alertMessage = "\(name)님, \(alert.day)일에 \(alert.how.toDecimal())원이 나가요."

        content.title = alert.towhat
        content.body = alertMessage
        content.sound = .default
        content.badge = 1

        // 고정 지출일 전날 18시에 매월 반복 알림.
        // 과거 구현은 "등록한 달의 지출일 00:00 - 6시간"에서 (day, hour)를 뽑았기 때문에
        // 등록 시점의 달에 따라 발화일이 달라졌다. 예) 2월에 31일 항목을 등록하면
        // 2/1 + 30일 = 3/3 → 전날 3/2 → 이후 매월 2일 18시에 발화.
        // 등록 달과 무관하게 결정적으로 계산한다.
        var components = DateComponents()
        components.day = Self.notificationDay(forExpenditureDay: alert.day)
        components.hour = 18

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)

        self.add(request, withCompletionHandler: { _ in

        })
    }

    // 지출일의 전날. 단 29일을 넘는 날짜는 모든 달에 존재하지 않아 그대로 쓸 수 없다:
    //  - 1일의 "전날"은 달마다 28~31일로 달라져 매월 반복 트리거 하나로 표현 불가
    //  - 30일 지출 → 29일 발화: 평년 2월엔 그 달 알림이 아예 오지 않음
    //  - 31일 지출 → 30일 발화: 2월엔 오지 않음
    // 모든 달에 존재하는 28일로 맞춘다 (본문이 실제 지출일을 알려주므로 며칠 앞서도 안내는 정확).
    private static func notificationDay(forExpenditureDay day: Int) -> Int {
        let clamped = min(max(day, 1), 31)
        return clamped == 1 ? 28 : min(clamped - 1, 28)
    }
}
