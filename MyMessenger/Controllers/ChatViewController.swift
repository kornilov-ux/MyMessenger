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
	var sender: MessageKit.SenderType
	var messageId: String
	var sentDate: Date	
	var kind: MessageKit.MessageKind
}

struct Sender: SenderType {
	var photoURL: String
	var senderId: String
	var displayName: String
}

class ChatViewController: MessagesViewController {
	
	public let otherUserEmail: String
	public var isNewConversation = false
	
	private var messages = [Message]()
	
	private let selfSender = Sender(photoURL: "",
									senderId: "1",
									displayName: "joe q")
	
	 init(with email: String) {
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
		guard !text.replacingOccurrences(of: " ", with: "").isEmpty else {
			return
		}
		
		print("text: \(text)")
		
		// Send Message
		if isNewConversation {
			// create convo in database
			
		}
		else {
			// append to existing conversation data
			
		}
		
		
	}
	
	
}


extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
	var currentSender: MessageKit.SenderType {
		return selfSender
	}
	
	func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
		return messages[indexPath.section]
	}
	
	func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
		return messages.count
	}
	
	
}
