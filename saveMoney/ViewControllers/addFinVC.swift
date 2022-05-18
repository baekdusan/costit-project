import UIKit

protocol sendFinData {
    func sendFinanceSource(_ controller: addFinVC, _ originData: finData, _ revisedData: finData)
}

protocol sendRevenueFinData {
    func sendRevenueData(_ controller: addFinVC, _ originData: finData, _ revisedData: finData)
}

enum sourceView {
    case expense
    case revenue
}

enum mode {
    case new
    case edit
}

class addFinVC: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var whenTextField: UITextField!
    @IBOutlet weak var towhatTextField: UITextField!
    @IBOutlet weak var howTextField: UITextField!
    @IBOutlet weak var memoPaper: UIImageView!
    
    var delegate: sendFinData! // 지출화면으로 보내는 대리자
    var rDelegate: sendRevenueFinData! // 수입화면으로 보내는 대리자
    
    var datepick = UIDatePicker() // 데이트 피커
    var when: Date! // 가계부 데이터에 넣을 시간(화면 표시와 달라서 따로 저장 후 추가나 변경 시에 사용)
    var outlay: Int! // 지출액
    var start: Date!
    var end: Date!
    let formatter = DateFormatter()
    
    var fromWhere: sourceView?
    var mode: mode?
    
    var originData: finData! // 수정할 때 잠시 담아두는 데이터
    
    
    func swipeRecognizer() {
            let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(self.respondToSwipeGesture(_:)))
        swipeDown.direction = UISwipeGestureRecognizer.Direction.down
            self.view.addGestureRecognizer(swipeDown)
    }
        
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer){
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction{
            case UISwipeGestureRecognizer.Direction.down:
                // 스와이프 시, 원하는 기능 구현.
                self.dismiss(animated: true, completion: nil)
            default: break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 빈 화면에 스크롤 제스처 추가
        swipeRecognizer()
        
        // 날짜 텍스트 필드 노출 스타일 설정  ----- 변경금지 !! -----
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.dateFormat = "yyyy. MM. dd."
        
        // 가져온 날짜 표시(새로운 데이터를 추가할 때만)
        if let _ = originData {
            whenTextField.text = formatter.string(from: originData.when)
            when = originData.when
        
        // 일반적인 추가일 때에는 현재 시간대를 할당
        } else {
            whenTextField.text = formatter.string(from: Date())
            when = datepick.date
        }
        
        // 툴바 및 데이트 피커 설정
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let dateTotowhat = UIBarButtonItem(title: "다음", style: .done, target: nil, action: #selector(dateTotowhat))
        let towhatTohow = UIBarButtonItem(title: "다음", style: .done, target: nil, action: #selector(towhatTohow))
        let done = UIBarButtonItem(title: "붙이기", style: .done, target: nil, action: #selector(donePressed))
        
        [dateTotowhat, towhatTohow, done].forEach {
            (fromWhere == .expense) ? ($0.tintColor = UIColor(named: "customLabel")) : ($0.tintColor = UIColor.black.withAlphaComponent(0.72))
        }
        
        toolbarSetting(whenTextField, [space, dateTotowhat])
        toolbarSetting(towhatTextField, [space, towhatTohow])
        toolbarSetting(howTextField, [space, done])
        
        //assign datepicker to the textfield, 텍스트 필드에 datepicker 할당
        whenTextField.inputView = datepick

        //datePicker 형식 바꾸기
        datepick.datePickerMode = .date
        datepick.minimumDate = start
        datepick.maximumDate = end
        datepick.locale = Locale(identifier: "ko-KR")
        datepick.preferredDatePickerStyle = .wheels
        towhatTextField.becomeFirstResponder()
        
        datepick.addTarget(self, action: #selector(valuechange), for: .valueChanged)
        
        // 메모장 이미지 그림자 넣기
        memoPaper.layer.shadowColor = UIColor.black.cgColor
        memoPaper.clipsToBounds = false
        memoPaper.layer.shadowOffset = CGSize(width: 0, height: 3)
        memoPaper.layer.shadowRadius = 5
        memoPaper.layer.shadowOpacity = 0.2
    }
    
    // 이 뷰가 노출될 때마다 메인에서 받아온 수정 데이터 셋팅
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        if let findata = originData {
            whenTextField.text = formatter.string(from: findata.when)
            towhatTextField.text = findata.towhat
            howTextField.text = findata.how.toDecimal()
        }
    }
    
    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // 데이트 피커 키보드 내용을 감지하는 메서드
    @objc func valuechange() {
        if whenTextField.isEditing {
            whenTextField.text = formatter.string(from: datepick.date)
        }
    }
    
    func toolbarSetting(_ textfield: UITextField, _ composition: [UIBarButtonItem]) {
        //toolbar 만들기, done 버튼이 들어갈 곳
        let toolbar = UIToolbar()
        toolbar.barTintColor = UIColor(named: fromWhere == .expense ? "topViewColor" : "pinColor")
        toolbar.sizeToFit() //view 스크린에 딱 맞게 사이즈 조정
        toolbar.setItems(composition, animated: true)
        textfield.inputAccessoryView = toolbar
    }
    
    @objc func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    // 날짜 키보드에서 다음을 눌렀을 때
    @objc func dateTotowhat() {
        when = datepick.date
        towhatTextField.becomeFirstResponder()
    }
    
    // towhat 키보드에서 다음을 눌렀을 때
    @objc func towhatTohow() {
        howTextField.becomeFirstResponder()
    }
    
    // towhat 키보드에서 키보드 속 다음을 눌렀을 때
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        howTextField.becomeFirstResponder()
    }
    
    // 지출 키보드에서 다음을 눌렀을 때
    @objc func donePressed() {
        if !whenTextField.text!.isEmpty, !towhatTextField.text!.isEmpty, !howTextField.text!.isEmpty {
            let writenData = finData(when: when, towhat: towhatTextField.text, how: outlay)
            if mode == .edit {
                guard let originData = originData else { return }
                switch fromWhere {
                case .expense:
                    if originData != writenData {
                        if let delegate = delegate {
                            delegate.sendFinanceSource(self, originData, writenData)
                        }
                    } else {
                    }
                case .revenue:
                    if originData != writenData {
                        if let delegate = rDelegate {
                            delegate.sendRevenueData(self, originData, writenData)
                        }
                    } else {
                    }
                default:
                    break
                }
            } else if mode == .new {
                switch fromWhere {
                case .expense:
                    if let delegate = delegate {
                        delegate.sendFinanceSource(self, writenData, writenData)
                    }
                case .revenue:
                    if let delegate = rDelegate {
                        delegate.sendRevenueData(self, writenData, writenData)
                    }
                default:
                    break
                }
            }
            dismiss(animated: true, completion: nil)
        } else {
            print("empty")
        }
    }
    
    
    
    // 금액 최대 글자수는 15로 제한, 메모는 30자
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newLength = (textField.text?.count)! + string.count - range.length
        
        if textField == howTextField {
            return !(newLength > 15)
        } else {
            return !(newLength > 30)
        }
            
    }
    
    // 지출 키보드에서 실시간으로 반점 찍어주기
    func textFieldDidChangeSelection(_ textField: UITextField) {
        if textField == howTextField {
            let money = textField.text!
            if money == "" {
            } else {
                textField.text = numberFormatter(number: Int(money.split(separator: ",").joined())!)
                outlay = textField.text!.toInt()
            }
        }
    }
    
    // 반점 찍어주는 메서드
    func numberFormatter(number: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: number))!
    }
}
