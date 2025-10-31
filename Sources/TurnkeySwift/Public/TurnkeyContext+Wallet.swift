import Foundation
import TurnkeyTypes
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
            let resp = try await client.createWallet(TCreateWalletBody(
                organizationId: user.organizationId,
                accounts: accounts,
                mnemonicLength: mnemonicLength.map(Int.init),
                walletName: walletName
            ))
            
            if resp.activity.result.createWalletResult?.walletId != nil {
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
    /// - Returns: An `ExportWalletResult` containing the decrypted mnemonic phrase.
    ///
    /// - Throws: `TurnkeySwiftError.invalidSession` if no session is selected,
    ///           `TurnkeySwiftError.invalidResponse` if response is malformed,
    ///           or `TurnkeySwiftError.failedToExportWallet` if export fails.
    public func exportWallet(walletId: String, dangerouslyOverrideSignerPublicKey: String? = nil, returnMnemonic: Bool = true) async throws -> String {
        let (targetPublicKey, _, embeddedPriv) = TurnkeyCrypto.generateP256KeyPair()
        
        guard
            authState == .authenticated,
            let client = client,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            let resp = try await client.exportWallet(TExportWalletBody(
                organizationId: user.organizationId,
                targetPublicKey: targetPublicKey,
                walletId: walletId
            ))
            
            guard let bundle = resp.activity.result.exportWalletResult?.exportBundle
            else {
                throw TurnkeySwiftError.invalidResponse
            }
            
            let decrypted = try TurnkeyCrypto.decryptExportBundle(
                exportBundle: bundle,
                organizationId: user.organizationId,
                embeddedPrivateKey: embeddedPriv,
                dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey,
                returnMnemonic: returnMnemonic
            )
            
            return decrypted
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
            let initResp = try await client.initImportWallet(TInitImportWalletBody(
                organizationId: user.organizationId,
                userId: user.id
            ))
            
            guard
                let importBundle = initResp
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
            
            let resp = try await client.importWallet(TImportWalletBody(
                organizationId: user.organizationId,
                accounts: accounts,
                encryptedBundle: encrypted,
                userId: user.id,
                walletName: walletName
            ))
            
            let activity = resp.activity
            
            if activity.result.importWalletResult?.walletId != nil {
                await refreshUser()
            }
            
            return activity
        } catch {
            throw TurnkeySwiftError.failedToImportWallet(underlying: error)
        }
    }
}
