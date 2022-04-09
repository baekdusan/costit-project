
import UIKit
import SwiftUI

class searchVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    // 지출, 소비 데이터
    var efinList: [finData] = []
    var rfinList: [finData] = []
    
    // 지출, 소비 데이터 필터링
    var eFiltered: [finData] = []
    var rFiltered: [finData] = []
    
    // 서치바
    var searchBar = UISearchBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        // 네비게이션 바 커스텀
        self.navigationController?.navigationBar.topItem?.title = ""
        self.navigationController?.navigationBar.tintColor = UIColor(named: "calendarBgColor")
        
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        self.navigationItem.titleView = searchBar
        
        searchBar.delegate = self
        searchBar.setImage(UIImage(), for: .search, state: .normal)
        searchBar.searchTextField.backgroundColor = .clear
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // 첫 화면 입장시 키보드 오픈
        searchBar.searchTextField.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        searchBar.placeholder = "품목을 입력해봐요 :)"
        searchBar.becomeFirstResponder()
    }
}

extension searchVC: UISearchBarDelegate {

    // 텍스트 입력할 때마다 필터링 & 테이블 뷰 갱신
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard let text = searchBar.text?.lowercased() else { return }
        self.rFiltered = self.rfinList.filter { $0.towhat.lowercased().contains(text) }.sorted(by: {$0.when > $1.when })
        self.eFiltered = self.efinList.filter { $0.towhat.lowercased().contains(text) }.sorted(by: {$0.when > $1.when })
        self.tableView.reloadData()
    }
    
    // 검색 버튼 눌렀을 때 키보드 내리기
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.endEditing(true)
    }
}

// 테이블 뷰 설정
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
