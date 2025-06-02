import SwiftUI
import TurnkeySwift
import TurnkeyHttp

struct DashboardView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var turnkey: TurnkeyContext
    @EnvironmentObject private var toast: ToastContext

    @State private var balances: [String: Double] = [:]
    @State private var ethPriceUSD: Double = 0
    @State private var exportedSeedPhrase: String? = nil
    
    
    @State private var showProfileMenu = false
    @State private var showWalletMenu = false
    
    @State private var showCreateWalletSheet = false
    @State private var showExportWalletSheet = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                
                DashboardHeader(
                    showProfileMenu: $showProfileMenu,
                    onSettings: handleSettingsPressed,
                    onLogout: handleLogoutPressed
                )
                
                ScrollView {
                    VStack(spacing: 0) {
                        if let wallets = turnkey.user?.wallets {
                            ForEach(wallets, id: \.id) { wallet in
                                let address = wallet.accounts.first?.address ?? ""
                                let balance = balances[address] ?? 0
                                let balanceUSD = balance * ethPriceUSD
                                
                                
                                WalletCardView(
                                    walletId: wallet.id,
                                    walletName: wallet.name,
                                    address: address,
                                    balanceUSD: balanceUSD,
                                    balanceETH: balance,
                                    onExport: handleExportPressed,
                                    onSign: handleSignMessagePressed
                                )
                                .padding()
                                .task {
                                    if !address.isEmpty && balances[address] == nil {
                                        do {
                                            let fetched = try await Ethereum.getBalance(for: address)
                                            await MainActor.run {
                                                balances[address] = fetched
                                            }
                                        } catch {
                                            await MainActor.run {
                                                balances[address] = 0
                                            }
                                            // we are using a free api, so rate limits are very common
                                            // so we fail silently and default to 0
                                        }
                                    }
                                }
                            }
                        }
                        
                        Color.clear.frame(height: 44)
                        
                    }
                }
                
                Spacer()
            }
            .task {
                do {
                    ethPriceUSD = try await Ethereum.getETHPriceUSD()
                } catch {
                    // we are using a free api, so rate limits are very common
                    // so we fail silently and default to 0
                }
            }
            
            WalletActionMenu(
                showWalletMenu: $showWalletMenu,
                onCreate: handleCreateWalletPressed,
                onImport: handleImportWalletPressed
            )
            
            OverlaySheet(isShowing: $showCreateWalletSheet) {
                CreateWalletSheet(isShowing: $showCreateWalletSheet) { name in
                    handleCreateWallet(name: name)
                }
            }
            
            if let phrase = exportedSeedPhrase {
                OverlaySheet(isShowing: $showExportWalletSheet) {
                    ExportWalletSheet(
                        isShowing: $showExportWalletSheet,
                        seedPhrase: phrase,
                        onDismiss: {
                            exportedSeedPhrase = nil
                        }
                    )
                }
            }
        }
    }
    
    private func runAfterClosingMenus(_ action: @escaping () -> Void) {
        // close any open menus
        showProfileMenu = false
        showWalletMenu = false
        
        // we defer execution until after state updates settle
        DispatchQueue.main.async {
            action()
        }
    }
    
    
    private func handleSettingsPressed() {
        runAfterClosingMenus {
            coordinator.push(MainRoute.settings)
        }
    }
    
    private func handleLogoutPressed() {
        runAfterClosingMenus {
            turnkey.clearSession()
        }
    }
    
    private func handleExportPressed(walletId: String) {
        Task {
            do {
                let seedPhrase = try await turnkey.exportWallet(walletId: walletId)
                runAfterClosingMenus {
                    withAnimation {
                        exportedSeedPhrase = seedPhrase
                        showExportWalletSheet = true
                    }
                }
            } catch {
                toast.show(message: "Failed to export wallet.", type: .error)
            }
        }
    }
    
    private func handleSignMessagePressed(walletAddress: String) {
        runAfterClosingMenus {
            coordinator.push(MainRoute.signMessage(walletAddress: walletAddress))
        }
    }
    
    private func handleCreateWalletPressed() {
        runAfterClosingMenus {
            withAnimation {
                showCreateWalletSheet = true
            }
        }
    }
    
    private func handleImportWalletPressed() {
        runAfterClosingMenus {
            coordinator.push(MainRoute.importWallet)
        }
    }
    
    private func handleCreateWallet(name: String) {
        Task {
            do {
                try await turnkey.createWallet(
                    walletName: name,
                    accounts: Constants.Turnkey.defaultEthereumAccounts
                )
            } catch {
                toast.show(message: "Failed to create wallet.", type: .error)
            }
        }
    }
    
}

struct DashboardHeader: View {
    @Binding var showProfileMenu: Bool
    var onSettings: () -> Void
    var onLogout: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Demo Wallet")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    withAnimation {
                        showProfileMenu.toggle()
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color.black)
            
            if showProfileMenu {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        Button(action: onSettings) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                            .padding()
                            .font(.system(size: 12))
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: onLogout) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("Log out")
                            }
                            .padding()
                            .font(.system(size: 12))
                        }
                    }
                    .background(Color.white)
                    .frame(width: UIScreen.main.bounds.width / 3)
                    .cornerRadius(10)
                    .shadow(radius: 8)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}


struct WalletActionMenu: View {
    @Binding var showWalletMenu: Bool
    let onCreate: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            if showWalletMenu {
                VStack(spacing: 4) {
                    Button(action: {
                        showWalletMenu = false
                        onCreate()
                    }) {
                        HStack {
                            Image(systemName: "tray.and.arrow.down")
                            Text("Create Wallet")
                        }
                        .padding()
                        .font(.system(size: 12))
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 4)
                    }
                    
                    Button(action: onImport) {
                        HStack {
                            Image(systemName: "tray.and.arrow.up")
                            Text("Import Wallet")
                        }
                        .padding()
                        .font(.system(size: 12))
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 4)
                    }
                }
                .padding(.bottom, 10)
            }
            
            Button(action: {
                showWalletMenu.toggle()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
            }
            .padding(.bottom, 24)
        }
    }
}

struct OverlaySheet<Content: View>: View {
    @Binding var isShowing: Bool
    let content: Content
    
    init(isShowing: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isShowing = isShowing
        self.content = content()
    }
    
    var body: some View {
        if isShowing {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .blur(radius: 10)
                    .transition(.opacity)
                    .zIndex(1)
                
                content
                    .frame(maxWidth: .infinity)
                    .padding()
                    .zIndex(2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct CreateWalletSheet: View {
    @Binding var isShowing: Bool
    var onCreate: (String) -> Void
    
    @State private var walletName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Wallet Name")
                .font(.headline)
            
            TextField("", text: $walletName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("Cancel") { isShowing = false }
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                
                Button("Create") {
                    onCreate(walletName)
                    isShowing = false
                }
                .font(.system(size: 16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: 350)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 25)
    }
}


struct ExportWalletSheet: View {
    @Binding var isShowing: Bool
    let seedPhrase: String
    let onDismiss: () -> Void
    
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Seed Phrase")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(seedPhrase)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Spacer()
                    Button {
                        UIPasteboard.general.string = seedPhrase
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Button("Done") {
                isShowing = false
                onDismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: 350)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 25)
    }
}
