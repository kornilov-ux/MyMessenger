//
//  ChatViewController.swift
//  MyMessenger
//
//  Created by Alex  on 15.09.2023.
//

import UIKit
import MessageKit
import InputBarAccessoryView


class ChatViewController: MessagesViewController {
	
	public static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .long
		formatter.locale = .current
		return formatter
	}()
	
	public let otherUserEmail: String
	private var conversationId: String?
	public var isNewConversation = false
	
	private var messages = [Message]()
	
	private var selfSender: Sender? { 
		guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
			return nil
		}
		
		let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
		
		return Sender(photoURL: "",
					  senderId: safeEmail,
					  displayName: "Me")
	}
	
	 init(with email: String, id: String?) {
		self.conversationId = id
		self.otherUserEmail = email
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	

    override func viewDidLoad() {
        super.viewDidLoad()
		view.backgroundColor = .red
		
		messagesCollectionView.messagesDataSource = self
		messagesCollectionView.messagesLayoutDelegate = self
		messagesCollectionView.messagesDisplayDelegate = self
		messageInputBar.delegate = self
    }
	
	private func listenForMessages(id: String, shouldScrollToBottom: Bool) {  
		print("Listening for messages in conversation with ID: \(id)")
			DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
				switch result {
				case .success(let messages):
					print("success in getting messages: \(messages)")
					guard !messages.isEmpty else {
						print("messages are empty")
						return
					}
					
					self?.messages = messages
					DispatchQueue.main.async {
						self?.messagesCollectionView.reloadDataAndKeepOffset()

						if shouldScrollToBottom {
							self?.messagesCollectionView.scrollToLastItem(animated: true)
						}
					}
				case .failure(let error):
					print("failed to get messages: \(error)")
				}
			})
		}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		messageInputBar.inputTextView.becomeFirstResponder()
		if let conversationId = conversationId { 
			listenForMessages(id: conversationId, shouldScrollToBottom: true)
		} 
	}
}


extension ChatViewController: InputBarAccessoryViewDelegate {
	
	func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
		guard !text.replacingOccurrences(of: " ", with: "").isEmpty, 
		let selfSender = self.selfSender, 
		let messageId = createMessageId() else {
			return
		}
		
		print("text: \(text)")
		
		let mmessage = Message(sender: selfSender,
							   messageId: messageId,
							   sentDate: Date(),
							   kind: .text(text))
		
		// Send Message
		if isNewConversation {
			// create convo in database
			DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: mmessage, completion: { [weak self] success in 
				if success {
					print("message sent")
					self?.isNewConversation = false
					let newConversationId = "conversation_\(mmessage.messageId)"
					self?.conversationId = newConversationId
					self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
					self?.messageInputBar.inputTextView.text = nil
				}
				else {
					print("faield to send")
				}
			})
			
		}
		else {
			// append to existing conversation data
			print("Appending message to existing conversation")
			guard let conversationId = conversationId, let name = self.title else {
				return
			}
			
			DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: mmessage, completion: { [weak self] success in
				if success {
					self?.messageInputBar.inputTextView.text = nil
					print("message sent")
				}
				else {
					print("failed to send")
				}
			})
		}
	}
	
	private func createMessageId() -> String? {
		// date, otherUserEmail, senderEmail, randomInt
		guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
			return nil
		}
		
		let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
		let dateString = Self.dateFormatter.string(from: Date())
		let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
		
		print("created message id: \(newIdentifier)")
		return newIdentifier
	}
	
}


extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
	var currentSender: MessageKit.SenderType {
		if let sender = selfSender {
			return sender
		}
		fatalError("Self Sender is nil, email should be cached")
	}
	
	
//	func currentSender() -> SenderType {
//		if let sender = selfSender {
//			return sender
//		}
//		fatalError("Self Sender is nil, email should be cached")
//		return Sender(photoURL: "", senderId: "12", displayName: "")
//
//	}
	
	func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
		return messages[indexPath.section]
	}
	
	func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
		return messages.count
	}
	
	
}
