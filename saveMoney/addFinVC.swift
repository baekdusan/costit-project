import UIKit

protocol sendFinData {
    func sendFinanceSource(_ controller: addFinVC, _ data: finData)
}

class addFinVC: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var whenTextField: UITextField!
    @IBOutlet weak var towhatTextField: UITextField!
    @IBOutlet weak var howTextField: UITextField!
    @IBOutlet weak var memoPaper: UIImageView!
    
    var delegate: sendFinData!
    var datepick = UIDatePicker()
    var when: Date!
    var outlay: Int! // 지출액
    var start: Date!
    var end: Date!
    let formatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 날짜 텍스트 필드 노출 스타일 설정
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.dateFormat = "yyyy. MM. dd."
        
        // 오늘 날짜 표시
        whenTextField.text = formatter.string(from: Date())
        
        // 데이트 피커뷰 만들어주고, 두번째 뷰를 firstResponder 설정
        createDatePickerView()
        towhatTextField.becomeFirstResponder()
        
        // 날짜 갱신해주는 타이머
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(valuechange), userInfo: nil, repeats: true)
        
        memoPaper.layer.shadowColor = UIColor.black.cgColor
        memoPaper.clipsToBounds = false
        memoPaper.layer.shadowOffset = CGSize(width: 0, height: 3)
        memoPaper.layer.shadowRadius = 5
        memoPaper.layer.shadowOpacity = 0.2
    }
    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func valuechange() {
        whenTextField.text = formatter.string(from: datepick.date)
        when = datepick.date
    }
    
    func createDatePickerView() {
        //toolbar 만들기, done 버튼이 들어갈 곳
        let timeToolbar = UIToolbar()
        timeToolbar.barTintColor = UIColor(named: "toolbar")
        timeToolbar.sizeToFit() //view 스크린에 딱 맞게 사이즈 조정
        
        let towhatToolbar = UIToolbar()
        towhatToolbar.barTintColor = UIColor(named: "toolbar")
        towhatToolbar.sizeToFit()
        
        let finishToolbar = UIToolbar()
        finishToolbar.barTintColor = UIColor(named: "toolbar")
        finishToolbar.sizeToFit()
        
        //버튼 만들기
        let leftSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let nextButton = UIBarButtonItem(title: "다음", style: .plain, target: nil, action: #selector(nextPressed))
        nextButton.tintColor = UIColor(named: "customLabel")
        let nextButton2 = UIBarButtonItem(title: "다음", style: .done, target: nil, action: #selector(nextPressed2))
        nextButton2.tintColor = UIColor(named: "customLabel")
        let doneButton = UIBarButtonItem(title: "붙이기", style: .done, target: nil, action: #selector(donePressed))
        doneButton.tintColor = UIColor(named: "customLabel")
        //action 자리에는 이후에 실행될 함수가 들어간다?
        
        //버튼 툴바에 할당
        timeToolbar.setItems([leftSpace, nextButton], animated: true)
        towhatToolbar.setItems([leftSpace, nextButton2], animated: true)
        finishToolbar.setItems([leftSpace, doneButton], animated: true)
        
        //toolbar를 키보드 대신 할당?
        whenTextField.inputAccessoryView = timeToolbar
        towhatTextField.inputAccessoryView = towhatToolbar
        howTextField.inputAccessoryView = finishToolbar
        
        //assign datepicker to the textfield, 텍스트 필드에 datepicker 할당
        whenTextField.inputView = datepick

        //datePicker 형식 바꾸기
        datepick.datePickerMode = .date
        datepick.minimumDate = start
        datepick.maximumDate = end
        datepick.locale = Locale(identifier: "ko-KR")
        datepick.preferredDatePickerStyle = .wheels
        
    }
    
    @objc func nextPressed() {
            
        whenTextField.text = formatter.string(from: datepick.date)
        when = datepick.date
        towhatTextField.becomeFirstResponder()
    }
    
    @objc func nextPressed2() {
        howTextField.becomeFirstResponder()
    }
    
    @objc func donePressed() {
        if !whenTextField.text!.isEmpty && !towhatTextField.text!.isEmpty && !howTextField.text!.isEmpty {
            if let delegate = delegate {
                delegate.sendFinanceSource(self, finData(when: when, towhat: towhatTextField.text, how: outlay))
            }
            dismiss(animated: true, completion: nil)
        } else {
            print("empty")
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        howTextField.becomeFirstResponder()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newLength = (textField.text?.count)! + string.count - range.length
            return !(newLength > 15)
        }
    
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
    
    func numberFormatter(number: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        return numberFormatter.string(from: NSNumber(value: number))!
    }
}
