import SwiftUI

struct SettingsView: View {
    @State private var connectedAccounts: [PlatformAccount] = []
    @State private var showConnectSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Connected Accounts") {
                    ForEach(connectedAccounts) { account in
                        HStack {
                            Text(account.platform.rawValue)
                            Spacer()
                            Text(account.accountName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button(action: { showConnectSheet = true }) {
                        Label("Connect New Account", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showConnectSheet) {
                ConnectPlatformView(isPresented: $showConnectSheet, connectedAccounts: $connectedAccounts)
            }
        }
    }
}

struct ConnectPlatformView: View {
    @Binding var isPresented: Bool
    @Binding var connectedAccounts: [PlatformAccount]
    @State private var selectedPlatform: MarketplacePlatform = .ebay
    @State private var accountName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Platform") {
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(MarketplacePlatform.allCases, id: \.self) { platform in
                            Text(platform.rawValue).tag(platform)
                        }
                    }
                }

                Section("Account") {
                    TextField("Account Name", text: $accountName)
                }

                Section {
                    Button(action: connectAccount) {
                        HStack {
                            Spacer()
                            Text("Connect with \(selectedPlatform.rawValue)")
                            Spacer()
                        }
                    }
                    .disabled(accountName.isEmpty)
                }
            }
            .navigationTitle("Connect Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func connectAccount() {
        let account = PlatformAccount(
            id: UUID(),
            platform: selectedPlatform,
            accountName: accountName,
            accessToken: "token",
            refreshToken: "refresh",
            tokenExpiresAt: Date().addingTimeInterval(3600),
            scopes: [],
            isActive: true,
            connectedAt: Date()
        )
        connectedAccounts.append(account)
        isPresented = false
    }
}
