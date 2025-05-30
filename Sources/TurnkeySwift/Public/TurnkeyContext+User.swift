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
            let client,
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
    
    /// Updates the currently authenticated user's contact information.
    ///
    /// - Parameters:
    ///   - email: Optional email address to update.
    ///   - phone: Optional phone number to update.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           or `TurnkeySwiftError.failedToUpdateUser` if the update fails.
    public func updateUser(email: String? = nil, phone: String? = nil) async throws {
        guard let client, let user else {
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
}
