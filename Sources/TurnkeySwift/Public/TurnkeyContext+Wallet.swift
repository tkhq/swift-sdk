import Foundation
import TurnkeyTypes
import TurnkeyCrypto

extension TurnkeyContext {
    
    /// Fetches wallets with their accounts.
    ///
    /// - Parameters:
    ///   - client: The authenticated TurnkeyClient.
    ///   - organizationId: The organization ID associated with the session.
    /// - Returns: An array of `Wallet` objects with accounts.
    public func fetchWallets() async throws -> [Wallet] {
        guard
            authState == .authenticated,
            let client = client,
            let session = session
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        do {
            let resp = try await client.getWallets(TGetWalletsBody(organizationId: session.organizationId))
            
            // fetch wallet accounts concurrently
            let detailed = try await withThrowingTaskGroup(of: Wallet.self) { group in
                for w in resp.wallets {
                    group.addTask {
                        let accounts = try await client.getWalletAccounts(TGetWalletAccountsBody(
                            organizationId: session.organizationId,
                            walletId: w.walletId
                        )).accounts
                        
                        return Wallet(
                            walletId: w.walletId,
                            walletName: w.walletName,
                            createdAt: w.createdAt.seconds,
                            updatedAt: w.updatedAt.seconds,
                            exported: w.exported,
                            imported: w.imported,
                            accounts: accounts
                        )
                    }
                }
                
                var res: [Wallet] = []
                for try await item in group { res.append(item) }
                return res
            }
            
            return detailed
            
        } catch {
            throw TurnkeySwiftError.failedToFetchWallets(underlying: error)
        }
        
        
    }
    
    /// Refreshes the current wallets data.
    ///
    /// This method uses the currently selected session to refetch wallet data
    /// from the Turnkey API and updates the internal state.
    ///
    /// - Throws: `TurnkeySwiftError.failedToFetchWallets` if the refresh fails.
    public func refreshWallets() async throws {
        // TODO: we currently throw a failedToFetchWallets error which breaks our convention
        // this should be failedToRefreshWallets
        let wallets = try await fetchWallets()
        await MainActor.run {
            self.wallets = wallets
        }
    }
    
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
            let session = session
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            _ = try await client.createWallet(TCreateWalletBody(
                organizationId: session.organizationId,
                accounts: accounts,
                mnemonicLength: mnemonicLength.map(Int.init),
                walletName: walletName
            ))
            
            try await refreshWallets()
        } catch {
            throw TurnkeySwiftError.failedToCreateWallet(underlying: error)
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
    ) async throws -> String {
        
        guard
            authState == .authenticated,
            let client = client,
            let session = session,
            let user = user
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            let initResp = try await client.initImportWallet(TInitImportWalletBody(
                organizationId: session.organizationId,
                userId: user.userId
            ))
            
            let importBundle = initResp.importBundle
            
            let encrypted = try TurnkeyCrypto.encryptWalletToBundle(
                mnemonic: mnemonic,
                importBundle: importBundle,
                userId: user.userId,
                organizationId: session.organizationId
            )
            
            let resp = try await client.importWallet(TImportWalletBody(
                organizationId: session.organizationId,
                accounts: accounts,
                encryptedBundle: encrypted,
                userId: user.userId,
                walletName: walletName
            ))
            
            try await refreshWallets()
            
            return resp.walletId
        } catch {
            throw TurnkeySwiftError.failedToImportWallet(underlying: error)
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
            let session = session
        else {
            throw TurnkeySwiftError.invalidSession
        }
        
        
        
        do {
            let resp = try await client.exportWallet(TExportWalletBody(
                organizationId: session.organizationId,
                targetPublicKey: targetPublicKey,
                walletId: walletId
            ))
            
            let bundle = resp.exportBundle
            
            let decrypted = try TurnkeyCrypto.decryptExportBundle(
                exportBundle: bundle,
                organizationId: session.organizationId,
                embeddedPrivateKey: embeddedPriv,
                dangerouslyOverrideSignerPublicKey: dangerouslyOverrideSignerPublicKey,
                returnMnemonic: returnMnemonic
            )
            
            return decrypted
        } catch {
            throw TurnkeySwiftError.failedToExportWallet(underlying: error)
        }
    }
}
