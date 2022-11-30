import UIKit

protocol FODelegate {
    func initialData(_ controller: firstOpenVC, _ nickName: String, _ pm: Int, _ salary: String)
}

class firstOpenVC: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return salaryList.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return salaryList[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        salaryDay = salaryList[row]
        salaryTF.text = "매월 " + salaryList[row]
    }

    var FODelegate: FODelegate?
    let datepick = UIPickerView()
    let salaryList: [String] = [Int](1...30).map { String($0) + "일" } + ["마지막 날"]
//    ["1일", "5일", "10일", "15일", "20일", "25일", "마지막 날"]
    var purposeMoney: Int!
    var salaryDay: String!
    var profileData = profile()
    var isFirstOpen: Bool = true
    
    @IBOutlet weak var confirmbtn: UIBarButtonItem!
    @IBOutlet weak var nicknameTF: UITextField!
    @IBOutlet weak var purposeTF: UITextField!
    @IBOutlet weak var salaryTF: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = ""
        self.navigationController?.navigationBar.tintColor = UIColor(named: "customLabel")
        
        datepick.delegate = self
        datepick.dataSource = self
        salaryTF.inputView = datepick
        
        purposeTF.keyboardType = .numberPad
        
        //버튼 만들기
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let toPurposeButton = UIBarButtonItem(title: "다음", style: .plain, target: nil, action: #selector(nicknamePressed(_:)))
        toPurposeButton.tintColor = UIColor(named: "customLabel")
        
        let toSalaryButton = UIBarButtonItem(title: "다음", style: .plain, target: nil, action: #selector(purposePressed(_:)))
        toSalaryButton.tintColor = UIColor(named: "customLabel")
        
        let doneButton = UIBarButtonItem(title: "완료", style: .done, target: nil, action: #selector(donePressed))
        doneButton.tintColor = UIColor(named: "customLabel")
        
        createToolbarBtn(nicknameTF, [space, toPurposeButton])
        createToolbarBtn(purposeTF, [space, toSalaryButton])
        createToolbarBtn(salaryTF, [space, doneButton])
        
        salaryTF.text = "매월 " + profileData.period
        if isFirstOpen {
            nicknameTF.text = profileData.nickName
            purposeTF.text = profileData.outLay.toDecimal()
        } else {
            nicknameTF.becomeFirstResponder()
        }
        
        confirmbtnAlpha()
        
        nicknameTF.addTarget(self, action: #selector(confirmbtnAlpha), for: .editingChanged)
        purposeTF.addTarget(self, action: #selector(confirmbtnAlpha), for: .editingChanged)
        salaryTF.addTarget(self, action: #selector(confirmbtnAlpha), for: .editingChanged)
    }
    
    @IBAction func confirm(_ sender: UIBarButtonItem) {
        if isAllfilled() {
            if let delegate = FODelegate {
                delegate.initialData(self, nicknameTF.text!, profileData.outLay, salaryDay ?? profileData.period)
                _ = navigationController?.popViewController(animated: true)
            }
        }
    }
    
    @objc func confirmbtnAlpha() {
        if isAllfilled() {
            confirmbtn.isEnabled = true
        } else {
            confirmbtn.isEnabled = false
        }
    }
    
    func isAllfilled() -> Bool {
        return !nicknameTF.text!.isEmpty && !purposeTF.text!.isEmpty && !salaryTF.text!.isEmpty
    }
    
    func createToolbarBtn(_ TF: UITextField, _ composition: [UIBarButtonItem]) {
        //toolbar 만들기, done 버튼이 들어갈 곳
        let toolbar = UIToolbar()
        toolbar.barTintColor = UIColor(named: "HeaderColor")
        toolbar.sizeToFit() //view 스크린에 딱 맞게 사이즈 조정
        toolbar.setItems(composition, animated: true)
        
        TF.inputAccessoryView = toolbar
    }
    
    @objc func nicknamePressed(_ textField: UITextField) {
        self.purposeTF.becomeFirstResponder()
    }
    
    @objc func purposePressed(_ textField: UITextField) {
        self.salaryTF.becomeFirstResponder()
    }
    
    @objc func donePressed(_ textField: UITextField) {
        if isAllfilled() {
            if let delegate = FODelegate {
                delegate.initialData(self, nicknameTF.text!, profileData.outLay, salaryDay ?? "1일")
                _ = navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func numberFormatter(number: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        return numberFormatter.string(from: NSNumber(value: number))!
    }
}

extension firstOpenVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.purposeTF.becomeFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newLength = (textField.text?.count)! + string.count - range.length
            return !(newLength > 15)
        }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        if textField == purposeTF {
            let money = textField.text!
            if money == "" {
            } else {
                textField.text = numberFormatter(number: Int(money.split(separator: ",").joined())!)
                profileData.outLay = (textField.text)!.toInt()
            }
        }
    }
    
}
