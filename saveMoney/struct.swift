import Foundation
import UIKit


extension Date {
    
    // 하루의 시작
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    // 하루의 끝
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }

    // 이번 달의 시작
    var startOfMonth: Date {

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: self)

        return  calendar.date(from: components)!
    }

    // 이번 달의 끝
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfMonth)!
    }
    
    // 지난 달의 끝
    var endofLastMonth: Date {
        var components = DateComponents()
        components.day = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfMonth)!
    }
    
    // 지난 어느 날의 시작
    func startOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.month = -1
        components.day = day - 1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
    
    // 이번 어느 날의 끝
    func endOfLastSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
    
    // 이번 어느 날의 시작
    func startOfSomeDay(_ day: Int) -> Date {
        var components = DateComponents()
        components.day = day - 1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
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
        dateFormatter.dateFormat = "yyyy-MM-dd"
            
        dateFormatter.timeZone = TimeZone(identifier: "ko-KR")
            
        return dateFormatter.string(from: self)
    }
    
    func onlydate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd"
        
        return dateFormatter.string(from: self)
    }
}

struct finData: Codable, Equatable {
    var when: Date!
    var towhat: String!
    var how: Int!
}

struct salaryDate: Codable {
    var startDate: Date = Date().startOfMonth
    var endDate: Date = Date().endOfMonth
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
    func btnLayout() {
        self.layer.cornerRadius = 32
//        btn.layer.shadowColor = UIColor.black.cgColor
//        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
//        btn.layer.shadowRadius = 5
//        btn.layer.shadowOpacity = 0.2
//        btn.layer.masksToBounds = false
        self.alpha = 0.78
    }
}

class revenue {
    static let shared = revenue()
    var rFinList: [finData]!
    private init() { }
}

class expense {
    static let shared = expense()
    var eFinList: [finData]!
    var purpose: Int!
    private init() { }
}
