import SwiftUI

struct ReceiveView: View {
    @Environment(LocalTransferService.self) private var service

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TDDSpacing.s20) {
                    HeaderView(
                        eyebrow: "MODO RECEPTOR",
                        title: "Todo listo para recibir.",
                        subtitle: "Mantén esta pantalla abierta y aparecerás como dispositivo cercano."
                    )

                    HStack(spacing: TDDSpacing.s16) {
                        ZStack {
                            Circle()
                                .fill(TDDColor.primary.opacity(0.14))
                                .frame(width: 48, height: 48)
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: TDDFont.xl.size, weight: .semibold))
                                .foregroundStyle(TDDColor.primary)
                        }
                        VStack(alignment: .leading, spacing: TDDSpacing.s4) {
                            Text("Visible en la red local")
                                .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                                .foregroundStyle(TDDColor.foreground)
                            Text("Otros dispositivos pueden encontrarte ahora")
                                .font(TDDFont.sans(TDDFont.sm.size))
                                .foregroundStyle(TDDColor.mutedForeground)
                        }
                        Spacer()
                        Circle()
                            .fill(TDDColor.primary)
                            .frame(width: 9, height: 9)
                    }
                    .padding(TDDSpacing.s16)
                    .background(TDDColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))

                    if service.receivedFiles.isEmpty {
                        EmptyStateView(
                            icon: "tray.and.arrow.down",
                            title: "Aún no has recibido nada",
                            message: "Los archivos aparecerán aquí al terminar una transferencia."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: TDDSpacing.s12) {
                            Text("Recibidos recientemente")
                                .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                                .foregroundStyle(TDDColor.foreground)
                            ForEach(service.receivedFiles, id: \.self) { url in
                                Label(url.lastPathComponent, systemImage: "doc.fill")
                                    .foregroundStyle(TDDColor.foreground)
                                    .padding(.vertical, TDDSpacing.s8)
                            }
                        }
                    }
                }
                .padding(TDDSpacing.s20)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
