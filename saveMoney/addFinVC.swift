import UIKit

protocol sendFinData {
    func sendFinanceSource(_ controller: addFinVC, _ originData: finData, _ revisedData: finData)
}

class addFinVC: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var whenTextField: UITextField!
    @IBOutlet weak var towhatTextField: UITextField!
    @IBOutlet weak var howTextField: UITextField!
    @IBOutlet weak var memoPaper: UIImageView!
    
    var delegate: sendFinData! // 메인으로 보내는 대리자
    var datepick = UIDatePicker() // 데이트 피커
    var when: Date! // 가계부 데이터에 넣을 시간(화면 표시와 달라서 따로 저장 후 추가나 변경 시에 사용)
    var outlay: Int! // 지출액
    var start: Date!
    var end: Date!
    let formatter = DateFormatter()
    
    var originData: finData! // 수정할 때 잠시 담아두는 데이터
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 날짜 텍스트 필드 노출 스타일 설정
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
        
        // 데이트 피커뷰 만들어주고, 두번째 뷰를 firstResponder 설정
        createDatePickerView()
        towhatTextField.becomeFirstResponder()
        
        // 날짜 갱신해주는 타이머
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(valuechange), userInfo: nil, repeats: true)
        
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
        // 날짜 변경이 이루어질 때만 데이트 피커 바탕으로 갱신
        if whenTextField.isEditing {
            whenTextField.text = formatter.string(from: datepick.date)
        }
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
    
    // 날짜 키보드에서 다음을 눌렀을 때
    @objc func nextPressed() {
        when = datepick.date
        towhatTextField.becomeFirstResponder()
    }
    
    // towhat 키보드에서 다음을 눌렀을 때
    @objc func nextPressed2() {
        howTextField.becomeFirstResponder()
    }
    
    // 지출 키보드에서 다음을 눌렀을 때
    @objc func donePressed() {
        if !whenTextField.text!.isEmpty && !towhatTextField.text!.isEmpty && !howTextField.text!.isEmpty {
            let writenData = finData(when: when, towhat: towhatTextField.text, how: outlay)
            // 수정하기로 열었을 때
            if let originData = originData {
                // 데이터를 수정 안하고 붙인다면 그냥 뷰를 닫기
                if originData != writenData {
                    if let delegate = delegate {
                        delegate.sendFinanceSource(self, originData, writenData)
                    }
                } else {
                }
            // 그냥 열었을 때
            } else {
                if let delegate = delegate {
                    delegate.sendFinanceSource(self, writenData, writenData)
                }
            }
            dismiss(animated: true, completion: nil)
        } else {
            print("empty")
        }
    }
    
    // towhat 키보드에서 다음을 눌렀을 때
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        howTextField.becomeFirstResponder()
    }
    
    // 최대 글자수는 15로 제한
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newLength = (textField.text?.count)! + string.count - range.length
            return !(newLength > 15)
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
