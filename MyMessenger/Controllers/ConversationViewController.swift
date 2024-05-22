//
//  ConversationViewController.swift
//  MyMessenger
//
//  Created by Alex  on 14.09.2023.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation {
	let id: String
	let name: String
	let otherUserEmail: String
	let latestMessage: LatestMessage
}

struct LatestMessage {
	let date: String
	let text: String
	let isRead: Bool
}

class ConversationViewController: UIViewController {
	
	private let spinner = JGProgressHUD(style: .dark)
	
	private var conversations = [Conversation]()

	private let tableView: UITableView = {
		let table = UITableView()
		table.isHidden = true
		table.register(ConversationTableViewCell.self,
							   forCellReuseIdentifier: ConversationTableViewCell.identifier)
		return table
	}()
	
	private let noConversationsLabel: UILabel = {
		let label = UILabel()
		label.text = "No Conversations!"
		label.textAlignment = .center
		label.textColor = .gray
		label.font = .systemFont(ofSize: 21, weight: .medium)
		label.isHidden = true
		return label
	}()
	
	private var loginObserver: NSObjectProtocol?
	
	override func viewDidLoad() {
		super.viewDidLoad()	
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
															target: self,
															action: #selector(didTapComposeButton))
		view.addSubview(tableView)
		view.addSubview(noConversationsLabel)
		setupTableView()
		startListeningForCOnversations()
		
//		loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: { [weak self] _ in
//			guard let strongSelf = self else {
//				return
//			}
//			
//			strongSelf.startListeningForCOnversations()
//		})		
	}
	
	private func startListeningForCOnversations() {
		guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
			return
		}
		
		if let observer = loginObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		
		print("starting conversation fetch...")
		let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
		
		DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in 
			switch result {
			case .success(let conversations):
				print("successfully got conversation models")
				guard !conversations.isEmpty else {
					self?.tableView.isHidden = true
					self?.noConversationsLabel.isHidden = false
					return
				}
				self?.noConversationsLabel.isHidden = true
				self?.tableView.isHidden = false
				self?.conversations = conversations
				
				DispatchQueue.main.async {
					self?.tableView.reloadData()
				}
			case .failure(let error):
				self?.tableView.isHidden = true
				self?.noConversationsLabel.isHidden = false
				print("failed to get convos: \(error)")
			}
		})
	}
	
	@objc private func didTapComposeButton() {
		let vc = NewConversationViewController()		
		vc.completion = { [weak self] result in 
			guard let strongSelf = self else {
				return
			}
			
			let currentConversations = strongSelf.conversations
			
			if let targetConversation = currentConversations.first(where: {
				$0.otherUserEmail == DatabaseManager.safeEmail(emailAddress: result.email)
			}) {
				let vc = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
				vc.isNewConversation = false
				vc.title = targetConversation.name
				vc.navigationItem.largeTitleDisplayMode = .never
				strongSelf.navigationController?.pushViewController(vc, animated: true)
			}
			else {
				strongSelf.createNewConversation(result: result)
			}
		}
		
		let navVC = UINavigationController(rootViewController: vc)
		present(navVC, animated: true)
	}
	
	private func createNewConversation(result: SearchResult) {
		let name = result.name
		let email = DatabaseManager.safeEmail(emailAddress: result.email)
		
		DatabaseManager.shared.conversationExists(iwth: email, completion: { [weak self] result in
			guard let strongSelf = self else {
				return
			}
			switch result {
			case .success(let conversationId):
				let vc = ChatViewController(with: email, id: conversationId)
				vc.isNewConversation = false
				vc.title = name
				vc.navigationItem.largeTitleDisplayMode = .never
				strongSelf.navigationController?.pushViewController(vc, animated: true)
			case .failure(_):
				let vc = ChatViewController(with: email, id: nil)
				vc.isNewConversation = true
				vc.title = name
				vc.navigationItem.largeTitleDisplayMode = .never
				strongSelf.navigationController?.pushViewController(vc, animated: true)
			}
		})
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		tableView.frame = view.bounds
		noConversationsLabel.frame = CGRect(x: 10,
											y: (view.height-100)/2,
											width: view.width-20,
											height: 100)
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
	
	private func setupTableView() {
		tableView.delegate = self
		tableView.dataSource = self
	}
}


extension ConversationViewController: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return conversations.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let model = conversations[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier,
												 for: indexPath) as! ConversationTableViewCell
		cell.configure(with: model)
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let model = conversations[indexPath.row]
		openConversation(model)
	}
	
	func openConversation(_ model: Conversation) {
		let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
		vc.title = model.name
		vc.navigationItem.largeTitleDisplayMode = .never
		navigationController?.pushViewController(vc, animated: true)
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 120
	}
	
	func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		return .delete
	}
	
}
