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
	
	public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
		database.child("users").observeSingleEvent(of: .value, with: { snapshot in
			guard let value = snapshot.value as? [[String: String]] else {
				completion(.failure(DatabaseError.failedToFetch))
				return
			}
			completion(.success(value))
		})
	}
	
	public enum DatabaseError: Error {
		case failedToFetch

		public var localizedDescription: String {
			switch self {
			case .failedToFetch:
				return "This means blah failed"
			}
		}
	}
	
	
	
}

//MARK: - seding messages / conversation

extension DatabaseManager {
	
	/// Creates a new conversation with target user emamil and first message sent
	public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
		guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String
			   else {
			return
		}
		// let currentNamme = UserDefaults.standard.value(forKey: "name") as? String
		
		let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
		let ref = database.child("\(safeEmail)")

		ref.observeSingleEvent(of: .value, with: { snapshot in 
			guard var userNode = snapshot.value as? [String: Any] else {
				completion(false)
				print("user not found")
				return
			}
			
			let messageDate = firstMessage.sentDate
			let dateString = ChatViewController.dateFormatter.string(from: messageDate)
			
			var message = ""
			
			switch firstMessage.kind {
			case .text(let messageText):
				message = messageText
			case .attributedText(_):
				break
			case .photo(_):
				break
			case .video(_):
				break
			case .location(_):
				break
			case .emoji(_):
				break
			case .audio(_):
				break
			case .contact(_):
				break
			case .linkPreview(_):
				break
			case .custom(_):
				break
			}
			
			let conversationId = "conversation_\(firstMessage.messageId)"
			
			let newConversationData: [String: Any] = [
				"id": conversationId,
				"other_user_email": otherUserEmail,
				"name": "",
				"latest_message": [
					"date": dateString,
					"message": message,
					"is_read": false
				]
			]
			
			
			if var conversations = userNode["conversations"] as? [[String: Any]] {
				// conversation array exists for current user
				// you should append
				conversations.append(newConversationData)
				userNode["conversations"] = conversations
				
				ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
					guard error == nil else {
						completion(false)
						return
					}
					self?.finishCreatingConversation(conversationID: conversationId,
											   firstMessage: firstMessage,
											   completion: completion)
				})
				
			}
			else {
				// conversation array does NOT exist
				// create it
				userNode["conversations"] = [
					newConversationData
				]
				
				ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
					guard error == nil else {
						completion(false)
						return
					}
					self?.finishCreatingConversation(conversationID: conversationId,
											   firstMessage: firstMessage,
											   completion: completion)
				})
			}
		})
		
	}
	
	private func finishCreatingConversation( conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
		
		let messageDate = firstMessage.sentDate
		let dateString = ChatViewController.dateFormatter.string(from: messageDate)
		
		var message = ""
		
		switch firstMessage.kind {
			
		case .text(let messageText):
			message = messageText
		case .attributedText(_):
			break
		case .photo(_):
			break
		case .video(_):
			break
		case .location(_):
			break
		case .emoji(_):
			break
		case .audio(_):
			break
		case .contact(_):
			break
		case .linkPreview(_):
			break
		case .custom(_):
			break
		}
		
		guard let myEmmail = UserDefaults.standard.value(forKey: "email") as? String else {
			completion(false)
			return
		}
		
		let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmmail)
		
		let collectionMessage: [String: Any] = [
			"id": firstMessage.messageId,
			"type": firstMessage.kind.messageKindString,
			"content": message,
			"date": dateString,
			"sender_email": currentUserEmail,
			"is_read": false
		]
		
		let value: [String: Any] = [
			 "messages": [
				 collectionMessage
			 ]
		 ]
		
		database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
					guard error == nil else {
						completion(false)
						return
					}
					completion(true)
				})
	}
	
	/// Fetches and returns all conversations for the user with passed in email
	public func getAllConversations(for email: String, completion: @escaping (Result<String, Error>) -> Void) {
		
	}
	
	/// Gets all messages for a given conversatino
	public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<String, Error>) -> Void) {
		
	}
	
	/// Sends a message with target conversation and message
	public func sendMessage(to conversation: String, mmessage: Message, completion: @escaping (Bool) -> Void) {
		
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
