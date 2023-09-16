//
//  ChatViewController.swift
//  MyMessenger
//
//  Created by Alex  on 15.09.2023.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message: MessageType {
	public var sender: MessageKit.SenderType
	public var messageId: String
	public var sentDate: Date	
	public var kind: MessageKit.MessageKind
}

extension MessageKind {
	var messageKindString: String {
		switch self {
		case .text(_):
			return "text"
		case .attributedText(_):
			return "attributed_text"
		case .photo(_):
			return "photo"
		case .video(_):
			return "video"
		case .location(_):
			return "location"
		case .emoji(_):
			return "emoji"
		case .audio(_):
			return "audio"
		case .contact(_):
			return "contact"
		case .custom(_):
			return "customc"
		case .linkPreview(_):
			return "link"
		}
	}
}

struct Sender: SenderType {
	public var photoURL: String
	public var senderId: String
	public var displayName: String
}

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
		//let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
		
		return Sender(photoURL: "",
					  senderId: email,
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
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		messageInputBar.inputTextView.becomeFirstResponder()
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
		
		// Send Message
		if isNewConversation {
			// create convo in database
			let mmessage = Message(sender: selfSender ,
								   messageId: messageId,
								   sentDate: Date(),
								   kind: .text(text))
			
			
			
			DatabaseManager.shared.createNewConversation(with: otherUserEmail, firstMessage: mmessage, completion: { success in 
				if success {
					print("message sent")
				}
				else {
					print("faield ot send")
				}
			})
			
		}
		else {
			// append to existing conversation data
			
		}
	}
	
	private func createMessageId() -> String? {
		// date, otherUserEmail, senderEmail, randomInt
		guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
			return nil
		}

		// let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)

//		let dateString = Self.dateFormatter.string(from: Date())
//		let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
		
		let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
		let safeOtherUserEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
		let dateString = ChatViewController.dateFormatter.string(from: Date())
		let newIdentifier = "\(safeCurrentEmail)_\(safeOtherUserEmail)_\(dateString)_\(UUID().uuidString)"
		
		let sanitizedIdentifier = sanitizeFirebasePath(newIdentifier)
		
		print("created message id: \(sanitizedIdentifier)")
		
		return sanitizedIdentifier

		//return newIdentifier
	}
	
	public func sanitizeFirebasePath(_ input: String) -> String {
		var sanitizedString = input
		let forbiddenCharacters: [Character] = [".", "#", "$", "[", "]"]
		
		for char in forbiddenCharacters {
			sanitizedString = sanitizedString.replacingOccurrences(of: String(char), with: "-")
		}
		
		return sanitizedString
	}
	
}


extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
	var currentSender: MessageKit.SenderType {
		if let sender = selfSender {
			return sender
		}
		fatalError("Self Sender is nil, email should be cached")
		return Sender(photoURL: "", senderId: "12", displayName: "")
	}
	
	
//	func currentSender() -> SenderType {
//		if let sender = selfSender {
//			return sender
//		}
//		fatalError("Self Sender is nil, email should be cached")
//		return Sender(photoURL: "", senderId: "12", displayName: "")
//
//	}
	
	func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
		return messages[indexPath.section]
	}
	
	func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
		return messages.count
	}
	
	
}
