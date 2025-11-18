//
//  UserModel.swift
//  TurnkeyiOSExample
//
//  Created by Taylor Dawson on 5/2/24.
//

import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var id: String = UUID().uuidString
    var userName: String?
    var email: String
    var walletAddress: String?
    var subOrgId: String?

    init( email: String, userName: String? = nil, subOrgId: String? = nil, walletAddress: String? = nil) {
        self.userName = userName
        self.email = email
        self.walletAddress = walletAddress
        self.subOrgId = subOrgId
    }
}
