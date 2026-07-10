import Foundation
import UserNotifications


extension Date {

    // 어떤 하루의 시작
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    // 이번 달의 시작
    var startOfThisMonth: Date {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    // 이번 달의 끝
    var endOfThisMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 다음 달의 끝 전 날
    var yesterdayOfEndOfNextMonth: Date {
        var components = DateComponents()
        components.month = 2
        components.day = -1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 이번 달의 끝 전 날
    var yesterdayOfEndOfThisMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        components.day = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 지난 달의 끝
    var endOfLastMonth: Date {
        var components = DateComponents()
        components.day = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 지난 어느 날의 시작
    func startOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.month = -1
        components.day = day - 1
        return Calendar.current.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 지난 어느 날의 끝
    func endOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 이번 어느 날의 시작
    func startOfSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        return Calendar.current.date(byAdding: components, to: startOfThisMonth) ?? self
    }

    // 다음 어느 날의 끝
    func endOfSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfSomeDay(day)) ?? self
    }
    
    // 표시/숫자 추출용 공통 포매터.
    // 참고: 기존의 TimeZone(identifier: "ko-KR")은 잘못된 식별자라 항상 nil(no-op)이었음 → 제거.
    // 디바이스가 비양력 캘린더(불교력 등)여도 양력 숫자가 나오도록 캘린더를 고정한다.
    private static func gregorianFormatter(_ format: String) -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = format
        return dateFormatter
    }

    // 날짜를 문자열로 변경 ("MM. dd.")
    func toString() -> String {
        Date.gregorianFormatter("MM. dd.").string(from: self)
    }

    // 날짜를 전체 문자열로 변경
    func toFullString() -> String {
        Date.gregorianFormatter("yyyy. MM. dd").string(from: self)
    }

    func onlydate() -> String {
        Date.gregorianFormatter("d").string(from: self)
    }
}

struct SalaryDate {
    var startDate: Date = Date().startOfThisMonth
    var endDate: Date = Date().endOfThisMonth
}

struct Profile {
    var nickName: String = "User"
    var outLay: Int = 0
    var period: String = "1일"
}

extension String {
    func toInt() -> Int {
        if self.contains(",") {
            return Int(self.split(separator: ",").joined()) ?? 0
        } else {
            return Int(self) ?? 0
        }
    }
}

extension Int {
    func toDecimal() -> String {
        let nsnum = NSNumber(value: self)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf.string(from: nsnum) ?? "\(self)"
    }
}

struct FixedExpenditureItem {
    var id: String = UUID().uuidString
    var day: Int
    var towhat: String
    var how: Int
}

extension UNUserNotificationCenter {
    func addNotificationRequest(to name: String, by alert: FixedExpenditureItem) {
        let content = UNMutableNotificationContent()
        
        let alertMessage = "\(name)님, 내일 \(alert.how.toDecimal())원이 나가요."
        
        content.title = alert.towhat
        content.body = alertMessage
        content.sound = .default
        content.badge = 1
        
        
        let date = Date().startOfSomeDay(alert.day)

        var components = DateComponents()
        components.hour = -6

        let alertTime = Calendar.current.date(byAdding: components, to: date) ?? date

        let component = Calendar.current.dateComponents([.day, .hour], from: alertTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: component, repeats: true)
        
        let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
        
        self.add(request, withCompletionHandler:{_ in

        })
    }
}
