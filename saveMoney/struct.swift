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

    // 다음 달의 끝 전 날
    var yesterdayOfEndOfNextMonth: Date {
        var components = DateComponents()
        components.month = 2
        components.day = -1
        components.second = -1
        return gregorian.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 이번 달의 끝 전 날
    var yesterdayOfEndOfThisMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        components.day = -1
        return gregorian.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 지난 달 마지막 날의 시작 (00:00) — 이름이 "끝"처럼 보이지만 시각은 하루의 시작임에 주의
    var startOfLastDayOfLastMonth: Date {
        var components = DateComponents()
        components.day = -1
        return gregorian.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 지난 어느 날의 시작
    func startOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.month = -1
        components.day = day - 1
        return gregorian.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 지난 어느 날의 끝
    func endOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        components.second = -1
        return gregorian.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 이번 어느 날의 시작
    func startOfSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        return gregorian.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 다음 어느 날의 끝
    func endOfSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return gregorian.date(byAdding: components, to: startOfSomeDay(day)) ?? self
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
    static let salaryDay = make("dd")             // 급여 기간 계산

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
    // 불변식: 기간 start는 그 날 00:00, end는 마지막 날 23:59:59 — start가 하루의 끝이면
    // 그 날의 지출이 기간 필터($0.when >= start)에서 통째로 빠진다.
    static func period(forSalaryDay salary: String, now: Date = Date()) -> SalaryDate {
        // 비양력 디바이스 캘린더(불교력 등)에서도 양력 기준 일자를 얻도록 gregorian 고정 캐시 사용
        let today = Int(AppDateFormatters.salaryDay.string(from: now)) ?? 1

        if salary == SalaryDay.lastDay {
            let endOfMonthDay = Int(AppDateFormatters.salaryDay.string(from: now.endOfThisMonth)) ?? 28
            if today == endOfMonthDay {
                // 월급날(말일) 당일: 과거엔 start가 endOfThisMonth(23:59:59)여서
                // 월급날 당일 지출이 정산 기간에서 누락되는 버그가 있었음 → 당일 00:00으로 시작
                return SalaryDate(startDate: now.startOfDay, endDate: now.yesterdayOfEndOfNextMonth)
            }
            return SalaryDate(startDate: now.startOfLastDayOfLastMonth, endDate: now.yesterdayOfEndOfThisMonth)
        }

        if salary == SalaryDay.firstDay {
            return SalaryDate(startDate: now.startOfThisMonth, endDate: now.endOfThisMonth)
        }

        // "29일" → 29 추출
        let digits = salary.filter { $0.isNumber }
        let salaryDay = Int(digits) ?? 1

        if today >= salaryDay {
            return SalaryDate(startDate: now.startOfSomeDay(salaryDay), endDate: now.endOfSomeDay(salaryDay))
        } else {
            return SalaryDate(startDate: now.startOfLastSomeDay(salaryDay), endDate: now.endOfLastSomeDay(salaryDay))
        }
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
    // 파싱 실패(비숫자·Int 범위 초과) 시 0 폴백. 입력 필드의 currencyInputFormatted
    // 자릿수 가드가 대부분의 경로를 막지만, keepAsIs 정책의 비파싱 입력
    // (전각 숫자 붙여넣기 등)은 여전히 이 폴백에 도달할 수 있음 (기존 동작 유지)
    func toInt() -> Int {
        if self.contains(",") {
            return Int(self.split(separator: ",").joined()) ?? 0
        } else {
            return Int(self) ?? 0
        }
    }
}

extension Int {
    private static let decimalFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
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

        let alertMessage = "\(name)님, 내일 \(alert.how.toDecimal())원이 나가요."

        content.title = alert.towhat
        content.body = alertMessage
        content.sound = .default
        content.badge = 1

        // 고정 지출일 전날 18시(당일 00:00 - 6시간)에 매월 반복 알림
        let date = Date().startOfSomeDay(alert.day)

        var components = DateComponents()
        components.hour = -6

        let gregorian = Calendar(identifier: .gregorian)
        let alertTime = gregorian.date(byAdding: components, to: date) ?? date

        let component = gregorian.dateComponents([.day, .hour], from: alertTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: component, repeats: true)

        let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)

        self.add(request, withCompletionHandler: { _ in

        })
    }
}
