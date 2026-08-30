import SwiftUI

struct FileQueueView: View {
    let files: [SelectedFile]
    let onRemove: (SelectedFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TDDSpacing.s12) {
            HStack {
                Text("Archivos seleccionados")
                    .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                    .foregroundStyle(TDDColor.foreground)
                Spacer()
                Text("\(files.count)")
                    .font(TDDFont.sans(TDDFont.xs.size, weight: .bold))
                    .foregroundStyle(TDDColor.primary)
                    .padding(.horizontal, TDDSpacing.s8)
                    .padding(.vertical, TDDSpacing.s4)
                    .background(TDDColor.primary.opacity(0.13))
                    .clipShape(Capsule())
            }
            ForEach(files) { file in
                HStack(spacing: TDDSpacing.s12) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(TDDColor.ctaSecondaryBg)
                        .frame(width: 34, height: 34)
                        .background(TDDColor.ctaSecondaryBg.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: TDDRadius.md))
                    VStack(alignment: .leading, spacing: TDDSpacing.s4) {
                        Text(file.name)
                            .font(TDDFont.sans(TDDFont.sm.size, weight: .medium))
                            .foregroundStyle(TDDColor.foreground)
                            .lineLimit(1)
                        Text(file.size.fileSizeLabel)
                            .font(TDDFont.sans(TDDFont.xs.size))
                            .foregroundStyle(TDDColor.mutedForeground)
                    }
                    Spacer()
                    Button {
                        onRemove(file)
                    } label: {
                        Image(systemName: "xmark")
                            .font(TDDFont.sans(TDDFont.xs.size, weight: .bold))
                            .foregroundStyle(TDDColor.mutedForeground)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(TDDSpacing.s12)
                .background(TDDColor.card)
                .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))
            }
        }
    }
}
