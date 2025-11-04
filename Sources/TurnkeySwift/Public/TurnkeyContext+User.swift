import Foundation
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {
    
    /// Fetches user data.
    ///
    /// - Returns: A `v1User` object containing user metadata.
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           or `TurnkeySwiftError.failedToFetchUser` if the fetch fails.
    public func fetchUser() async throws -> v1User {
        guard
            authState == .authenticated,
            let client = client,
            let session = session
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            let userResp = try await client.getUser(TGetUserBody(
                organizationId: session.organizationId,
                userId: session.userId
            ))
            return userResp.user
        } catch {
            throw TurnkeySwiftError.failedToFetchUser(underlying: error)
        }
    }
    
    /// Refreshes the current user data.
    ///
    /// This method uses the currently selected session to refetch user data
    /// from the Turnkey API and updates the internal state.
    ///
    /// - Throws: `TurnkeySwiftError.failedToFetchUser` if the refresh fails.
    public func refreshUser() async throws {
        // TODO: we currently throw a failedToFetchUser error which breaks our convention
        // this should be failedToRefreshUser
        let user = try await fetchUser()
        await MainActor.run {
            self.user = user
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
            let user = user,
            let session = session
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        do {
            _ = try await client.updateUserEmail(TUpdateUserEmailBody(
                organizationId: session.organizationId,
                userEmail: email,
                userId: user.userId,
                verificationToken: verificationToken
            ))
            
            try await refreshUser()
            
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
            let user = user,
            let session = session
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            _ = try await client.updateUserPhoneNumber(TUpdateUserPhoneNumberBody(
                organizationId: session.organizationId,
                userId: user.userId,
                userPhoneNumber: phone,
                verificationToken: verificationToken
            ))
            
            try await refreshUser()
            
        } catch {
            throw TurnkeySwiftError.failedToUpdateUserPhoneNumber(underlying: error)
        }
    }
}
