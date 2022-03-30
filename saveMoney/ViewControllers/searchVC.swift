
import UIKit

class searchVC: UIViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    var efinList: [finData] = []
    var rfinList: [finData] = []
    
    var eFiltered: [finData] = []
    var rFiltered: [finData] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.searchBar.becomeFirstResponder()
    }
    
    @IBAction func popBtn(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
}

extension searchVC: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard let text = searchBar.text?.lowercased() else { return }
        self.rFiltered = self.rfinList.filter { $0.towhat.lowercased().contains(text) }.sorted(by: {$0.when > $1.when })
        self.eFiltered = self.efinList.filter { $0.towhat.lowercased().contains(text) }.sorted(by: {$0.when > $1.when })
        
        self.tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
}


extension searchVC: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return eFiltered.count
        case 1:
            return rFiltered.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "searchCell", for: indexPath) as? searchCell else { return UITableViewCell() }
        
        cell.tableCellBorderLayout()
        
        switch indexPath.section {
        case 0:
            cell.set(eFiltered, indexPath.row)
        case 1:
            cell.set(rFiltered, indexPath.row)
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if rFiltered.count + eFiltered.count == 0 {
            return nil
        }
        
        switch section {
        case 0:
            return "💸 지출"
        case 1:
            return "💰 수입"
        default:
            return nil
        }
    }
}

extension searchVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let myLabel = UILabel()
        myLabel.frame = CGRect(x: 18, y: 0, width: tableView.frame.width - 36, height: 30)
        myLabel.font = UIFont.boldSystemFont(ofSize: 12)
        myLabel.alpha = 0.72
        myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)

        let headerView = UIView()
        headerView.addSubview(myLabel)

        return headerView
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.searchBar.resignFirstResponder()
    }
}


class searchCell: UITableViewCell {
    
    @IBOutlet weak var tableCellBorder: UIStackView!
    @IBOutlet weak var when: UILabel!
    @IBOutlet weak var towhat: UILabel!
    @IBOutlet weak var how: UILabel!

    func set(_ list: [finData], _ row: Int) {
        when.text = list[row].when.toFullString()
        towhat.text = list[row].towhat
        how.text = list[row].how.toDecimal() + " 원"
    }
    
    func tableCellBorderLayout() {
        let border = UIView()
        border.backgroundColor = .systemGray6
        border.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        border.frame = CGRect(x: 0, y: tableCellBorder.frame.height - 1.5, width: tableCellBorder.frame.width, height: 1.5)
        tableCellBorder.addSubview(border)
    }
}
