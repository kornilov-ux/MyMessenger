//
//  AppDelegate.swift
//  MyMessenger
//
//  Created by Alex  on 14.09.2023.
//

import UIKit
import FirebaseCore
import GoogleSignIn


@main
class AppDelegate: UIResponder, UIApplicationDelegate {



	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		FirebaseApp.configure()
		return true
	}

	// MARK: UISceneSession Lifecycle

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		// Called when a new scene session is being created.
		// Use this method to select a configuration to create the new scene with.
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
		// Called when the user discards a scene session.
		// If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
		// Use this method to release any resources that were specific to the discarded scenes, as they will not return.
	}
	
	func handleSessionRestore(user: GIDGoogleUser) {
		guard let email = user.profile?.email,
			let firstName = user.profile?.givenName,
			let lastName = user.profile?.familyName else {
				return
		}

		UserDefaults.standard.set(email, forKey: "email")
		UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")

		DatabaseManager.shared.userExists(with: email, completion: { exists in
			if !exists {
				// insert to database
				let chatUser = ChatAppUser(
					firstName: firstName,
					lastName: lastName,
					emailAddress: email
				)
				DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
					if success {
						// upload image

						if user.profile?.hasImage == true {
							guard let url = user.profile?.imageURL(withDimension: 200) else {
								return
							}

							URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
								guard let data = data else {
									return
								}

								let filename = chatUser.profilePictureFileName
								StorageManager.shared.uploadProfilePicture(with: data, fileName: filename, completion: { result in
									switch result {
									case .success(let downloadUrl):
										UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
										print(downloadUrl)
									case .failure(let error):
										print("Storage maanger error: \(error)")
									}
								})
							}).resume()
						}
					}
				})
			}
		})

	}

	
	

}

