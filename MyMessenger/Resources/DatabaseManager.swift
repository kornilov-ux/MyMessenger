//
//  DatabaseManager.swift
//  MyMessenger
//
//  Created by Alex  on 14.09.2023.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {

	/// Shared instance of class
	public static let shared = DatabaseManager()

	private let database = Database.database().reference()
	

	static func safeEmail(emailAddress: String) -> String {
		var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
		safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
		return safeEmail
	}
}



// MARK: - Account Managment

extension DatabaseManager {
	
	public func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
		
		let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
		database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
			guard snapshot.value as? [String: Any] != nil else {
				completion(false)
				return
			}
			completion(true)
		})
	}
	
	
	/// Inserts new user in database
	public func insertUser(with user: ChatAppUser) {
		database.child(user.safeEmail).setValue([
			"first_name": user.firstName,
			"last_name": user.lastName
		])
	}
}

struct ChatAppUser {
	let firstName: String
	let lastName: String
	let emailAddress: String
//	let profilePictureUrl: String
	
	var safeEmail: String {
		var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
		safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
		return safeEmail
	}
	
	
}
