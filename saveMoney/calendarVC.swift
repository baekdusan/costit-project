import UIKit
import FSCalendar

class calendarVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var calendarView: FSCalendar!
    @IBOutlet weak var pickDate: UILabel!
    @IBOutlet weak var todayTotalCost: UILabel!
    @IBOutlet weak var todayTotalRCost: UILabel!
    
    var finList: [finData] = []
    var finRList: [finData] = []
    var filtered: [finData] = []
    let dateFormatter = DateFormatter()
    var period = salaryDate()
    var purpose : Int = 0
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        tableView.layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 싱글톤으로 수입 내역 받기
        if let rData = UserDefaults.standard.value(forKey:"rFinList") as? Data {
            finRList = try! PropertyListDecoder().decode([finData].self, from: rData)
        }
        if let shared = revenue.shared.rFinList {
            finRList = shared
        }
        UserDefaults.standard.set(try? PropertyListEncoder().encode(finRList), forKey:"rFinList")
        
        // 싱글톤으로 지출 내역 받기
        if let eData = UserDefaults.standard.value(forKey:"eFinList") as? Data {
            finList = try! PropertyListDecoder().decode([finData].self, from: eData)
        }
        if let shared = expense.shared.eFinList {
            finList = shared
        }
        UserDefaults.standard.set(try? PropertyListEncoder().encode(finList), forKey:"eFinList")
        
        // 싱글톤으로 목표 금액 받기
        if let pp = UserDefaults.standard.value(forKey: "purpose") as? Int {
            purpose = pp
        }
        if let shared = expense.shared.purpose {
            purpose = shared
        }
        UserDefaults.standard.setValue(purpose, forKey: "purpose")
        
        // 캘린더 디자인 셋팅
        calendarView.appearance.headerTitleFont = UIFont.systemFont(ofSize: 16, weight: .medium)
        calendarView.appearance.titleFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        calendarView.appearance.weekdayFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        calendarView.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        calendarView.appearance.todayColor = UIColor.clear
        calendarView.appearance.titleDefaultColor = UIColor(named: "customLabel")
        calendarView.appearance.eventDefaultColor = #colorLiteral(red: 0.3518846035, green: 0.6747873425, blue: 0.622913003, alpha: 1)
        calendarView.appearance.eventSelectionColor = #colorLiteral(red: 0.3518846035, green: 0.6747873425, blue: 0.622913003, alpha: 1)
        calendarView.appearance.subtitleTodayColor = .label
        calendarView.appearance.subtitleFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        selectDate(Date())
        
        // 테이블 뷰 디자인 셋팅
        tableView.layer.borderWidth = 0.5
        tableView.layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    func filter(_ today: Date) {
        filtered = (finList + finRList).filter { dateFormatter.string(from: $0.when) == dateFormatter.string(from: today)  }
        filtered.sort(by: { $0.when > $1.when })
    }
    
    func updateThisMonthTotalCost() -> [Int] {
        var rtotal = 0
        var etotal = 0
        
        if filtered.isEmpty {
            return [0, 0]
        } else {
            for i in filtered {
                if finList.contains(i) {
                    etotal += i.how
                } else if finRList.contains(i) {
                    rtotal += i.how
                }
            }
            return [etotal, rtotal]
        }
    }
    
    func selectDate(_ date: Date) {
        pickDate.text = date.toString(false)
        filter(date)
        todayTotalCost.text = "- " + updateThisMonthTotalCost()[0].toDecimal() + " 원"
        todayTotalRCost.text = "+ " + updateThisMonthTotalCost()[1].toDecimal() + " 원"
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        tableView.tableFooterView = UIView.init(frame: .zero)
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
        if date.toFullString() >= period.startDate.toFullString() && date.toFullString() <= period.endDate.toFullString() {
            filter(date)
            if updateThisMonthTotalCost()[0] > percent(date)[1] {
                return [#colorLiteral(red: 0.8259984851, green: 0, blue: 0, alpha:  1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)]
            } else if updateThisMonthTotalCost()[0] > percent(date)[0] {
                return [#colorLiteral(red: 0.9756903052, green: 0.4849535823, blue: 0.5627821684, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)]
            } else {
                return [#colorLiteral(red: 0.9300299287, green: 0.8275253177, blue: 0.8353049159, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)]
            }
        } else {
            return [#colorLiteral(red: 0.3333333433, green: 0.3333333433, blue: 0.3333333433, alpha: 1)]
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
        for i in finList {
            eDates.append(format.string(from: i.when))
        }
        var rDates: [String] = []
        for i in finRList {
            rDates.append(format.string(from: i.when))
        }
        
        if eDates.contains(format.string(from: date)) && rDates.contains(format.string(from: date)) {
            return 2
        } else if eDates.contains(format.string(from: date)) || rDates.contains(format.string(from: date)) {
            return 1
        } else {
            return 0
        }
    }
    
    func calendar(_ calendar: FSCalendar, titleFor date: Date) -> String? {
        switch date.toFullString() {
        case period.startDate.toFullString():
            return "\(date.onlydate().toInt())일"
        case period.endDate.toFullString():
            return "\(date.onlydate().toInt())일"
        case Date().toFullString():
            return "오늘"
        default:
            return nil
        }
    }
    
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventSelectionColorsFor date: Date) -> [UIColor]? {
        if date.toFullString() >= period.startDate.toFullString() && date.toFullString() <= period.endDate.toFullString() {
            filter(date)
            if updateThisMonthTotalCost()[0] > percent(date)[1] {
                return [#colorLiteral(red: 0.8259984851, green: 0, blue: 0, alpha:  1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)]
            } else if updateThisMonthTotalCost()[0] > percent(date)[0] {
                return [#colorLiteral(red: 0.9756903052, green: 0.4849535823, blue: 0.5627821684, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)]
            } else {
                return [#colorLiteral(red: 0.9300299287, green: 0.8275253177, blue: 0.8353049159, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)]
            }
        } else {
            return [#colorLiteral(red: 0.3333333433, green: 0.3333333433, blue: 0.3333333433, alpha: 1)]
        }
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, borderDefaultColorFor date: Date) -> UIColor? {
        
        switch date.toFullString() {
        case period.startDate.toFullString():
            return UIColor(named: "toolbar")
        case period.endDate.toFullString():
            return UIColor(named: "toolbar")
        case Date().toFullString():
            return UIColor(named: "toolbar")
        default:
            return nil
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
        
        cell.setList(indexPath.row, filtered, finRList)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
}

class dailyOutLay: UITableViewCell {
    
    @IBOutlet weak var what: UILabel!
    @IBOutlet weak var how: UILabel!
    
    func setList(_ int: Int, _ list: [finData], _ rlist: [finData]) {
        what.text = list[int].towhat
        how.text = (rlist.contains(list[int]) ? "+ " : "- ") + list[int].how.toDecimal() + " 원"
    }
}
