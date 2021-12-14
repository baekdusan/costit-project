import UIKit
import WidgetKit

class mainVC: UIViewController, sendFinData, shareRevenueFinList, FODelegate {
    
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
        navigationItem.title = salaryData.startDate.toString(false) + " - " + salaryData.endDate.toString(false)
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
    @IBOutlet weak var editbtn: UIBarButtonItem!
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var balance: UILabel! // 남은 금액
    @IBOutlet weak var balanceCondition: UILabel! // "목표 금액"
    
    @IBOutlet weak var collectionView: UICollectionView! // 콜렉션뷰
    @IBOutlet weak var addFinBorder: UIButton!
    
    // 지출 가계부
    var efinList: [finData] = [finData(when: Date(), towhat: "코스트잇 다운로드😎", how: 1200)] {
        didSet {
            // 가계부 데이터 변경시마다 저장 및 상태 변경
            UserDefaults.standard.set(try? PropertyListEncoder().encode(efinList), forKey:"finlist")
            balanceCondition.text = "/ \(id.outLay.toDecimal()) 원"
        }
    }
    // 수입 가계부
    var rfinList: [finData] = [] {
        didSet {
            // 가계부 데이터 변경시마다 저장 및 상태 변경
            UserDefaults.standard.set(try? PropertyListEncoder().encode(rfinList), forKey:"rfinList")
        }
    }
    var salaryData = salaryDate() {
        // 급여 날짜 저장
        didSet {
            UserDefaults.standard.set(try? PropertyListEncoder().encode(salaryData), forKey: "salarydata")
        }
    }
    var id = profile() {
        // 프로필 담기
        didSet {
            UserDefaults.standard.set(try? PropertyListEncoder().encode(id), forKey: "profile")
        }
    }
    var isFirstOpen: Bool! // 앱 첫실행 감지
    var filteredList: [[finData]] = [] // 필터링된 가계부 데이터
    var isEditEnabled: Bool = false // 편집 가능 여부
    var isEditMode: Bool = false // 편집 모드 여부
    var pullRefresh = UIRefreshControl()
    
    // segue시 데이터 전달
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "addFinData" {
            
            let vc = segue.destination as! addFinVC
            vc.start = salaryData.startDate
            vc.end = salaryData.endDate
            vc.delegate = self
        } else if segue.identifier == "toRevenueVC" {
            
            let vc = segue.destination as! revenueVC
            vc.rdelegate = self
            vc.rfinList = rfinList
            vc.start = salaryData.startDate
            vc.end = salaryData.endDate
        } else if segue.identifier == "calendar" {
            
            let vc = segue.destination as! calendarVC
            vc.efinList = efinList
            vc.rfinList = rfinList
            vc.purpose = id.outLay
            vc.period = salaryData
        } else if segue.identifier == "firstOpen" {
            
            let vc = segue.destination as! firstOpenVC
            vc.FODelegate = self
        } else if segue.identifier == "editProfile" {
            
            let vc = segue.destination as! firstOpenVC
            vc.profileData = id
            vc.FODelegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 가계부 작성 버튼 곡률, 그림자 layout
        addFinBorder.btnLayout(false)
        
        // 지출 가계부 정보 받아오기
        if let fData = UserDefaults.standard.value(forKey:"finlist") as? Data {
            efinList = try! PropertyListDecoder().decode([finData].self, from: fData)
        }
        // 수입 가계부 정보 받아오기
        if let rfData = UserDefaults.standard.value(forKey: "rfinList") as? Data {
            rfinList = try! PropertyListDecoder().decode([finData].self, from: rfData)
        }
        // 프로필 데이터 받아오기
        if let pData = UserDefaults.standard.value(forKey: "profile") as? Data {
            id = try! PropertyListDecoder().decode(profile.self, from: pData)
        }
        // 급여 날짜 받아오기
        if let sData = UserDefaults.standard.value(forKey: "salarydata") as? Data {
            salaryData = try! PropertyListDecoder().decode(salaryDate.self, from: sData)
        }
        
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        // 네비게이션 바 투명처리
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        
        // 네비게이션 바 타이틀 레이아웃 설정
        let title = UILabel()
        title.text = salaryData.startDate.toString(false) + " - " + salaryData.endDate.toString(false)
        title.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        title.textColor = UIColor(named: "customLabel")
        navigationItem.titleView = title
        
        // 첫 실행 감지
        isFirstOpen = UserDefaults.standard.bool(forKey: "firstOpen")
        if isFirstOpen == false {
            performSegue(withIdentifier: "firstOpen", sender: self)
        }
    }
    
    @IBAction func addFinbtn(_ sender: Any) {
    }
    
    @IBAction func edit(_ sender: UIBarButtonItem) {
        if isEditEnabled == false {
                isEditEnabled = true
            editbtn.image = UIImage(systemName: "lock.open.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium))
        } else {
            isEditEnabled = false
            isEditMode = false
            editbtn.image = UIImage(systemName: "lock.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .medium))
        }
        
        collectionView.reloadData()
    }
    
    // 급여일을 설정했을 때 그걸 바탕으로 한달의 지출 기간을 셋팅
    func setSalaryDate(_ salary: String) -> salaryDate {
        switch salary {
        case "1일":
            
            return salaryDate(startDate: Date().startOfMonth, endDate: Date().endOfMonth)
        case "마지막날":
            
            return salaryDate(startDate: Date().endofLastMonth, endDate: Date().endOfMonth)
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
        
        collectionView.performBatchUpdates({
            
            collectionView.deleteItems(at: [IndexPath.init(row: row, section: section)])
            let removedStr = filteredList[section].remove(at: row)
            efinList.remove(at: efinList.firstIndex(where: {$0 == removedStr})!)
            
            balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원"
            balanceCondition.text = "/ \(id.outLay.toDecimal()) 원"
            towidget()
            
            isEditMode = true
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
                print(filteredList[section][row])
                guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "addFinData") as? addFinVC else { return }
                vc.modalPresentationStyle = .overFullScreen
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

extension mainVC: UICollectionViewDelegate, UICollectionViewDataSource {

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
        
        if isEditEnabled {
            if !isEditMode {
                cell.dismiss.transform = CGAffineTransform(scaleX: 0, y: 0)
                UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: .curveLinear, animations: {
                    cell.dismiss.alpha = 1.0;
                    cell.dismiss.transform = .identity
                }, completion: nil)
            }
        } else {
            cell.dismiss.alpha = 0
        }
        return cell
    }
    
    // 컬렉션 헤더 뷰 레이아웃
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as? header else { return UICollectionReusableView() }
            
            headerView.updateHeader(filteredList, indexPath.section)
            return headerView
        default: assert(false, "nil")
        }
        
        return UICollectionReusableView()
    }
}

// 컬렉션 뷰 크기, 위치
extension mainVC: UICollectionViewDelegateFlowLayout {
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
        how.text = "- " + model[section][row].how.toDecimal()
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
        if arr[index].isEmpty {
            headerDate.text = "정말?"
        } else {
            headerDate.text = arr[index][0].when.onlydate() + "일"

            for i in arr[index] {
                todaytotal += i.how
            }
        }
        todayTotal.text = "₩ " + todaytotal.toDecimal()
    }
}

extension mainVC : UIScrollViewDelegate {
    
    // 스크롤이 시작될 때
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.addFinBorder.btnLayout(true)
    }
    
    // 스크롤이 끝에 닿았을 때
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        UIView.animate(withDuration: 0.6, delay: 0, animations: { self.addFinBorder.btnLayout(false) }, completion: nil)
    }
    
    // 스크롤뷰에서 손을 뗐을 때
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        UIView.animate(withDuration: 0.6, delay: 0, animations: { self.addFinBorder.btnLayout(false) }, completion: nil)
    }
    
    // 맨 위로 스크롤이 올라갈 때 (상단 상태바 중앙 터치 시)
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        UIView.animate(withDuration: 0.6, delay: 0, animations: { self.addFinBorder.btnLayout(false) }, completion: nil)
    }
}
