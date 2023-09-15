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
	public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
		database.child(user.safeEmail).setValue([
			"first_name": user.firstName,
			"last_name": user.lastName
		], withCompletionBlock: { [weak self] error, _ in
			
			guard let strongSelf = self else {
				return
			}
			
			guard error == nil else {
				print("failed ot write to database")
				completion(false)
				return
			}
			
			strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
				if var usersCollection = snapshot.value as? [[String: String]] {
					// append to user dictionary
					let newElement = [
						"name": user.firstName + " " + user.lastName,
						"email": user.safeEmail
					]
					usersCollection.append(newElement)
					
					strongSelf.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
						guard error == nil else {
							completion(false)
							return
						}
						
						completion(true)
					})
				}
				else {
					// create that array
					let newCollection: [[String: String]] = [
						[
							"name": user.firstName + " " + user.lastName,
							"email": user.safeEmail
						]
					]
					
					strongSelf.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
						guard error == nil else {
							completion(false)
							return
						}
						
						completion(true)
					})
				}
			})
		})
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
	
	var profilePictureFileName: String {
		return "\(safeEmail)_profile_picture.png"
	}
	
}
