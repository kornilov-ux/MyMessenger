//
//  ConversationViewController.swift
//  MyMessenger
//
//  Created by Alex  on 14.09.2023.
//

import UIKit
import FirebaseAuth

class ConversationViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		
		
		
	}
	
	override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
		
		 validateAuth()
			
		}

		private func validateAuth() {
			if  FirebaseAuth.Auth.auth().currentUser == nil {
				let vc = LoginViewController()
				let nav = UINavigationController(rootViewController: vc)
				nav.modalPresentationStyle = .fullScreen
				present(nav, animated: false)
			}
		}


}
