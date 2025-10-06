import Foundation
import TurnkeyCrypto

extension TurnkeyContext {
    
    /// Creates a new wallet with the given name and accounts.
    ///
    /// - Parameters:
    ///   - walletName: Name to assign to the new wallet.
    ///   - accounts: List of wallet accounts to generate.
    ///   - mnemonicLength: Optional mnemonic length (e.g. 12, 24).
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           or `TurnkeySwiftError.failedToCreateWallet` on failure.
    public func createWallet(
        walletName: String,
        accounts: [WalletAccountParams],
        mnemonicLength: Int32? = nil
    ) async throws {
        
        guard
            authState == .authenticated,
            let client = client,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            let resp = try await client.createWallet(
                organizationId: user.organizationId,
                walletName: walletName,
                accounts: accounts,
                mnemonicLength: mnemonicLength
            )
            
            if try resp.body.json.activity.result.createWalletResult?.walletId != nil {
                await refreshUser()
            }
        } catch {
            throw TurnkeySwiftError.failedToCreateWallet(underlying: error)
        }
    }
    
    /// Exports the mnemonic phrase for the specified wallet.
    ///
    /// - Parameter walletId: The wallet identifier to export.
    ///
    /// - Returns: The decrypted mnemonic phrase.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           `TurnkeySwiftError.invalidResponse` if response is malformed,
    ///           or `TurnkeySwiftError.failedToExportWallet` if export fails.
    public func exportWallet(walletId: String) async throws -> String {
        let (targetPublicKey, _, embeddedPriv) = TurnkeyCrypto.generateP256KeyPair()
        
        guard
            authState == .authenticated,
            let client = client,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            let resp = try await client.exportWallet(
                organizationId: user.organizationId,
                walletId: walletId,
                targetPublicKey: targetPublicKey,
                language: nil
            )
            
            guard let bundle = try resp.body.json.activity.result.exportWalletResult?.exportBundle
            else {
                throw TurnkeySwiftError.invalidResponse
            }
            
            return try TurnkeyCrypto.decryptExportBundle(
                exportBundle: bundle,
                organizationId: user.organizationId,
                embeddedPrivateKey: embeddedPriv,
                returnMnemonic: true
            )
        } catch {
            throw TurnkeySwiftError.failedToExportWallet(underlying: error)
        }
    }
    
    /// Imports an existing wallet using the provided mnemonic and account list.
    ///
    /// - Parameters:
    ///   - walletName: Name to assign to the imported wallet.
    ///   - mnemonic: The recovery phrase to import.
    ///   - accounts: List of wallet accounts to generate.
    ///
    /// - Returns: The resulting `Activity` object from the import.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           `TurnkeySwiftError.invalidResponse` if response is malformed,
    ///           or `TurnkeySwiftError.failedToImportWallet` if import fails.
    @discardableResult
    public func importWallet(
        walletName: String,
        mnemonic: String,
        accounts: [WalletAccountParams]
    ) async throws -> Activity {
        
        guard
            authState == .authenticated,
            let client = client,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            let initResp = try await client.initImportWallet(
                organizationId: user.organizationId,
                userId: user.id
            )
            
            guard
                let importBundle = try initResp.body.json
                    .activity.result.initImportWalletResult?.importBundle
            else {
                throw TurnkeySwiftError.invalidResponse
            }
            
            let encrypted = try TurnkeyCrypto.encryptWalletToBundle(
                mnemonic: mnemonic,
                importBundle: importBundle,
                userId: user.id,
                organizationId: user.organizationId
            )
            
            let resp = try await client.importWallet(
                organizationId: user.organizationId,
                userId: user.id,
                walletName: walletName,
                encryptedBundle: encrypted,
                accounts: accounts
            )
            
            let activity = try resp.body.json.activity
            
            if activity.result.importWalletResult?.walletId != nil {
                await refreshUser()
            }
            
            return activity
        } catch {
            throw TurnkeySwiftError.failedToImportWallet(underlying: error)
        }
    }
}
