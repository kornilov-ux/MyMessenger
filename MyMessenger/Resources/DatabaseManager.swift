//
//  DatabaseManager.swift
//  MyMessenger
//
//  Created by Alex  on 14.09.2023.
//

import Foundation
import FirebaseDatabase
import MessageKit

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

extension DatabaseManager {

	/// Returns dictionary node at child path
	public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
		database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
			guard let value = snapshot.value else {
				completion(.failure(DatabaseError.failedToFetch))
				return
			}
			completion(.success(value))
		}
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
				print("failed to write to database")
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
	
	/// Creates a new conversation with target user email and first message sent
	public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
		guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
			  let currentNamme = UserDefaults.standard.value(forKey: "name") as? String else {
			return
		}
		
		let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
		let ref = database.child("\(safeEmail)")

		ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in 
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
			case .attributedText(_), .photo(_), .video(_), .location(_), .emoji(_), .audio(_), .contact(_),.custom(_), .linkPreview(_):
				break
			}
			
			let conversationId = "conversation_\(firstMessage.messageId)"
			
			let newConversationData: [String: Any] = [
				"id": conversationId,
				"other_user_email": otherUserEmail,
				"name": name,
				"latest_message": [
					"date": dateString,
					"message": message,
					"is_read": false
				]
			]
			
			///code from the last commit
			let recipient_newConversationData: [String: Any] = [
				"id": conversationId,
				"other_user_email": safeEmail,
				"name": currentNamme,
				"latest_message": [
					"date": dateString,
					"message": message,
					"is_read": false
				]
			]
			// Update recipient conversaiton entry
			
			self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
				if var conversatoins = snapshot.value as? [[String: Any]] {
					// append
					conversatoins.append(recipient_newConversationData)
					self?.database.child("\(otherUserEmail)/conversations").setValue(conversatoins)
				}
				else {
					// create
					self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
				}
			})
			///code from the last commit
			
			// Update current user conversation entry
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
					self?.finishCreatingConversation(name: name,
													 conversationID: conversationId,
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
					self?.finishCreatingConversation(name: name, 
													 conversationID: conversationId,
													 firstMessage: firstMessage,
													 completion: completion)
				})
			}
		})
		
	}
	
	private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
		
		let messageDate = firstMessage.sentDate
		let dateString = ChatViewController.dateFormatter.string(from: messageDate)
		
		var message = ""
		
		switch firstMessage.kind {
			
		case .text(let messageText):
			message = messageText
		case .attributedText(_), .photo(_), .video(_), .location(_), .emoji(_), .audio(_), .contact(_),.custom(_), .linkPreview(_):
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
			"is_read": false,
			"name": name
		]
		
		let value: [String: Any] = [
			 "messages": [
				 collectionMessage
			 ]
		 ]
		print("adding conversation: \(conversationID)")
		
		database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
			guard error == nil else {
				completion(false)
				return
			}
			completion(true)
		})
	}
	
	/// Fetches and returns all conversations for the user with passed in email
	public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
		database.child("\(email)/conversations").observe(.value, with: { snapshot in 
			print("Snapshot value: \(String(describing: snapshot.value))")
			guard let value = snapshot.value as? [[String: Any]] else {
				completion(.failure(DatabaseError.failedToFetch))
				return
			}
			print("Conversations from snapshot: \(value)")
			let conversations: [Conversation] = value.compactMap({ dictionary in
				guard let conversationId = dictionary["id"] as? String,
					  let name = dictionary["name"] as? String,
					  let otherUserEmail = dictionary["other_user_email"] as? String,
					  let latestMessage = dictionary["latest_message"] as? [String: Any],
					  let date = latestMessage["date"] as? String,
					  let message = latestMessage["message"] as? String,
					  let isRead = latestMessage["is_read"] as? Bool else {
					return nil
				}
				
				let latestMmessageObject = LatestMessage(date: date,
														 text: message,
														 isRead: isRead)
				return Conversation(id: conversationId,
									name: name,
									otherUserEmail: otherUserEmail,
									latestMessage: latestMmessageObject)
			})
			print("Parsed conversations: \(conversations)")
			completion(.success(conversations))
		})
	}
	
	/// Gets all messages for a given conversation
	public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
		print("Fetching messages for conversation with ID: \(id)")
		database.child("\(id)/messages").observe(.value, with: { snapshot in
			print("Received snapshot: \(snapshot)")
			guard let value = snapshot.value as? [[String: Any]] else {
				print("Failed to convert snapshot value to [[String: Any]]")
				completion(.failure(DatabaseError.failedToFetch))
				return
			}

			var messages: [Message] = []
			for messageData in value {
				if let message = self.parseMessage(from: messageData) {
					messages.append(message)
				} else {
					print("Failed to convert message dictionary to Message object")
				}
			}

			print("Successfully created Message objects")
			completion(.success(messages))
		})
	}

	private func parseMessage(from data: [String: Any]) -> Message? {
		guard let name = data["name"] as? String,
			  //let isRead = data["is_read"] as? Bool,
			  let messageID = data["id"] as? String,
			  let content = data["content"] as? String,
			  let senderEmail = data["sender_email"] as? String,
			  let type = data["type"] as? String,
			  let dateString = data["date"] as? String,
			  let date = ChatViewController.dateFormatter.date(from: dateString) else {
			return nil
		}

		var kind: MessageKind?

		switch type {
		case "text":
			kind = .text(content)
		default:
			// Обработка неизвестного типа сообщения
			break
		}

		guard let finalKind = kind else {
			return nil
		}

		let sender = Sender(photoURL: "",
							senderId: senderEmail,
							displayName: name)

		return Message(sender: sender,
					   messageId: messageID,
					   sentDate: date,
					   kind: finalKind)
	}
		///code from the last commit
	
	/// Sends a message with target conversation and message
	public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
		// add new message to messages
		// update sender latest message
		// update recipient latest message
		guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
			completion(false)
			return
		}
		
		let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
		
		database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
			guard let strongSelf = self else {
				return
			}
			
			guard var currentMessages = snapshot.value as? [[String: Any]] else {
				completion(false)
				return
			}
			
			let messageDate = newMessage.sentDate
			let dateString = ChatViewController.dateFormatter.string(from: messageDate)

			var message = ""
			switch newMessage.kind {
			case .text(let messageText):
				message = messageText
			case .attributedText(_):
				break
			case .photo(let mediaItem):
				if let targetUrlString = mediaItem.url?.absoluteString {
					message = targetUrlString
				}
				break
			case .video(let mediaItem):
				if let targetUrlString = mediaItem.url?.absoluteString {
					message = targetUrlString
				}
				break
			case .location(let locationData):
				let location = locationData.location
				message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
				break
			case .emoji(_):
				break
			case .audio(_):
				break
			case .contact(_):
				break
			case .custom(_), .linkPreview(_):
				break
			}
			
			guard let myEmmail = UserDefaults.standard.value(forKey: "email") as? String else {
				completion(false)
				return
			}
			
			let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmmail)
			
			let newMessageEntry: [String: Any] = [
				"id": newMessage.messageId,
				"type": newMessage.kind.messageKindString,
				"content": message,
				"date": dateString,
				"sender_email": currentUserEmail,
				"is_read": false,
				"name": name
			]
			
			currentMessages.append(newMessageEntry)
			
			strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
				guard error == nil else {
					completion(false)
					return
				}
				
				// MARK: -soon
				
				completion(true)
			}
		})
	}
	
	public func conversationExists(iwth targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
		   let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
		   guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
			   return
		   }
		   let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)

		   database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
			   guard let collection = snapshot.value as? [[String: Any]] else {
				   completion(.failure(DatabaseError.failedToFetch))
				   return
			   }

			   // iterate and find conversation with target sender
			   if let conversation = collection.first(where: {
				   guard let targetSenderEmail = $0["other_user_email"] as? String else {
					   return false
				   }
				   return safeSenderEmail == targetSenderEmail
			   }) {
				   // get id
				   guard let id = conversation["id"] as? String else {
					   completion(.failure(DatabaseError.failedToFetch))
					   return
				   }
				   completion(.success(id))
				   return
			   }

			   completion(.failure(DatabaseError.failedToFetch))
			   return
		   })
	   }
	
}

struct ChatAppUser {
	let firstName: String
	let lastName: String
	let emailAddress: String
	
	var safeEmail: String {
		var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
		safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
		return safeEmail
	}
	
	var profilePictureFileName: String {
		return "\(safeEmail)_profile_picture.png"
	}
	
}
