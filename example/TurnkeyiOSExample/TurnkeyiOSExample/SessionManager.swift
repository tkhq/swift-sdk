//
//  SessionManager.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 5/2/24.
//

import Foundation

class SessionManager {
    static let shared = SessionManager()
    var currentUser: User?

    private init() {}

    func setCurrentUser(user: User) {
        currentUser = user
    }

    func getCurrentUser() -> User? {
        return currentUser
    }
    
    func clearUser() {
        currentUser = nil
    }
}
