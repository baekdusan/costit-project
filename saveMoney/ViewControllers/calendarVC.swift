import UIKit
import FSCalendar
import SwiftUI

class calendarVC: UIViewController {
    
    @IBOutlet weak var totalBorder: UIStackView!
    @IBOutlet weak var rTotal: UILabel!
    @IBOutlet weak var eTotal: UILabel!
    @IBOutlet weak var pTotal: UILabel!
    
    @IBOutlet weak var calendarView: FSCalendar!
    @IBOutlet weak var tableView: UITableView!
   
    @IBOutlet weak var pickDate: UILabel!
    @IBOutlet weak var todayTotalCost: UILabel!
    @IBOutlet weak var todayTotalRCost: UILabel!
    @IBOutlet weak var calendarCorner: UIView!
    
    var efinList: [finData] = []
    var rfinList: [finData] = []
    var pfinList: [FixedExpenditure] = []
    var filtered: [finData] = []
    let dateFormatter = DateFormatter()
    var period = salaryDate()
    var purpose : Int = 0
    var nickName : String = "User"
    
    let navTitle = UILabel()
    
    // 다크 라이트 전환시 적용
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        calendarView.appearance.selectionColor = UIColor(named: "calendarBgColor")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setNavigationBar()
        
        calendarView.layer.shadowColor = UIColor.black.cgColor
        calendarView.layer.shadowOpacity = 0.08
        calendarView.layer.shadowOffset = CGSize(width: 0, height: 4)
        calendarView.layer.masksToBounds = false
        
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 캘린더 디자인 셋팅
        calendarView.locale = Locale(identifier: "ko_KR")
        
        calendarView.appearance.headerDateFormat = "yyyy년 MM월"
        calendarView.appearance.headerTitleFont = UIFont.systemFont(ofSize: 16, weight: .medium)
        calendarView.appearance.weekdayFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        calendarView.appearance.titleFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        calendarCorner.layer.cornerRadius = 20
        calendarCorner.layer.shadowColor = UIColor.black.cgColor
        calendarCorner.layer.shadowOpacity = 0.08
        calendarCorner.layer.shadowOffset = CGSize(width: 0, height: -4)
        calendarCorner.layer.masksToBounds = false
        
        // 오픈시 오늘 날짜로 뷰 셋팅
        calendarView.select(Date())
        selectDate(Date())
        
        rTotal.text = filteredbyMonth(period.startDate, period.endDate, list: rfinList)
        eTotal.text = filteredbyMonth(period.startDate, period.endDate, list: efinList)
        pTotal.text = totalF(pfinList)
        
        tableCellBorderLayout(totalBorder)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        todayTotalCost.text = "- " + updateThisMonthTotalCost()[0].toDecimal() + " 원"
        todayTotalRCost.text = "+ " + updateThisMonthTotalCost()[1].toDecimal() + " 원"
        
        tableView.reloadData()
        
        if updateThisMonthTotalCost()[0] * updateThisMonthTotalCost()[1] == 0 {
            
            if updateThisMonthTotalCost()[0] == 0 {
                todayTotalRCost.alpha = 1
            } else {
                todayTotalRCost.alpha = 0
            }
            
            if updateThisMonthTotalCost()[1] == 0 {
                todayTotalCost.alpha = 1
            } else {
                todayTotalCost.alpha = 0
            }
        } else {
            todayTotalCost.alpha = 1
            todayTotalRCost.alpha = 1
        }
    }
    
    func setNavigationBar() {
        
        // 버튼 사이즈 조정
        let symbolScale = UIImage.SymbolConfiguration(scale: .medium)
        
        // 네비게이션 경계 없애기
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        // 왼쪽 버튼(검색 버튼)
        let searchImage = UIImage(systemName: "magnifyingglass", withConfiguration: symbolScale)
        let searchVCBtn = UIBarButtonItem(image: searchImage, style: .plain, target: self, action: #selector(toSearchVC))
        let pinImage = UIImage(systemName: "pin.fill", withConfiguration: symbolScale)
        let pinVCBtn = UIBarButtonItem(image: pinImage, style: .plain, target: self, action: #selector(toPinVC))
        
        // 타이틀
        navTitle.font = .systemFont(ofSize: 13, weight: .bold)
        navTitle.textColor = UIColor(named: "customLabel")
        self.navigationItem.titleView = navTitle
        
        // 오른쪽 버튼(dismiss)
        let rightImage = UIImage(systemName: "xmark", withConfiguration: symbolScale)
        let rightBtn = UIBarButtonItem(image: rightImage, style: .done, target: self, action: #selector(dismissVC) )
        
        self.navigationItem.leftBarButtonItems = [searchVCBtn, pinVCBtn]
        self.navigationItem.leftBarButtonItems?.forEach {
            $0.tintColor = UIColor(named: "customLabel")
        }
        self.navigationItem.rightBarButtonItem = rightBtn
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "customLabel")
        
        let dday = Date().dDay(period.endDate)
        
        switch dday {
        case 0:
            navTitle.text = "오늘이 마지막이에요!"
        case 1:
            navTitle.text = "하루 남았어요"
        default:
            navTitle.text = "\(dday)일 남았어요"
        }
    }
    
    @objc func toSearchVC() {
        guard let searchVC = storyboard?.instantiateViewController(withIdentifier: "searchVC") as? searchVC else { return }
        searchVC.efinList = efinList
        searchVC.rfinList = rfinList
        
        navigationController?.pushViewController(searchVC, animated: true)
    }
    
    @objc func toPinVC() {
        guard let pinVC = storyboard?.instantiateViewController(withIdentifier: "fixedExpenditureVC") as? fixedExpenditureVC else { return }
        pinVC.fixedData = pfinList
        pinVC.fixedDelegate = self
        pinVC.modalPresentationStyle = .fullScreen
        
        self.present(pinVC, animated: true)
    }
    
    @objc func dismissVC() {
        self.dismiss(animated: true)
    }
}

extension calendarVC: FixedFinDataDelegate {
    func fixedFinData(_ controller: fixedExpenditureVC, _ fixedData: [FixedExpenditure]) {
        self.pfinList = fixedData
        pTotal.text = totalF(pfinList)
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
        if date >= period.startDate && date <= period.endDate {
            
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

extension calendarVC {
    func filteredbyMonth(_ startDate: Date, _ endDate: Date, list: [finData]) -> String {
        
        let filtered = list.filter { $0.when >= startDate && $0.when <= endDate}
        
        var total = 0
        
        for i in filtered {
            total += i.how
        }
        
        return total.toDecimal()
    }
    
    func totalF(_ list: [FixedExpenditure]) -> String {
        var total = 0
        for i in list {
            total += i.how
        }
        
        return total.toDecimal()
    }
    
    func tableCellBorderLayout(_ stackView : UIStackView) {
        let border = UIView()
        border.backgroundColor = .systemGray6
        border.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        border.frame = CGRect(x: 10, y: stackView.frame.height + 19.25, width: stackView.frame.width - 20, height: 1.5)
        border.layer.masksToBounds = false
        stackView.addSubview(border)
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
