//
//  ConversationViewController.swift
//  MyMessenger
//
//  Created by Alex  on 14.09.2023.
//

import UIKit

class ConversationViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .red
		
	}
	
	override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
		let isLoggedIn = UserDefaults.standard.bool(forKey: "logged_in")
		if  !isLoggedIn {
			let vc = LoginViewController()
			let nav = UINavigationController(rootViewController: vc)
			nav.modalPresentationStyle = .fullScreen
			present(nav, animated: false)
		}
			//validateAuth()
		}

//		private func validateAuth() {
//			let isLoggedIn = UserDefaults.standard.bool(forKey: "logged_in")
//			if  !isLoggedIn {
//				let vc = LoginViewController()
//				let nav = UINavigationController(rootViewController: vc)
//				nav.modalPresentationStyle = .fullScreen
//				present(nav, animated: false)
//			}
//		}


}
