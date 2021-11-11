import UIKit
import FSCalendar

class calendarVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var calendarView: FSCalendar!
    @IBOutlet weak var pickDate: UILabel!
    @IBOutlet weak var todayTotalCost: UILabel!
    @IBOutlet weak var todayTotalRCost: UILabel!
    @IBOutlet weak var calendarCorner: UIView!
    
    var efinList: [finData] = []
    var rfinList: [finData] = []
    var filtered: [finData] = []
    let dateFormatter = DateFormatter()
    var period = salaryDate()
    var purpose : Int = 0
    
    // 다크 라이트 전환시 적용
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        calendarView.appearance.selectionColor = UIColor(named: "toolbar")
        calendarCorner.layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 캘린더 디자인 셋팅
        calendarView.locale = Locale(identifier: "ko_KR")
        
        calendarView.appearance.headerDateFormat = "yyyy년 MM월"
        calendarView.appearance.headerTitleFont = UIFont.systemFont(ofSize: 16, weight: .medium)
        calendarView.appearance.weekdayFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        calendarView.appearance.titleFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        calendarCorner.layer.borderWidth = 1
        calendarCorner.layer.cornerRadius = 24
        calendarCorner.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        calendarCorner.layer.borderColor = UIColor.systemGray5.cgColor
        
        // 오픈시 오늘 날짜로 뷰 셋팅
        selectDate(Date())
    }
    
    func filter(_ today: Date) {
        let format = DateFormatter()
        format.dateFormat = "yyyyMMdd"
        filtered = (efinList + rfinList).filter { format.string(from: $0.when) == format.string(from: today) }
        filtered.sort(by: { $0.when > $1.when })
    }
    
    func updateThisMonthTotalCost() -> [Int] {
        var rtotal = 0
        var etotal = 0
        
        if filtered.isEmpty {
            return [0, 0]
        } else {
            for i in filtered {
                if efinList.contains(i) {
                    etotal += i.how
                } else if rfinList.contains(i) {
                    rtotal += i.how
                }
            }
            return [etotal, rtotal]
        }
    }
    
    func selectDate(_ date: Date) {
        pickDate.text = date.onlydate()
        filter(date)
        updateThisMonthTotalCost()[0] == 0 ? (todayTotalCost.alpha = 0) : (todayTotalCost.alpha = 1)
        updateThisMonthTotalCost()[1] == 0 ? (todayTotalRCost.alpha = 0) : (todayTotalRCost.alpha = 1)
        
        todayTotalCost.text = "+ " + updateThisMonthTotalCost()[0].toDecimal() + " 원"
        todayTotalRCost.text = "- " + updateThisMonthTotalCost()[1].toDecimal() + " 원"
        tableView.reloadData()
    }
    
    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}



extension calendarVC: FSCalendarDelegate, FSCalendarDataSource, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectDate(date)
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        filter(date)
        
        let format = DateFormatter()
        format.dateFormat = "yyyyMMdd"
        var eDates: [String] = []
        for i in efinList {
            eDates.append(format.string(from: i.when))
        }
        var rDates: [String] = []
        for i in rfinList {
            rDates.append(format.string(from: i.when))
        }
        var eventNum: [Int] = [0, 0]
        if rDates.contains(format.string(from: date)) {
            eventNum[0] = 1
        }
        if eDates.contains(format.string(from: date)) {
            eventNum[1] = 1
        }
        
        switch eventNum {
        case [1, 1]:
            return [#colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1), event(date)]
        case [0, 1] :
            return [event(date)]
        case [1, 0]:
            return [#colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)]
        default:
            return [event(date)]
        }
    }
    
    func event(_ date: Date) -> UIColor {
        if date.toFullString() >= period.startDate.toFullString() && date.toFullString() <= period.endDate.toFullString() {
            
            if updateThisMonthTotalCost()[0] > percent(date)[1] {
                return .systemPink.withAlphaComponent(1)
            } else if updateThisMonthTotalCost()[0] > percent(date)[0] {
                return .systemPink.withAlphaComponent(0.6)
            } else {
                return .systemPink.withAlphaComponent(0.2)
            }
        } else {
            return #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        }
    }
    
    func percent(_ date: Date) -> [Int] {
        filter(date)
        let standard = Int(Double(purpose) / Double(Date().endOfMonth.onlydate())!)
        return [Int(Double(standard)), Int(Double(standard) * 1.5)]
    }
    
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let format = DateFormatter()
        format.dateFormat = "yyyyMMdd"
        var eDates: [String] = []
        for i in efinList {
            eDates.append(format.string(from: i.when))
        }
        var rDates: [String] = []
        for i in rfinList {
            rDates.append(format.string(from: i.when))
        }
        var eventNum: Int = 0
        if eDates.contains(format.string(from: date)) {
            eventNum += 1
        }
        if rDates.contains(format.string(from: date)) {
            eventNum += 1
        }
        return eventNum
    }
    
    func calendar(_ calendar: FSCalendar, titleFor date: Date) -> String? {
        
        switch date.toFullString() {
        case period.startDate.toFullString():
            return "시작"
        case period.endDate.toFullString():
            return "끝"
        case Date().toFullString():
            return "오늘"
        default:
            return nil
        }
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventSelectionColorsFor date: Date) -> [UIColor]? {
        filter(date)
        
        let format = DateFormatter()
        format.dateFormat = "yyyyMMdd"
        var eDates: [String] = []
        for i in efinList {
            eDates.append(format.string(from: i.when))
        }
        var rDates: [String] = []
        for i in rfinList {
            rDates.append(format.string(from: i.when))
        }
        var eventNum: [Int] = [0, 0]
        if rDates.contains(format.string(from: date)) {
            eventNum[0] = 1
        }
        if eDates.contains(format.string(from: date)) {
            eventNum[1] = 1
        }
        
        switch eventNum {
        case [1, 1]:
            return [#colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1), event(date)]
        case [0, 1] :
            return [event(date)]
        case [1, 0]:
            return [#colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)]
        default:
            return [event(date)]
        }
    }
    
  
}

extension calendarVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "daily", for: indexPath) as? dailyOutLay else {
            return UITableViewCell()
        }
        
        cell.setList(indexPath.row, filtered, rfinList)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

class dailyOutLay: UITableViewCell {
    
    @IBOutlet weak var what: UILabel!
    @IBOutlet weak var how: UILabel!
    
    func setList(_ int: Int, _ list: [finData], _ rlist: [finData]) {
        what.text = list[int].towhat
        how.text = (rlist.contains(list[int]) ? "+ " : "- ") + list[int].how.toDecimal()
    }
}
