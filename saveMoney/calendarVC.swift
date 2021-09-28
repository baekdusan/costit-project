import UIKit
import FSCalendar

class calendarVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var calendarView: FSCalendar!
    @IBOutlet weak var pickDate: UILabel!
    @IBOutlet weak var todayTotalCost: UILabel!
    
    var finList: [finData] = []
    var filtered: [finData] = []
    let dateFormatter = DateFormatter()
    var period = salaryDate()
    var purpose : Int = 0
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        tableView.layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        tableView.layer.borderWidth = 0.5
        tableView.layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    func filter(_ today: Date) {
        filtered = finList.filter { dateFormatter.string(from: $0.when) == dateFormatter.string(from: today)  }
        filtered.sort(by: { $0.when > $1.when })
    }
    
    func updateThisMonthTotalCost() -> Int {
        var total = 0
        
        if filtered.isEmpty {
            return 0
        } else {
            for i in filtered {
                total += i.how
            }
            return total
        }
    }
    
    func isEnough() -> UIColor {
        return .white
    }
    
    func selectDate(_ date: Date) {
        pickDate.text = date.toString(false)
        filter(date)
        todayTotalCost.text = updateThisMonthTotalCost().toDecimal() + " 원"
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
            if updateThisMonthTotalCost() > percent(date)[1] {
                return [#colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)]
            } else if updateThisMonthTotalCost() > percent(date)[0] {
                return [#colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)]
            } else {
                return [#colorLiteral(red: 0.3518846035, green: 0.6747873425, blue: 0.622913003, alpha: 1)]
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
        
        var dates: [String] = []
        for i in finList {
            dates.append(format.string(from: i.when))
        }
        
        if dates.contains(format.string(from: date)) {
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
            if updateThisMonthTotalCost() > percent(date)[1] {
                return [#colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)]
            } else if updateThisMonthTotalCost() > percent(date)[0] {
                return [#colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)]
            } else {
                return [#colorLiteral(red: 0.3518846035, green: 0.6747873425, blue: 0.622913003, alpha: 1)]
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
        
        cell.setList(indexPath.row, filtered)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.bounds.height / 3
    }
}

class dailyOutLay: UITableViewCell {
    
    @IBOutlet weak var what: UILabel!
    @IBOutlet weak var how: UILabel!
    
    func setList(_ int: Int, _ list: [finData]) {
        what.text = list[int].towhat
        how.text = "- " + list[int].how.toDecimal() + " 원"
    }
}
