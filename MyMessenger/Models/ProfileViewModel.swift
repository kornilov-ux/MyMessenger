//
//  ProfileViewModel.swift
//  MyMessenger
//
//  Created by Alex  on 24.05.2024.
//

import Foundation

enum ProfileViewModelType {
	case info, logout
}

struct ProfileViewModel {
	let viewModelType: ProfileViewModelType
	let title: String
	let handler: (() -> Void)?
}
