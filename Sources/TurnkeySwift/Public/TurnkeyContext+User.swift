import Foundation
import TurnkeyTypes
import TurnkeyHttp

extension TurnkeyContext {
    
    /// Fetches user data for the currently active session.
    ///
    /// Retrieves user metadata from the Turnkey API using the current session’s credentials.
    ///
    /// - Returns: A `v1User` object containing user information and metadata.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.failedToFetchUser` if the request or decoding fails.
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
    
    /// Refreshes and updates the current user data.
    ///
    /// Refetches user metadata from the Turnkey API using the active session
    /// and updates the local user state on the main thread.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.failedToFetchUser` if the request or decoding fails.
    public func refreshUser() async throws {
        // TODO: we currently throw a failedToFetchUser error which breaks our convention
        // this should be failedToRefreshUser
        let user = try await fetchUser()
        await MainActor.run {
            self.user = user
        }
    }
    
    /// Updates the user’s email address for the currently active session.
    ///
    /// If a verification token is provided, the email will be marked as verified.
    /// Passing an empty string (`""`) will remove the existing email address.
    ///
    /// - Parameters:
    ///   - email: The new email address to set, or `""` to delete it.
    ///   - verificationToken: Optional verification token to mark the email as verified.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.failedToUpdateUserEmail` if the update operation fails.
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
    
    /// Updates the user’s phone number for the currently active session.
    ///
    /// If a verification token is provided, the phone number will be marked as verified.
    /// Passing an empty string (`""`) will remove the existing phone number.
    ///
    /// - Parameters:
    ///   - phone: The new phone number to set, or `""` to delete it.
    ///   - verificationToken: Optional verification token to mark the phone number as verified.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.failedToUpdateUserPhoneNumber` if the update operation fails.
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
