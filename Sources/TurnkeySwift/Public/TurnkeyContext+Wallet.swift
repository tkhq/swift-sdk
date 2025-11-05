import Foundation
import TurnkeyTypes
import TurnkeyCrypto

extension TurnkeyContext {
    
    /// Fetches all wallets and their associated accounts for the active session.
    ///
    /// Retrieves wallet metadata and concurrently fetches account details for each wallet.
    ///
    /// - Returns: An array of `Wallet` objects including their accounts.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.failedToFetchWallets` if fetching wallets or accounts fails.
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
    
    /// Refreshes the wallet list for the active session.
    ///
    /// Refetches all wallets and their accounts from the Turnkey API
    /// and updates the local wallet state on the main thread.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.failedToFetchWallets` if the refresh operation fails.
    public func refreshWallets() async throws {
        // TODO: we currently throw a failedToFetchWallets error which breaks our convention
        // this should be failedToRefreshWallets
        let wallets = try await fetchWallets()
        await MainActor.run {
            self.wallets = wallets
        }
    }
    
    /// Creates a new wallet under the active organization.
    ///
    /// Generates a wallet with the specified name, account parameters, and optional mnemonic length.
    ///
    /// - Parameters:
    ///   - walletName: The name to assign to the new wallet.
    ///   - accounts: The list of account parameters to generate under this wallet.
    ///   - mnemonicLength: Optional mnemonic phrase length (e.g. `12` or `24`).
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.failedToCreateWallet` if wallet creation fails.
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
    
    /// Imports an existing wallet using a mnemonic phrase.
    ///
    /// Initializes an import bundle, encrypts the mnemonic, and sends it to the Turnkey API.
    /// The imported wallet is automatically added to the current session’s organization.
    ///
    /// - Parameters:
    ///   - walletName: The name to assign to the imported wallet.
    ///   - mnemonic: The recovery phrase to import.
    ///   - accounts: The list of wallet accounts to generate.
    ///
    /// - Returns: The ID of the imported wallet.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.invalidResponse` if the API response is malformed.
    ///   - `TurnkeySwiftError.failedToImportWallet` if the import operation fails.
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
    
    
    /// Exports a wallet’s mnemonic phrase.
    ///
    /// Generates an ephemeral key pair, requests an export bundle, and decrypts it locally.
    ///
    /// - Parameters:
    ///   - walletId: The wallet identifier to export.
    ///   - dangerouslyOverrideSignerPublicKey: Optional public key override for advanced use.
    ///   - returnMnemonic: Whether to return the mnemonic phrase (defaults to `true`).
    ///
    /// - Returns: The decrypted mnemonic phrase or export data.
    ///
    /// - Throws:
    ///   - `TurnkeySwiftError.invalidSession` if no active session is found.
    ///   - `TurnkeySwiftError.invalidResponse` if the API response is malformed.
    ///   - `TurnkeySwiftError.failedToExportWallet` if decryption or export fails.
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
