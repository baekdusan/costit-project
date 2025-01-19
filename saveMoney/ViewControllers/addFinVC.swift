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
    var outlay: Int? // 지출액
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
        
        // 가져온 날짜 표시(데이터를 수정할 때만)
        if let _ = originData {
            whenTextField.text = formatter.string(from: originData.when)
            when = originData.when
            
            // 일반적인 추가일 때에는 현재 시간대를 할당
        } else {
            whenTextField.text = formatter.string(from: Date())
            when = datepick.date
        }
        
        //assign datepicker to the textfield, 텍스트 필드에 datepicker 할당
        whenTextField.inputView = datepick
        
        //datePicker 형식 바꾸기
        datepick.datePickerMode = .date
        //        datepick.minimumDate = start
        //        datepick.maximumDate = end
        datepick.locale = Locale(identifier: "ko-KR")
        datepick.preferredDatePickerStyle = .wheels
        
        
        datepick.addTarget(self, action: #selector(valuechange), for: .valueChanged)
        
        // 메모장 이미지 그림자 넣기
        memoPaper.layer.shadowColor = UIColor.black.cgColor
        memoPaper.clipsToBounds = false
        memoPaper.layer.shadowOffset = CGSize(width: 0, height: 3)
        memoPaper.layer.shadowRadius = 5
        memoPaper.layer.shadowOpacity = 0.2
        
        addInputAccessoryForTextFields(textFields: [whenTextField, towhatTextField, howTextField], dismissable: true, previousNextable: true)
        whenTextField.becomeFirstResponder()
    }
    
    // 이 뷰가 노출될 때마다 메인에서 받아온 수정 데이터 셋팅
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        if let findata = originData {
            whenTextField.text = formatter.string(from: findata.when)
            towhatTextField.text = findata.towhat
            howTextField.text = findata.how.toDecimal()
            outlay = findata.how // 초기 값 설정
        }
    }
    
    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // 데이트 피커 키보드 내용을 감지하는 메서드
    @objc func valuechange() {
        if whenTextField.isEditing {
            whenTextField.text = formatter.string(from: datepick.date)
            when = datepick.date // datepick.date 값을 when에 반영
        }
    }
    
    // towhat 키보드에서 키보드 속 다음을 눌렀을 때
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        howTextField.becomeFirstResponder()
    }
    
    func addInputAccessoryForTextFields(textFields: [UITextField], dismissable: Bool = true, previousNextable: Bool = false) {
        for (index, textField) in textFields.enumerated() {
            let toolbar: UIToolbar = UIToolbar()
            toolbar.sizeToFit()
            toolbar.barTintColor = UIColor(named: fromWhere == .expense ? "topViewColor" : "pinColor")
            var items = [UIBarButtonItem]()
            if previousNextable {
                let previousButton = UIBarButtonItem(image: UIImage(systemName: "chevron.up"), style: .plain, target: nil, action: nil)
                previousButton.width = 30
                if textField == textFields.first {
                    previousButton.isEnabled = false
                } else {
                    previousButton.target = textFields[index - 1]
                    previousButton.action = #selector(UITextField.becomeFirstResponder)
                }
                
                let nextButton = UIBarButtonItem(image: UIImage(systemName: "chevron.down"), style: .plain, target: nil, action: nil)
                nextButton.width = 30
                if textField == textFields.last {
                    nextButton.isEnabled = false
                } else {
                    nextButton.target = textFields[index + 1]
                    nextButton.action = #selector(UITextField.becomeFirstResponder)
                }
                items.append(contentsOf: [previousButton, nextButton])
            }
            
            let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: #selector(donePressed))
            items.append(contentsOf: [spacer, doneButton])
            items.forEach {
                (fromWhere == .expense) ? ($0.tintColor = UIColor(named: "customLabel")) : ($0.tintColor = UIColor.black.withAlphaComponent(0.72))
            }
            
            toolbar.setItems(items, animated: false)
            textField.inputAccessoryView = toolbar
        }
    }
    
    // 지출 키보드에서 다음을 눌렀을 때
    @objc func donePressed() {
        guard
            let whenText = whenTextField.text, !whenText.isEmpty,
            let towhatText = towhatTextField.text, !towhatText.isEmpty,
            let howText = howTextField.text, !howText.isEmpty
        else {
            print("empty")
            return
        }
        
        // `outlay`가 nil이면 `howTextField.text`를 다시 파싱
        if outlay == nil {
            outlay = Int(howText.replacingOccurrences(of: ",", with: "")) ?? 0
        }
        
        let writenData = finData(when: when, towhat: towhatText, how: outlay ?? 0)
        
        if mode == .edit {
            guard let originData = originData else { return }
            if originData != writenData {
                if fromWhere == .expense {
                    delegate?.sendFinanceSource(self, originData, writenData)
                } else if fromWhere == .revenue {
                    rDelegate?.sendRevenueData(self, originData, writenData)
                }
            }
        } else if mode == .new {
            if fromWhere == .expense {
                delegate?.sendFinanceSource(self, writenData, writenData)
            } else if fromWhere == .revenue {
                rDelegate?.sendRevenueData(self, writenData, writenData)
            }
        }
        
        dismiss(animated: true, completion: nil)
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
    //    func textFieldDidChangeSelection(_ textField: UITextField) {
    //        if textField == howTextField {
    //            let money = textField.text!
    //            if money == "" {
    //            } else {
    //                textField.text = numberFormatter(number: Int(money.split(separator: ",").joined())!)
    //                outlay = textField.text!.toInt()
    //            }
    //        }
    //    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        if textField == howTextField, let moneyText = textField.text?.replacingOccurrences(of: ",", with: ""),
           let money = Int(moneyText) {
            textField.text = numberFormatter(number: money)
            outlay = money
        } else {
            outlay = nil
        }
    }
    
    
    // 반점 찍어주는 메서드
    func numberFormatter(number: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: number))!
    }
}
