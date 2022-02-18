import UIKit
import UserNotifications

protocol FixedFinDataDelegate: AnyObject {
    func fixedFinData(_ controller: fixedExpenditureVC, _ fixedData: [FixedExpenditure])
}

class fixedExpenditureVC: UIViewController {
    
    @IBOutlet weak var navigation: UINavigationBar!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    @IBOutlet weak var TFSTackView: UIStackView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var whenTF: UITextField!
    @IBOutlet weak var toWhatTF: UITextField!
    @IBOutlet weak var howTF: UITextField!
    
    let notificationCenter = UNUserNotificationCenter.current()
    
    var name: String = "User"
    
    var fixedData: [FixedExpenditure] = [] {
        didSet {
            if let delegate = fixedDelegate {
                delegate.fixedFinData(self, fixedData)
                
            }
            if !fixedData.isEmpty {
                for i in fixedData {
                    notificationCenter.removePendingNotificationRequests(withIdentifiers: [i.id])
                    notificationCenter.addNotificationRequest(to: name, by: i)
                }
            }
            
            self.navigationBarTitle.text = totalCost()
        }
    }
    let navigationBarTitle = UILabel()
    let border = UIView()
    
    var filteredFixedData: [[FixedExpenditure]] = []
    var pickerview = UIPickerView()
    
    let days = [Int](1...31)
    
    var when: Int = 1
    var towhat: String?
    var how: Int?
    
    var fixedDelegate: FixedFinDataDelegate?
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        border.backgroundColor = UIColor(named: "fixedColor")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        requestNotificationAuthorization()
        
        tableView.separatorStyle = .none
        
        self.navigation.setBackgroundImage(UIImage(), for: .default)
        self.navigation.shadowImage = UIImage()
        
        navigationBarTitle.text = totalCost()
        navigationBarTitle.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
//        title.textColor = UIColor(named: "customLabel")
        
        navigation.topItem?.titleView = navigationBarTitle
        
        
        border.backgroundColor = UIColor(named: "fixedColor")
        border.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        border.frame = CGRect(x: 0, y: TFSTackView.frame.height - 1.5, width: TFSTackView.frame.width, height: 1.5)
        TFSTackView.addSubview(border)
        
        addInputAccessoryForTextFields(textFields: [whenTF, toWhatTF, howTF], dismissable: true, previousNextable: true)
        
        addBtnAlpha()
        
        [whenTF, toWhatTF, howTF].forEach {
            $0?.addTarget(self, action: #selector(addBtnAlpha), for: .editingChanged)
        }
        
        
        filteredbyDays()
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        pickerview.dataSource = self
        pickerview.delegate = self
        whenTF.inputView = pickerview
        howTF.keyboardType = .numberPad
        
        if !fixedData.isEmpty {
            for i in fixedData {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [i.id])
                notificationCenter.addNotificationRequest(to: name, by: i)
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        self.view.endEditing(true)
    }
    
    

    
    @IBAction func addFixedDataBtn(_ sender: UIBarButtonItem) {
        addFixedData()
    }
    

    
    @IBAction func dismissBtn(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    

}

extension fixedExpenditureVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return String(filteredFixedData[section][0].day) + "일"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredFixedData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFixedData[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "fixedExpenditureCell") as? fixedExpenditureCell else { return UITableViewCell() }
        cell.layout(filteredFixedData, indexPath.section, indexPath.row)
        cell.tableCellBorderLayout()
        
//        cell.addBtn.tag = indexPath.section * 1000 + indexPath.row
        cell.trashBtn.tag = indexPath.section * 1000 + indexPath.row
        
        cell.trashBtn.addTarget(self, action: #selector(trashBtnTapped(sender:)), for: .touchUpInside)
//        cell.addBtn.addTarget(self, action: #selector(addBtnTapped(sender:)), for: .touchUpInside)
        return cell
    }

}

extension fixedExpenditureVC: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        days.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(days[row])일"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        when = days[row]
        whenTF.text = "\(days[row])일"
    }
    
}

extension fixedExpenditureVC: UITextFieldDelegate {
    
    
    // 금액 최대 글자수는 15로 제한, 메모는 30자
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let newLength = (textField.text?.count)! + string.count - range.length
        
        if textField == howTF {
            return !(newLength > 11)
        } else {
            return !(newLength > 15)
        }
            
    }
    
    // 지출 키보드에서 실시간으로 반점 찍어주기
    func textFieldDidChangeSelection(_ textField: UITextField) {
        
        if textField == howTF {
            let money = textField.text!
            if money == "" {
            } else {
                textField.text = numberFormatter(number: Int(money.split(separator: ",").joined())!)
                how = textField.text!.toInt()
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == toWhatTF {
            howTF.becomeFirstResponder()
        }
        
        return true
    }
    
    // 반점 찍어주는 메서드
    func numberFormatter(number: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: number))!
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == whenTF {
            pickerview.selectRow(0, inComponent: 0, animated: true)
            when = 1
            whenTF.text = "1일"
        }
    }
}

extension fixedExpenditureVC {
    
    @objc func addBtnAlpha() {
        isAllfilled() ? (addBtn.isEnabled = true) : (addBtn.isEnabled = false)
    }
    
    func isAllfilled() -> Bool {
        
        return !whenTF.text!.isEmpty && !toWhatTF.text!.isEmpty && !howTF.text!.isEmpty
        
    }
    
    func filteredbyDays() {
        
        var day: Set<Int> = []
        
        for i in fixedData {
            day.insert(i.day)
        }
        
        filteredFixedData.removeAll()
        
        for j in day {
            var list: [FixedExpenditure] = []
            list = fixedData.filter { $0.day == j }
            filteredFixedData.append(list)
        }
        
        filteredFixedData.sort { $0[0].day < $1[0].day }
    }
    
    @objc func trashBtnTapped(sender: UIButton) {
        let section = sender.tag / 1000
        let row = sender.tag % 1000
        
        tableView.performBatchUpdates({
            
            tableView.deleteRows(at: [IndexPath.init(row: row, section: section)], with: .fade)
            let removedData = filteredFixedData[section].remove(at: row)

            if filteredFixedData[section].isEmpty {
                tableView.deleteSections([section], with: .fade)
                filteredFixedData.remove(at: section)
            }
            
            fixedData.remove(at: fixedData.firstIndex(where: {$0 == removedData})!)
        }, completion: {[self] _ in
            tableView.reloadData()})
    }
    
//    @objc func addBtnTapped(sender: UIButton) {
//        print(sender)
//    }
    

    
    @objc func addFixedData() {
        if isAllfilled() {
            let data = FixedExpenditure(day: when, towhat: toWhatTF.text, how: how)
            fixedData.append(data)
            filteredbyDays()
            tableView.reloadData()
            
            [howTF,whenTF,toWhatTF].forEach {
                $0?.text?.removeAll()
            }
            addBtnAlpha()
            howTF.resignFirstResponder()
        } else {
            print("error")
        }
    }
    
    func addInputAccessoryForTextFields(textFields: [UITextField], dismissable: Bool = true, previousNextable: Bool = false) {
        
            for (index, textField) in textFields.enumerated() {
                let toolbar: UIToolbar = UIToolbar()
                toolbar.sizeToFit()
                toolbar.barTintColor = UIColor(named: "fixedColor")

                var items = [UIBarButtonItem]()
                
                let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                
                
                if previousNextable {
                    
                    let previousButton = UIBarButtonItem(title: "이전", style: .plain, target: nil, action: nil)
                    previousButton.width = 30
                    previousButton.tintColor = .white
                    
                    if textField == textFields.first {
                        previousButton.isEnabled = false
                    } else {
                        previousButton.target = textFields[index - 1]
                        previousButton.action = #selector(UITextField.becomeFirstResponder)
                    }

                    let nextButton = UIBarButtonItem(title: "다음", style: .plain, target: nil, action: nil)
                    nextButton.width = 30
                    nextButton.tintColor = .white
                    
                    if textField == textFields.last {
                        nextButton.isEnabled = false
                    } else {
                        nextButton.target = textFields[index + 1]
                        nextButton.action = #selector(UITextField.becomeFirstResponder)
                    }
                    items.append(contentsOf: [previousButton, spacer, nextButton])
                }
                
                toolbar.setItems(items, animated: false)
                textField.inputAccessoryView = toolbar
            }
        }
    
    func requestNotificationAuthorization() {
        let authOptions: UNAuthorizationOptions = [.alert, .sound, .badge]

        notificationCenter.requestAuthorization(options: authOptions) { success, error in
            if let error = error {
                print(error)
            }
        }
    }
    
    func totalCost() -> String {
        var total = 0
        if !fixedData.isEmpty {
            for i in fixedData {
                total += i.how
            }
        }
        return "📌 \(total.toDecimal())원"
    }
}
