import SwiftUI

struct DeviceCard: View {
    let device: DiscoveredDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TDDSpacing.s16) {
                Image(systemName: "iphone")
                    .font(.system(size: TDDFont.xl.size, weight: .medium))
                    .foregroundStyle(isSelected ? TDDColor.background : TDDColor.primary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? TDDColor.primary : TDDColor.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: TDDRadius.md))
                VStack(alignment: .leading, spacing: TDDSpacing.s4) {
                    Text(device.name)
                        .font(TDDFont.sans(TDDFont.sm.size, weight: .semibold))
                        .foregroundStyle(TDDColor.foreground)
                    Text(device.detail)
                        .font(TDDFont.sans(TDDFont.xs.size))
                        .foregroundStyle(TDDColor.mutedForeground)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: TDDFont.xl.size))
                    .foregroundStyle(isSelected ? TDDColor.primary : TDDColor.mutedForeground.opacity(0.4))
            }
            .padding(TDDSpacing.s12)
            .background(isSelected ? TDDColor.primary.opacity(0.12) : TDDColor.card)
            .overlay(
                RoundedRectangle(cornerRadius: TDDRadius.xl)
                    .stroke(isSelected ? TDDColor.primary.opacity(0.7) : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))
        }
        .buttonStyle(.plain)
    }
}
