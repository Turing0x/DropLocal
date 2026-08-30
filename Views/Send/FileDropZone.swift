import SwiftUI

struct FileDropZone: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: TDDSpacing.s16) {
                ZStack {
                    Circle()
                        .fill(TDDColor.primary.opacity(0.15))
                        .frame(width: 62, height: 62)
                    Image(systemName: "plus")
                        .font(.system(size: TDDFont.xl2.size, weight: .medium))
                        .foregroundStyle(TDDColor.primary)
                }
                Text("Añadir archivos")
                    .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                    .foregroundStyle(TDDColor.foreground)
                Text("Fotos, vídeos, documentos y más")
                    .font(TDDFont.sans(TDDFont.sm.size))
                    .foregroundStyle(TDDColor.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TDDSpacing.s32)
            .background(
                RoundedRectangle(cornerRadius: TDDRadius.xl)
                    .strokeBorder(TDDColor.primary.opacity(0.42), style: StrokeStyle(lineWidth: 1.2, dash: [7]))
                    .background(TDDColor.primary.opacity(0.04).clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl)))
            )
        }
        .buttonStyle(.plain)
    }
}
