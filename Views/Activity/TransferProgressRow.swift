import SwiftUI

struct TransferProgressRow: View {
    let record: TransferRecord

    var body: some View {
        VStack(alignment: .leading, spacing: TDDSpacing.s12) {
            HStack(spacing: TDDSpacing.s12) {
                Image(systemName: record.state == .completed ? "checkmark" : "arrow.up")
                    .font(TDDFont.sans(TDDFont.xs.size, weight: .bold))
                    .foregroundStyle(record.state == .completed ? TDDColor.primary : TDDColor.ctaSecondaryBg)
                    .frame(width: 34, height: 34)
                    .background((record.state == .completed ? TDDColor.primary : TDDColor.ctaSecondaryBg).opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: TDDRadius.md))
                VStack(alignment: .leading, spacing: TDDSpacing.s4) {
                    Text(record.fileName)
                        .font(TDDFont.sans(TDDFont.sm.size, weight: .medium))
                        .foregroundStyle(TDDColor.foreground)
                        .lineLimit(1)
                    Text("\(record.deviceName) · \(record.size.fileSizeLabel)")
                        .font(TDDFont.sans(TDDFont.xs.size))
                        .foregroundStyle(TDDColor.mutedForeground)
                }
                Spacer()
                Text(record.state.label)
                    .font(TDDFont.sans(TDDFont.xs.size, weight: .semibold))
                    .foregroundStyle(record.state == .completed ? TDDColor.primary : TDDColor.mutedForeground)
            }
            if record.state == .transferring {
                ProgressView(value: record.progress)
                    .tint(TDDColor.primary)
            }
        }
        .padding(TDDSpacing.s16)
        .background(TDDColor.card)
        .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))
    }
}
