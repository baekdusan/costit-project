import Foundation
import UIKit


extension Date {
    
    // 어떤 하루의 시작
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    // 어떤 하루의 끝
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? startOfDay
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
    
    // 오늘이 월요일인지?
    func isMonday() -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.weekday], from: self)
        return components.weekday == 2
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

    // 날짜를 문자열로 변경
    func toString(_ containYear: Bool) -> String {
        Date.gregorianFormatter(containYear ? "yyyy-MM" : "MM. dd.").string(from: self)
    }

    // 날짜를 전체 문자열로 변경
    func toFullString() -> String {
        Date.gregorianFormatter("yyyy. MM. dd").string(from: self)
    }

    func onlydate() -> String {
        Date.gregorianFormatter("d").string(from: self)
    }

    func onlyMonth() -> Int {
        Int(Date.gregorianFormatter("M").string(from: self)) ?? 1
    }
}

struct finData: Codable, Equatable {
    var when: Date
    var towhat: String
    var how: Int

    // 기존 IUO(Optional) 데이터와의 호환을 위한 커스텀 디코더
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        when = try container.decode(Date.self, forKey: .when)
        towhat = try container.decode(String.self, forKey: .towhat)
        how = try container.decodeIfPresent(Int.self, forKey: .how) ?? 0
    }

    init(when: Date, towhat: String, how: Int) {
        self.when = when
        self.towhat = towhat
        self.how = how
    }
}

struct salaryDate: Codable {
    var startDate: Date = Date().startOfThisMonth
    var endDate: Date = Date().endOfThisMonth
}

struct profile: Codable {
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

extension UIButton {
    func btnLayout(_ isDragging: Bool) {
        self.layer.cornerRadius = 30
        self.alpha = isDragging ? 0.3 : 1
    }
}

struct FixedExpenditure: Codable, Equatable {
    var id: String = UUID().uuidString
    var day: Int
    var towhat: String
    var how: Int

    // 기존 IUO(Optional) 데이터와의 호환을 위한 커스텀 디코더
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        day = try container.decodeIfPresent(Int.self, forKey: .day) ?? 1
        towhat = try container.decodeIfPresent(String.self, forKey: .towhat) ?? ""
        how = try container.decodeIfPresent(Int.self, forKey: .how) ?? 0
    }

    init(id: String = UUID().uuidString, day: Int, towhat: String, how: Int) {
        self.id = id
        self.day = day
        self.towhat = towhat
        self.how = how
    }
}

extension UNUserNotificationCenter {
    func addNotificationRequest(to name: String, by alert: FixedExpenditure) {
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

extension String {
    func toDate() -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyyMM"
        return dateFormatter.date(from: self)
    }
}
