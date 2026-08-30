import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: TDDSpacing.s12) {
            Image(systemName: icon)
                .font(.system(size: TDDFont.xl2.size))
                .foregroundStyle(TDDColor.primary)
                .frame(width: 64, height: 64)
                .background(TDDColor.primary.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                .foregroundStyle(TDDColor.foreground)
            Text(message)
                .font(TDDFont.sans(TDDFont.sm.size))
                .foregroundStyle(TDDColor.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TDDSpacing.s32)
        .padding(.horizontal, TDDSpacing.s24)
        .background(TDDColor.card)
        .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))
    }
}
