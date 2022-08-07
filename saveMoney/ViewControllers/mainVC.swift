import UIKit
import WidgetKit

class mainVC: UIViewController {
    
    @IBOutlet weak var topView: UIView!
    // 남은 금액, 목표 금액
    @IBOutlet weak var balance: UILabel!
    @IBOutlet weak var balanceCondition: UILabel!

    @IBOutlet weak var collectionView: UICollectionView!
    // 수입 화면, 지출 입력 버튼
    @IBOutlet weak var revenueBorder: UIButton!
    @IBOutlet weak var addFinBorder: UIButton!
    
    // 지출 가계부
    var efinList: [finData] = [] {
        didSet { UserDefaults.standard.set(try? PropertyListEncoder().encode(efinList), forKey:"finlist")
            balanceCondition.text = "/ \(id.outLay.toDecimal()) 원" }
    }
    // 수입 가계부
    var rfinList: [finData] = [] {
        didSet { UserDefaults.standard.set(try? PropertyListEncoder().encode(rfinList), forKey:"rfinList") }
    }
    // 고정 지출 내역
    var fixedFinList: [FixedExpenditure] = [] {
        didSet { UserDefaults.standard.set(try? PropertyListEncoder().encode(fixedFinList), forKey: "fixedFinList") }
    }
    // 급여 날짜 저장
    var salaryData = salaryDate() {
        didSet { UserDefaults.standard.set(try? PropertyListEncoder().encode(salaryData), forKey: "salarydata") }
    }
    // 프로필 담기
    var id = profile() {
        didSet { UserDefaults.standard.set(try? PropertyListEncoder().encode(id), forKey: "profile") }
    }
    var isFirstOpen: Bool! // 앱 첫실행 감지
    var filteredList: [[finData]] = [] // 필터링된 가계부 데이터
    let gradientView = CAGradientLayer()
    
    var navTitle = UILabel()
    
    // 기록 확인을 위한 데이트 피커
    let datePicker = UIPickerView()
    let titleTouch = UITextField()
    
    // 데이트 피커가 담을 년/월
    var year : [Int] = []
    let month = [Int](1...12)
    
    // 지정 날짜의 Int값을 Date형식으로 변경해주기 전에 담는 곳
    var selectedYear: String = "2021"
    var selectedMonth: String = "01"
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        gradientView.removeFromSuperlayer()
        let colors: [CGColor] = [
            UIColor(named: "topViewColor")!.cgColor,
            UIColor(named: "backgroundColor")!.withAlphaComponent(0).cgColor
        ]
        gradientView.colors = colors
        topView.layer.addSublayer(gradientView)
    }
    
    // segue시 데이터 전달
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "addFinData" {
            let vc = segue.destination as! addFinVC
            vc.fromWhere = .expense
            vc.mode = .new
            vc.start = salaryData.startDate
            vc.end = salaryData.endDate
            vc.delegate = self
        } else if segue.identifier == "toRevenueVC" {
            let vc = segue.destination as! revenueVC
            vc.rdelegate = self
            vc.rfinList = rfinList
            vc.start = salaryData.startDate
            vc.end = salaryData.endDate
        } else if segue.identifier == "firstOpen" {
            let vc = segue.destination as! firstOpenVC
            vc.isFirstOpen = isFirstOpen
            vc.FODelegate = self
        } else if segue.identifier == "editProfile" {
            let vc = segue.destination as! firstOpenVC
            vc.profileData = id
            vc.FODelegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 탑뷰 그라데이션 주기
        gradientView.frame = topView.bounds
        let colors: [CGColor] = [
            UIColor(named: "topViewColor")!.cgColor,
            UIColor(named: "backgroundColor")!.withAlphaComponent(0).cgColor
        ]
        gradientView.colors = colors
        topView.layer.addSublayer(gradientView)
        collectionView.clipsToBounds = false
        
        // 지출 가계부 정보 받아오기
        if let fData = UserDefaults.standard.value(forKey:"finlist") as? Data {
            efinList = try! PropertyListDecoder().decode([finData].self, from: fData)
        }
        // 수입 가계부 정보 받아오기
        if let rfData = UserDefaults.standard.value(forKey: "rfinList") as? Data {
            rfinList = try! PropertyListDecoder().decode([finData].self, from: rfData)
        }
        // 고정 지출 정보 가져오기
        if let fFData = UserDefaults.standard.value(forKey: "fixedFinList") as? Data {
            fixedFinList = try! PropertyListDecoder().decode([FixedExpenditure].self, from: fFData)
        }
        // 프로필 데이터 받아오기
        if let pData = UserDefaults.standard.value(forKey: "profile") as? Data {
            id = try! PropertyListDecoder().decode(profile.self, from: pData)
        }
        // 급여 날짜 받아오기
        if let sData = UserDefaults.standard.value(forKey: "salarydata") as? Data {
            salaryData = try! PropertyListDecoder().decode(salaryDate.self, from: sData)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(savePinData(_:)), name: NSNotification.Name("toMainVC"), object: nil)
        
        // 오늘이 설정기간의 마지막 시간을 넘어가면, 프로필에서 설정해둔 날짜에 맞춰 새롭게 갱신
        if Date() > salaryData.endDate {
            salaryData.startDate = setSalaryDate(id.period).startDate
            salaryData.endDate = setSalaryDate(id.period).endDate
            UserDefaults.standard.set(try? PropertyListEncoder().encode(salaryData), forKey: "salarydata")
        }
        
        // 이번 달로 콜렉션 뷰 데이터 갱신
        filteredbyMonth(salaryData.startDate, salaryData.endDate)
        
        // 레이아웃 셋팅 (이름, 남은 금액, 목표 기간)
        balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원"
        balanceCondition.text = "/ \(id.outLay.toDecimal()) 원"
        
        self.collectionView.alwaysBounceVertical = true
        
        // 피커뷰 대리자 채택
        self.datePicker.dataSource = self
        self.datePicker.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        // 가계부 작성 버튼 곡률, 그림자 layout
        addFinBorder.btnLayout(false)
        revenueBorder.btnLayout(false)
        
        // 네비게이션 바 투명처리
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        
        // 네비게이션 바 타이틀 레이아웃 설정 및 터치 이벤트 부여
        navTitle.text = salaryData.startDate.toString(false) + " ~ " + salaryData.endDate.toString(false)
        navTitle.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        navTitle.textColor = UIColor(named: "customLabel")
        navTitle.sizeToFit()
        navigationItem.titleView = navTitle
        
        let titleTouch = UITapGestureRecognizer(target: self, action: #selector(changeDate))
        navTitle.isUserInteractionEnabled = true
        navTitle.addGestureRecognizer(titleTouch)
        
        // 첫 실행 감지
        isFirstOpen = UserDefaults.standard.bool(forKey: "firstOpen")
        if isFirstOpen == false {
            performSegue(withIdentifier: "firstOpen", sender: self)
        }
        
        // 데이트 피커가 담을 년 셋팅
        let setDateFormatter = DateFormatter()
        setDateFormatter.dateFormat = "yyyy"
        year = [Int](2021...Int(setDateFormatter.string(from: Date()))!)
        selectedYear = String(year[year.count - 1])
        
        // 데이트 피커가 담을 월 셋팅
        setDateFormatter.dateFormat = "MM"
        selectedMonth = setDateFormatter.string(from: Date())
        
        // 데이트 피커 default value 설정
        datePicker.selectRow(year.count - 1, inComponent: 0, animated: true)
        datePicker.selectRow(Int(selectedMonth)! - 1, inComponent: 1, animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        reset()
    }
    
    // calendarVC를 네비게이션 컨트롤러가 품은 뷰로 만들어서 모달로 Push
    @IBAction func calendarVCTapped(_ sender: UIBarButtonItem) {
        guard let vc = storyboard?.instantiateViewController(identifier: "calendarVC") as? calendarVC else { return }
        vc.efinList = efinList
        vc.rfinList = rfinList
        vc.pfinList = fixedFinList
        vc.id = id
        vc.period = salaryData
        
        let navigationController = UINavigationController(rootViewController: vc)
        navigationController.modalPresentationStyle = .fullScreen

        present(navigationController, animated: true)
    }
    
    // notification으로 변경된 보관함 배열 수신
    @objc func savePinData(_ notification: NSNotification){
        fixedFinList = notification.userInfo!["save"] as! [FixedExpenditure]
        UserDefaults.standard.set(try? PropertyListEncoder().encode(fixedFinList), forKey: "fixedFinList")
        }
    
    // 상단 네비게이션 타이틀을 클릭했을 때 데이트 피커 노출
    @objc func changeDate() {
        view.addSubview(titleTouch)
        
        let toolbar = UIToolbar()
        toolbar.barTintColor = UIColor(named: "topViewColor")
        toolbar.sizeToFit()
        
        let reset = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(reset))
        reset.tintColor = UIColor(named: "customLabel")
        let blank = UIBarButtonItem(systemItem: .flexibleSpace)
        let ok = UIBarButtonItem(title: "설정", style: .done, target: self, action: #selector(setDate))
        ok.tintColor = UIColor(named: "customLabel")
        
        toolbar.setItems([reset, blank, ok], animated: true)
        
        self.titleTouch.inputView = datePicker
        self.titleTouch.inputAccessoryView = toolbar

        titleTouch.becomeFirstResponder()
    }
    
    // 초기화(이번 달 설정 날짜로 필터링)
    @objc func reset() {
        // 이번 달로 콜렉션 뷰 데이터 갱신
        filteredbyMonth(salaryData.startDate, salaryData.endDate)
        
        // 레이아웃 셋팅 (이름, 남은 금액, 목표 기간)
        navTitle.text = salaryData.startDate.toString(false) + " ~ " + salaryData.endDate.toString(false)
        navTitle.sizeToFit()
        
        balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원"
        balanceCondition.text = "/ \(id.outLay.toDecimal()) 원"
        
        collectionView.reloadData()
        titleTouch.resignFirstResponder()
    }
    
    // 원하는 날짜로 필터링
    @objc func setDate() {
        
        let stringDate = selectedYear + selectedMonth
        
        // 필터링할 시간의 앞과 뒤
        let start = stringDate.toDate()!.startOfMonth
        let end = stringDate.toDate()!.endOfMonth
        
        // 필터링 후 레이아웃 셋팅(사용한 총액, 날짜)
        filteredbyMonth(start, end) // 이번 달에 맞춰서 filteredList 할당
        balance.text = updateThisMonthTotalCost().toDecimal() + " 원"
        balanceCondition.text = "이만큼 사용했어요"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        let settingDate = formatter.string(from: stringDate.toDate()!)

        navTitle.text =  "🗓 " + settingDate
        navTitle.sizeToFit()
        navigationItem.titleView = navTitle
        
        // 콜렉션뷰 갱신, 키보드 내리기, 지출 입력 금지
        
        collectionView.reloadData()
        titleTouch.resignFirstResponder()
    }

    
    // 급여일을 설정했을 때 그걸 바탕으로 한달의 지출 기간을 셋팅
    func setSalaryDate(_ salary: String) -> salaryDate {
        switch salary {
        case "1일":
            
            return salaryDate(startDate: Date().startOfMonth, endDate: Date().endOfMonth)
        case "마지막 날", "마지막날":
            
            return salaryDate(startDate: Date().endofLastMonth, endDate: Date().yesterDayofLastDayofMonth)
        default:
            
            let int = salary.map { String($0) }
            let salaryDay = Int(int[0..<int.count - 1].joined())!
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko")
            formatter.dateFormat = "dd"
            let today = Int(formatter.string(from: Date()))!
            
            if today >= salaryDay {
                return salaryDate(startDate: Date().startOfSomeDay(salaryDay), endDate: Date().endOfSomeDay(salaryDay))
            } else {
                return salaryDate(startDate: Date().startOfLastSomeDay(salaryDay), endDate: Date().endOfLastSomeDay(salaryDay))
            }
        }
    }
    
    // 이번 달 기준으로 리스트 필터링, 남은 금액, 그리고 재정 상태 표시
    func updateLayout() {
        navTitle.text = salaryData.startDate.toString(false) + " ~ " + salaryData.endDate.toString(false)
        navTitle.sizeToFit()
        
        filteredbyMonth(salaryData.startDate, salaryData.endDate) // 이번 달에 맞춰서 filteredList 할당
        balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원" // 남은 금액 = 목표 금액 - 이번 달 총 지출 비용
        balanceCondition.text = "/ \(id.outLay.toDecimal()) 원"
        
        // 콜렉션뷰 갱신, 위젯 갱신
        collectionView.reloadData()
        towidget()
    }

    // 이번 달의 전체 지출 비용
    func updateThisMonthTotalCost() -> Int {
        
        var total = 0
        if filteredList.isEmpty {
            return 0
        } else {
            for i in filteredList {
                for j in i {
                    total += j.how
                }
            }
            return total
        }
    }
    
    // 현재 급여기간에 담아서 filteredList에 담는 메서드
    func filteredbyMonth(_ startDate: Date, _ endDate: Date) {
        
        let filtered = efinList.filter { $0.when >= startDate && $0.when <= endDate}
        var day: Set<String> = []
        
        for i in filtered {
            day.insert(i.when.toFullString())
        }
        
        filteredList.removeAll()
        
        for j in day {
            var list: [finData] = []
            list = filtered.filter { $0.when.toFullString() == j }
            filteredList.append(list)
        }
        
        filteredList.sort { $0[0].when > $1[0].when }
    }
    
    // 가계부 삭제 버튼
    @objc func cancelButtonAction(sender : UIButton) {
        let section = sender.tag / 1000
        let row = sender.tag % 1000
        
        let alert = UIAlertController(title: "삭제", message: "해당 지출 내역을 삭제해요.", preferredStyle: .alert)
        
        let cancel = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let ok = UIAlertAction(title: "확인", style: .default, handler: { _ in self.deleteExpenseFinData(section, row) })
        
        alert.addAction(cancel)
        alert.addAction(ok)
        
        present(alert, animated: true)
    }
    
    func deleteExpenseFinData(_ section: Int, _ row: Int) {
        collectionView.performBatchUpdates({
            
            collectionView.deleteItems(at: [IndexPath.init(row: row, section: section)])
            let removedData = filteredList[section].remove(at: row)
            
            if filteredList[section].isEmpty {
                collectionView.deleteSections([section])
                filteredList.remove(at: section)
            }
            
            efinList.remove(at: efinList.firstIndex(where: {$0 == removedData})!)
            
            balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원"
            balanceCondition.text = "/ \(id.outLay.toDecimal()) 원"
            towidget()
            
        }, completion: { [self] _ in
            collectionView.reloadData()})
    }
    
    // 수정 버튼(꾹 누르는 제스처)
    @objc func longPress(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {

        if longPressGestureRecognizer.state == UIGestureRecognizer.State.began {
            let touchPoint = longPressGestureRecognizer.location(in: collectionView)
            if let index = collectionView.indexPathForItem(at: touchPoint) {
                let section = index[0]
                let row = index[1]
                guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "addFinData") as? addFinVC else { return }
                vc.modalPresentationStyle = .overFullScreen
                vc.fromWhere = .expense
                vc.mode = .edit
                vc.originData = filteredList[section][row]
                vc.delegate = self
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    // 위젯으로 데이터 전송
    func towidget() {
        if let wdata = UserDefaults.init(suiteName: "group.costit") {
            let stringData: [String] = [id.nickName + "님", (id.outLay - updateThisMonthTotalCost()).toDecimal() + "원", id.outLay > updateThisMonthTotalCost() ? "남았어요" : "망했어요", Double(id.outLay) != 0 ? String(Int(Double(id.outLay - updateThisMonthTotalCost()) / Double(id.outLay) * 100)) : "0"]
            wdata.setValue(stringData, forKey: "string")
        }
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        } else {
        }
    }
}

extension mainVC: sendFinData, shareRevenueFinList, FODelegate, FixedFinDataDelegate {
    func fixedFinData(_ controller: fixedExpenditureVC, _ fixedData: [FixedExpenditure]) {
        fixedFinList = fixedData
    }
    
    // 앱 첫 오픈시에 데이터 입력을 넘겨받는 프로토콜
    func initialData(_ controller: firstOpenVC, _ nickName: String, _ pm: Int, _ salary: String) {
        
        // 첫 실행 저장
        isFirstOpen = true
        UserDefaults.standard.setValue(isFirstOpen, forKey: "firstOpen")
        
        // 프로필 셋팅
        id = profile(nickName: nickName, outLay: pm, period: salary)
        
        // 레이아웃
        // 1. 기준일
        salaryData.startDate = setSalaryDate(salary).startDate
        salaryData.endDate = setSalaryDate(salary).endDate
        navigationItem.title = salaryData.startDate.toString(false) + " ~ " + salaryData.endDate.toString(false)
        // 2. 남은 금액 및 상태
        updateLayout()
    }
    
    // 데이터 추가 뷰에서 넘겨받는 프로토콜
    func sendFinanceSource(_ controller: addFinVC, _ originData: finData, _ revisedData: finData) {
        
        // 일반적인 추가
        if originData == revisedData {
            efinList.append(revisedData)
        // 수정일 때 -> 원래 데이터 삭제 후, 새로운 데이터 추가
        } else {
            let removedData = originData
            efinList.remove(at: efinList.firstIndex(where: {$0 == removedData})!)
            efinList.append(revisedData)
        }
        updateLayout()
    }
    
    // 수입 가계부에서 받는 프로토콜
    func sendRFinList(_ viewController: revenueVC, _ rFinList: [finData]) {
        rfinList = rFinList
    }
}

extension mainVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    
    // 섹션 개수 -> 최대 31개(한달 최대 일수)
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return filteredList.count
    }
    
    // 섹션당 로우 개수
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredList[section].count
    }
    
    // 컬렉션 뷰 레이아웃
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let deepTouchGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fincell", for: indexPath) as? finCell else {
            return UICollectionViewCell()
        }
        
        cell.updateUI(filteredList, indexPath.section, indexPath.row)
        cell.makeShadow()
        cell.dismiss.tag = indexPath.section * 1000 + indexPath.row
        cell.dismiss.addTarget(self, action: #selector(cancelButtonAction(sender:)), for: .touchUpInside)
        cell.border.addGestureRecognizer(deepTouchGesture)
        return cell
    }
    
    // 컬렉션 헤더 뷰 레이아웃
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as? header else { return UICollectionReusableView() }
            
            header.updateHeader(filteredList, indexPath.section)
            return header
        } else {
            return UICollectionReusableView()
        }
    }
    
    // 메모지 크기 설정(정사각형)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = (view.bounds.width - 48) * 0.5
        let height = width
        
        return CGSize(width: width, height: height)
    }
}

// 컬렉션 뷰 셀 클래스
class finCell: UICollectionViewCell {
    
    @IBOutlet weak var border: UIView!
    @IBOutlet weak var when: UILabel!
    @IBOutlet weak var towhat: UILabel!
    @IBOutlet weak var how: UILabel!
    @IBOutlet weak var dismiss: UIButton!
    
    func updateUI(_ model: [[finData]], _ section: Int, _ row: Int) {
        
        when.text = model[section][row].when.toString(false)
        towhat.text = model[section][row].towhat
        let money: Int = model[section][row].how
        money == 0 ? (how.text = "무료") : (how.text = "- " + money.toDecimal())
        
    }
    
    func makeShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.masksToBounds = false
    }
}

// 컬렉션 헤더 뷰 클래스
class header: UICollectionReusableView {
    @IBOutlet weak var headerDate: UILabel!
    @IBOutlet weak var todayTotal: UILabel!
    
    func updateHeader(_ arr: [[finData]], _ index: Int) {
        var todaytotal = 0
        headerDate.text = arr[index][0].when.onlydate() + "일"
        for i in arr[index] {
            todaytotal += i.how
        }
        todayTotal.text = todaytotal.toDecimal() + "원"
    }
}

extension mainVC : UIScrollViewDelegate {
    
    // 스크롤이 시작될 때
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.addFinBorder.btnLayout(true)
        self.revenueBorder.btnLayout(true)
        self.titleTouch.resignFirstResponder()
    }
    
    // 스크롤이 끝에 닿았을 때
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            animations:
                {
                    self.addFinBorder.btnLayout(false)
                    self.revenueBorder.btnLayout(false)
                },
            completion: nil
        )
    }
    
    // 스크롤뷰에서 손을 뗐을 때
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            animations:
                {
                    self.addFinBorder.btnLayout(false)
                    self.revenueBorder.btnLayout(false)
                },
            completion: nil
        )
    }
    
    // 맨 위로 스크롤이 올라갈 때 (상단 상태바 중앙 터치 시)
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            animations:
                {
                    self.addFinBorder.btnLayout(false)
                    self.revenueBorder.btnLayout(false)
                },
            completion: nil
        )
    }
}

// 데이트 피커 뷰 델리게이트
extension mainVC: UIPickerViewDelegate, UIPickerViewDataSource {
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        switch component {
        case 0:
            return year.count
        case 1:
            return month.count
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch component {
        case 0:
            return "\(year[row])년"
        case 1:
            return "\(month[row])월"
        default:
            return ""
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        2
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
          case 0:
              selectedYear = String(year[row])
          case 1:
              selectedMonth = String(format: "%02d", month[row])
          default:
              break
          }
    }
}
