import UIKit
import WidgetKit

class mainVC: UIViewController, sendFinData, FODelegate {
    
    // 앱 첫 오픈시에 데이터 입력을 넘겨받는 프로토콜
    func initialData(_ controller: firstOpenVC, _ nickName: String, _ pm: Int, _ salary: String) {
        
        // 첫 실행 저장
        isFirstOpen = true
        UserDefaults.standard.setValue(isFirstOpen, forKey: "firstOpen")
        
        // 프로필 셋팅 및 저장
        id = profile(nickName: nickName, outLay: pm, period: salary)
        UserDefaults.standard.set(try? PropertyListEncoder().encode(id), forKey: "profile")
        
        // 레이아웃 셋팅 (닉네임, 남은 금액, 목표 기간 셋팅)
        
        self.nickName.text = id.nickName + ","
        
        salaryData.startDate = setSalaryDate(salary).startDate
        salaryData.endDate = setSalaryDate(salary).endDate
        UserDefaults.standard.set(try? PropertyListEncoder().encode(salaryData), forKey: "salarydata")
        navigationItem.title = salaryData.startDate.toString(false) + " - " + salaryData.endDate.toString(false)
        
        filteredbyMonth(salaryData.startDate, salaryData.endDate) // 이번 달에 맞춰서 filteredList 할당
        balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원" // 남은 금액 = 목표 금액 - 이번 달 총 지출 비용
        if Int(id.outLay - updateThisMonthTotalCost()) < 0 {
            balanceCondition.text = "망했어요"
        }
        
        collectionView.reloadData() // 콜렉션 뷰 filteredFinList로 갱신
        towidget()
    }
    
    // 데이터 추가 뷰에서 넘겨받는 프로토콜
    func sendFinanceSource(_ controller: addFinVC, _ data: finData) {
        
        finList.append(data) // finList에 추가
        filteredbyMonth(salaryData.startDate, salaryData.endDate) // 이번 달에 맞춰서 filteredList 할당
        balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원" // 남은 금액 = 목표 금액 - 이번 달 총 지출 비용
        if Int(id.outLay - updateThisMonthTotalCost()) < 0 {
            balanceCondition.text = "망했어요."
        }
        
        collectionView.reloadData() // 콜렉션 뷰 filteredFinList로 갱신
        towidget()
    }
    
    @IBOutlet weak var nickName: UILabel! // 닉네임 라벨
    @IBOutlet weak var balance: UILabel! // 남은 금액
    @IBOutlet weak var balanceCondition: UILabel! // "남았어요.", "망했어요."
    
    @IBOutlet weak var collectionView: UICollectionView! // 콜렉션뷰
    @IBOutlet weak var addFinBorder: UIButton!
    
    // 전체 가계부
    var finList: [finData] = [] {
        didSet {
            UserDefaults.standard.set(try? PropertyListEncoder().encode(finList), forKey:"finlist")
            if Int(id.outLay - updateThisMonthTotalCost()) < 0 {
                balanceCondition.text = "망했어요."
            }
        }
    }
    var salaryData = salaryDate() // 급여 날짜 저장
    var id = profile() // 프로필 담기
    var isFirstOpen: Bool!
    var filteredList: [[finData]] = []
    
    // 스크롤 효과 최대, 최소 높이 (보류)
    var MaxTopHeight: CGFloat!
    var MinTopHeight: CGFloat!
    
    // segue시 데이터 전달
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "addFinData" {
            let vc = segue.destination as! addFinVC
            vc.start = salaryData.startDate
            vc.end = salaryData.endDate
            vc.delegate = self
        } else if segue.identifier == "calendar" {
            let vc = segue.destination as! calendarVC
            vc.finList = finList
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
        
//        MaxTopHeight = collectionView.frame.origin.y - (period.layer.bounds.height + 40) - view.safeAreaInsets.top
//        MinTopHeight = (period.layer.bounds.height + 40) + view.safeAreaInsets.top
//        viewTopHeight.constant = MaxTopHeight

        // 가계부 작성 버튼 곡률, 그림자 layout
        addFinBorder.layer.cornerRadius = 32
        addFinBorder.layer.shadowColor = UIColor.black.cgColor
        addFinBorder.layer.shadowOffset = CGSize(width: 0, height: 4)
        addFinBorder.layer.shadowRadius = 5
        addFinBorder.layer.shadowOpacity = 0.2
        addFinBorder.layer.masksToBounds = false
        
        // 가계부 정보 받아오기
        if let fData = UserDefaults.standard.value(forKey:"finlist") as? Data {
            finList = try! PropertyListDecoder().decode([finData].self, from: fData)
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
        nickName.text = id.nickName + ","
        balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원"
        if Int(id.outLay - updateThisMonthTotalCost()) < 0 {
            balanceCondition.text = "망했어요."
        }
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
        
        let filtered = finList.filter { $0.when >= startDate && $0.when <= endDate}
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
        collectionView.performBatchUpdates({
            
            let section = sender.tag / 1000
            let row = sender.tag % 1000
            
            collectionView.deleteItems(at: [IndexPath.init(row: row, section: section)])
            let removedStr = filteredList[section].remove(at: row)
            finList.remove(at: finList.firstIndex(where: {$0 == removedStr})!)
            
            balance.text = Int(id.outLay - updateThisMonthTotalCost()).toDecimal() + " 원"
            if Int(id.outLay - updateThisMonthTotalCost()) < 0 {
                balanceCondition.text = "망했어요."
            } else {
                balanceCondition.text = "이만큼 더 쓸 수 있어요."
            }
            towidget()
        }, completion: { [self] _ in collectionView.reloadData()})
    }
    
    // 위젯으로 데이터 전송
    func towidget() {
        if let wdata = UserDefaults.init(suiteName: "group.costit") {
            let stringData: [String] = [id.nickName + ",", (id.outLay - updateThisMonthTotalCost()).toDecimal() + "원", id.outLay > updateThisMonthTotalCost() ? "더 쓸 수 있어요" : "망했어요", Double(id.outLay) != 0 ? String(Int(Double(id.outLay - updateThisMonthTotalCost()) / Double(id.outLay) * 100)) : "0"]
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
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fincell", for: indexPath) as? finCell else {
            return UICollectionViewCell()
        }
        
        cell.updateUI(filteredList, indexPath.section, indexPath.row)
        cell.dismiss.tag = indexPath.section * 1000 + indexPath.row
        cell.dismiss.addTarget(self, action: #selector(cancelButtonAction(sender:)), for: .touchUpInside)
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
    
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        let y: CGFloat = scrollView.contentOffset.y
//
//                //변경될 최상단 뷰의 높이
//                let ModifiedTopHeight: CGFloat = viewTopHeight.constant - y
//
//                // *** 변경될 높이가 최댓값을 초과함
//                if(ModifiedTopHeight >= MaxTopHeight)
//                {
//                    //현재 최상단뷰의 높이를 최댓값(250)으로 설정
//                    viewTopHeight.constant = MaxTopHeight
//                    nickName.alpha = 1
//                    balanceCondition.alpha = 1
//                    balance.alpha = 1
//                }// *** 변경될 높이가 최솟값 미만임
//                else if(ModifiedTopHeight < MinTopHeight)
//                {
//                    //현재 최상단뷰의 높이를 최솟값(50+상태바높이)으로 설정
//                    viewTopHeight.constant = MinTopHeight
//                }// *** 변경될 높이가 최솟값(50+상태바높이)과 최댓값(250) 사이임
//                else
//                {
//                    //현재 최상단 뷰 높이를 변경함
//                    viewTopHeight.constant = ModifiedTopHeight
//                    scrollView.contentOffset.y = 0
//
//                    // 알파값 변경
//                    let alpha = { [self] in
//                        return (ModifiedTopHeight - MinTopHeight) / MaxTopHeight
//                    }
//                    nickName.alpha = alpha()
//                    balanceCondition.alpha = alpha()
//                    balance.alpha = alpha()
//                }
//
//    }
    
}

// 컬렉션 뷰 크기, 위치
extension mainVC: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = (view.bounds.width - 50) * 0.5
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
        how.text = "- " + model[section][row].how.toDecimal() + " 원"
    }
}

// 컬렉션 헤더 뷰 클래스
class header: UICollectionReusableView {
    @IBOutlet weak var headerDate: UILabel!
    
    func updateHeader(_ arr: [[finData]], _ index: Int) {
        
        if arr[index].isEmpty {
            headerDate.text = "정말?"
        } else {
            headerDate.text = arr[index][0].when.onlydate() + "일"
        }
    }
}
