import SwiftUI

struct WalletCardView: View {
    let walletId: String
    let walletName: String
    let address: String
    let balanceUSD: Double
    let balanceETH: Double
    let onExport: (String) -> Void
    let onSign: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Wallet name & address
            VStack(alignment: .leading, spacing: 4) {
                Text(walletName)
                    .font(.system(size: 20, weight: .semibold))
                
                HStack(spacing: 4) {
                    Text(truncateAddress(address))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            // Balances
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f ETH", balanceUSD))
                        .font(.system(size: 28, weight: .bold))
                    Text("USD")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                
                Text(String(format: "%.2f ETH", balanceETH))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Actions
            HStack(spacing: 8) {
                ActionButton(title: "Sign", action: { onSign(address) })
                ActionButton(title: "Export", action: {onExport(walletId)})
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
    
    private func truncateAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)…\(suffix)"
    }
}

private struct ActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.black)
            .frame(minWidth: 60)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}

