import SwiftUI

struct HeaderView: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: TDDSpacing.s12) {
            Text(eyebrow)
                .font(TDDFont.sans(TDDFont.xs.size, weight: .bold))
                .tracking(TDDFont.trackingWide * TDDFont.xs.size)
                .foregroundStyle(TDDColor.primary)
            Text(title)
                .font(TDDFont.sans(TDDFont.xl4.size, weight: .bold))
                .foregroundStyle(TDDColor.foreground)
            Text(subtitle)
                .font(TDDFont.sans(TDDFont.sm.size))
                .foregroundStyle(TDDColor.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
