import SwiftUI

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: TDDSpacing.s4) {
                Image(systemName: systemImage)
                    .font(.system(size: TDDFont.xl.size, weight: .semibold))
                Text(title)
                    .font(TDDFont.sans(TDDFont.xs.size, weight: .semibold))
            }
            .foregroundStyle(isSelected ? TDDColor.primary : TDDColor.mutedForeground)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
