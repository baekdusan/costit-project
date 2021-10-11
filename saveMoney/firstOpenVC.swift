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
    let salaryList: [String] = ["1일", "5일", "10일", "15일", "20일", "25일", "마지막날"]
    var purposeMoney: Int!
    var salaryDay: String!
    var profileData = profile()
    
    @IBOutlet weak var nicknameTF: UITextField!
    @IBOutlet weak var purposeTF: UITextField!
    @IBOutlet weak var salaryTF: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = ""
        self.navigationController?.navigationBar.tintColor = UIColor(named: "HeaderColor")
        
        datepick.delegate = self
        datepick.dataSource = self
        
        purposeTF.keyboardType = .numberPad
        
        
        salaryTF.inputView = datepick
        
        createToolbarBtn(purposeTF)
        createToolbarBtn(salaryTF)
        createToolbarBtn(nicknameTF)
        if profileData.nickName != "User" {
            nicknameTF.text = profileData.nickName
            purposeTF.text = profileData.outLay.toDecimal()
            salaryTF.text = "매월 " + profileData.period
            
        } else {
            nicknameTF.becomeFirstResponder()
        }
    }
    
    func createToolbarBtn(_ TF: UITextField) {
        //toolbar 만들기, done 버튼이 들어갈 곳
        let toolbar = UIToolbar()
        toolbar.barTintColor = UIColor(named: "HeaderColor")
        toolbar.sizeToFit() //view 스크린에 딱 맞게 사이즈 조정
        
        //버튼 만들기
        let leftSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "완료", style: .done, target: nil, action: #selector(donePressed))
        doneButton.tintColor = UIColor(named: "customLabel")
        let nextButton = UIBarButtonItem(title: "다음", style: .plain, target: nil, action: #selector(nextPressed))
        nextButton.tintColor = UIColor(named: "customLabel")
        let nextButton2 = UIBarButtonItem(title: "다음", style: .plain, target: nil, action: #selector(nextPressed2))
        nextButton2.tintColor = UIColor(named: "customLabel")
        
        //버튼 툴바에 할당
//        TF == purposeTF ? toolbar.setItems([leftSpace, nextButton], animated: true) : toolbar.setItems([leftSpace, doneButton], animated: true)
        
        switch TF {
        case purposeTF:
            toolbar.setItems([leftSpace, nextButton], animated: true)
        case salaryTF:
            toolbar.setItems([leftSpace, doneButton], animated: true)
        case nicknameTF:
            toolbar.setItems([leftSpace, nextButton2], animated: true)
        default:
            toolbar.setItems([leftSpace, nextButton2], animated: true)
        }
        
        //toolbar를 키보드 대신 할당?
        TF.inputAccessoryView = toolbar
    }
    
    @objc func nextPressed(_ textField: UITextField) {
        salaryTF.becomeFirstResponder()
    }
    
    @objc func nextPressed2(_ textField: UITextField) {
        self.purposeTF.becomeFirstResponder()
    }
    
    @objc func donePressed(_ textField: UITextField) {
        if nicknameTF.text != nil && purposeTF.text != nil && salaryTF.text != nil {
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
