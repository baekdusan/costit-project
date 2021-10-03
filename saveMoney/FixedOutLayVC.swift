//
//  FixedOutLayVC.swift
//  saveMoney
//
//  Created by 백두산 on 2021/10/03.
//

import UIKit

class FixedOutLayVC: UIViewController {

    @IBOutlet weak var dismissLayOut: UIButton!
    @IBOutlet weak var addBtnLayOut: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        dismissLayOut.btnLayout()
        addBtnLayOut.btnLayout()
        
    }
    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
