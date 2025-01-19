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
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    // 이번 달의 시작
    var startOfThisMonth: Date {
        
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: self)
        
        return  calendar.date(from: components)!
    }
    
    // 이번 달의 끝
    var endOfThisMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth)!
    }
    
    // 다음 달의 끝 전 날
    var yesterdayOfEndOfNextMonth: Date {
        var components = DateComponents()
        components.month = 2
        components.day = -1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth)!
    }
    
    // 이번 달의 끝 전 날
    var yesterdayOfEndOfThisMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        components.day = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth)!
    }
    
    // 지난 달의 끝
    var endOfLastMonth: Date {
        var components = DateComponents()
        components.day = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfThisMonth)!
    }
    
    // 지난 어느 날의 시작
    func startOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.month = -1
        components.day = day - 1
        return Calendar.current.date(byAdding: components, to: startOfThisMonth)!
    }
    
    // 지난 어느 날의 끝
    func endOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfThisMonth)!
    }
    
    // 이번 어느 날의 시작
    func startOfSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        return Calendar.current.date(byAdding: components, to: startOfThisMonth)!
    }
    
    // 다음 어느 날의 끝
    func endOfSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfSomeDay(day))!
    }
    
    // 오늘이 월요일인지?
    func isMonday() -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.weekday], from: self)
        return components.weekday == 2
    }
    
    // 날짜를 문자열로 변경
    func toString(_ containYear: Bool) -> String {
        let dateFormatter = DateFormatter()
        if containYear == true {
            dateFormatter.dateFormat = "yyyy-MM"
        } else {
            dateFormatter.dateFormat = "MM. dd."
        }
        
        dateFormatter.timeZone = TimeZone(identifier: "ko-KR")
        
        return dateFormatter.string(from: self)
    }
    
    // 날짜를 전체 문자열로 변경
    func toFullString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy. MM. dd"
        
        dateFormatter.timeZone = TimeZone(identifier: "ko-KR")
        
        return dateFormatter.string(from: self)
    }
    
    func onlydate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"
        return dateFormatter.string(from: self)
    }
    
    func onlyMonth() -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M"
        return Int(dateFormatter.string(from: self))!
    }
}

struct finData: Codable, Equatable {
    var when: Date!
    var towhat: String!
    var how: Int!
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
        if self.map({ String($0) }).contains(",") {
            return Int(self.split(separator: ",").joined())!
        } else {
            return Int(self)!
        }
    }
}

extension Int {
    func toDecimal() -> String {
        
        let nsnum = NSNumber(value: self)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        
        return nf.string(from: nsnum)!
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
    var day: Int!
    var towhat: String!
    var how: Int!
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
        
        let alertTime = Calendar.current.date(byAdding: components, to: date)!
        
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
        dateFormatter.dateFormat = "yyyyMM"
        dateFormatter.timeZone = TimeZone(identifier: "ko-KR")
        if let date = dateFormatter.date(from: self) { return date } else { return nil }
    }
}
