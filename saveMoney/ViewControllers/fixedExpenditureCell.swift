import UIKit

class fixedExpenditureCell: UITableViewCell {
    
    @IBOutlet weak var towhat: UILabel!
    @IBOutlet weak var how: UILabel!
    //    @IBOutlet weak var addBtn: UIButton!
    @IBOutlet weak var trashBtn: UIButton!
    @IBOutlet weak var tableCellBorder: UIStackView!
    
    func layout(_ data: [[FixedExpenditure]], _ section: Int, _ row: Int) {
        self.how.text = data[section][row].how.toDecimal() + " 원"
        self.towhat.text = data[section][row].towhat
    }
    
    func tableCellBorderLayout() {
        let border = UIView()
        border.backgroundColor = .systemGray6
        border.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        border.frame = CGRect(x: 0, y: tableCellBorder.frame.height - 1.5, width: tableCellBorder.frame.width, height: 1.5)
        tableCellBorder.addSubview(border)
    }
}
