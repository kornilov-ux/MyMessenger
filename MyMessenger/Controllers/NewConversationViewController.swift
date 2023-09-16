//
//  NewConversationViewController.swift
//  MyMessenger
//
//  Created by Alex  on 14.09.2023.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
	
	private let spinner = JGProgressHUD(style: .dark)
	
	private var users = [[String: String]]()	
	private var results = [[String: String]]()
	
	private var hasFetched = false
	public var completion: (([String: String]) -> (Void))?
	
	private let searchBar: UISearchBar = {
		let searchBar = UISearchBar()
		searchBar.placeholder = "Search for Users..."
		return searchBar
	}()
	
	private let tableView: UITableView = {
		let table = UITableView()
		table.isHidden = true
		table.register(UITableViewCell.self,
					   forCellReuseIdentifier: "cell")
		return table
	}()
	
	private let noResultsLabel: UILabel = {
		let label = UILabel()
		label.isHidden = true
		label.text = "No Results"
		label.textAlignment = .center
		label.textColor = .green
		label.font = .systemFont(ofSize: 21, weight: .medium)
		return label
	}()

    override func viewDidLoad() {
        super.viewDidLoad()
		
		view.addSubview(noResultsLabel)
		view.addSubview(tableView)
		tableView.delegate = self
		tableView.dataSource = self
		
		searchBar.delegate = self
		view.backgroundColor = .white
		navigationController?.navigationBar.topItem?.titleView = searchBar
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
															style: .done,
															target: self,
															action: #selector(dismissSelf))
		searchBar.becomeFirstResponder()
    }
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		tableView.frame = view.bounds
		noResultsLabel.frame = CGRect(x: view.width/4,
									  y: (view.height-200)/2,
									  width: view.width/2,
									  height: 200)
	}
	
	@objc private func dismissSelf() {
		dismiss(animated: true, completion: nil)
	}
    

}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return results.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
		cell.textLabel?.text = results[indexPath.row]["name"]
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		// start conversation
		let targetUserData = results[indexPath.row]

		dismiss(animated: true, completion: { [weak self] in
			self?.completion?(targetUserData)
		})
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 90
	}
	
	
	
}


extension NewConversationViewController: UISearchBarDelegate {
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
			return
		}

		searchBar.resignFirstResponder()

		results.removeAll()
		spinner.show(in: view)

		searchUsers(query: text)
	}
	
	func searchUsers(query: String) {
		// check if array has firebase results
		if hasFetched {
			// if it does: filter
			filterUsers(with: query)
		}
		else {
			DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
				switch result {
				case .success(let usersCollection):
					self?.hasFetched = true
					self?.users = usersCollection
					self?.filterUsers(with: query)
				case .failure(let error):
					print("Failed to get usres: \(error)")
				}
			})
		}
	}
	
	func filterUsers(with term: String) {
		// update the UI: eitehr show results or show no results label
		guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, hasFetched else {
			return
		}

		let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)

		self.spinner.dismiss()

		let results: [[String:String]] = self.users.filter({  
			guard let email = $0["email"], email != safeEmail else {
				return false
			}

			guard let name = $0["name"]?.lowercased() else {
				return false
			}

			return name.hasPrefix(term.lowercased())
		})

		self.results = results

		updateUI()
	}

	func updateUI() {
		if results.isEmpty {
			noResultsLabel.isHidden = false
			tableView.isHidden = true
		}
		else {
			noResultsLabel.isHidden = true
			tableView.isHidden = false
			tableView.reloadData()
		}
	}
	
	
}
