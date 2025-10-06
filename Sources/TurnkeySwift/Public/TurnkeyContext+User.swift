import Foundation
import TurnkeyHttp

extension TurnkeyContext {
    
    /// Refreshes the current user and associated wallet data.
    ///
    /// This method uses the currently selected session to refetch user data
    /// from the Turnkey API and updates the internal state.
    ///
    /// If no valid session is found, the method silently returns.
    public func refreshUser() async {
        
        guard
            authState == .authenticated,
            let client = client,
            let sessionKey = selectedSessionKey,
            let dto = try? JwtSessionStore.load(key: sessionKey)
        else {
            return
        }
        
        if let updated = try? await fetchSessionUser(
            using: client,
            organizationId: dto.organizationId,
            userId: dto.userId
        ) {
            await MainActor.run {
                self.user = updated
            }
        }
    }
    
    /// Updates the contact information for the user associated with the currently selected session.
    ///
    /// - Parameters:
    ///   - email: Optional email address to update.
    ///   - phone: Optional phone number to update.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           or `TurnkeySwiftError.failedToUpdateUser` if the update fails.
    public func updateUser(email: String? = nil, phone: String? = nil) async throws {
        
        guard
            authState == .authenticated,
            let client = client,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let trimmedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        
        do {
            let resp = try await client.updateUser(
                organizationId: user.organizationId,
                userId: user.id,
                userName: nil,
                userEmail: trimmedEmail,
                userTagIds: [],
                userPhoneNumber: trimmedPhone
            )
            
            if try resp.body.json.activity.result.updateUserResult?.userId != nil {
                await refreshUser()
            }
            
        } catch {
            throw TurnkeySwiftError.failedToUpdateUser(underlying: error)
        }
    }
    
    /// Updates the email address for the user associated with the currently selected session.
    ///
    /// If a verification token is provided, the email will be marked as verified. Otherwise, it will be considered unverified.
    /// Passing an empty string ("") will delete the user's email address.
    ///
    /// - Parameters:
    ///   - email: The new email address to update, or an empty string to delete it.
    ///   - verificationToken: Optional verification token to mark the email as verified.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           or `TurnkeySwiftError.failedToUpdateUserEmail` if the update fails.
    public func updateUserEmail(email: String, verificationToken: String? = nil ) async throws {
        guard
            authState == .authenticated,
            let client = client,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        do {
            let resp = try await client.updateUserEmail(
                organizationId: user.organizationId,
                userId: user.id,
                userEmail: email,
                verificationToken: verificationToken
            )
            
            if try resp.body.json.activity.result.updateUserEmailResult?.userId != nil {
                await refreshUser()
            }
            
        } catch {
            throw TurnkeySwiftError.failedToUpdateUserEmail(underlying: error)
        }
    }
    
    /// Updates the phone number for the user associated with the currently selected session.
    ///
    /// If a verification token is provided, the phone number will be marked as verified. Otherwise, it will be considered unverified.
    /// Passing an empty string ("") will delete the user's phone number.
    ///
    /// - Parameters:
    ///   - phone: The new phone number to update, or an empty string to delete it.
    ///   - verificationToken: Optional verification token to mark the phone number as verified.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           or `TurnkeySwiftError.failedToUpdateUserPhoneNumber` if the update fails.
    public func updateUserPhoneNumber(phone: String, verificationToken: String? = nil ) async throws {
        guard
            authState == .authenticated,
            let client = client,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            let resp = try await client.updateUserPhoneNumber(
                organizationId: user.organizationId,
                userId: user.id,
                userPhoneNumber: phone,
                verificationToken: verificationToken
            )
            
            if try resp.body.json.activity.result.updateUserPhoneNumberResult?.userId != nil {
                await refreshUser()
            }
            
        } catch {
            throw TurnkeySwiftError.failedToUpdateUserPhoneNumber(underlying: error)
        }
    }
}
