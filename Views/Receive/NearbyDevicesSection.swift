import SwiftUI

// Sección de la pestaña "Recibir" que lista los pares LocalSend
// descubiertos. Es deliberadamente aditiva: no toca el flujo de envío ni el
// de recepción viejos (que siguen con `LocalTransferService` y el protocolo
// `_locdrop._tcp` hasta la Sprint 2). Su único cometido en esta sprint es
// que se pueda comprobar a simple vista que el ordenador aparece aquí.
struct NearbyDevicesSection: View {
    @Environment(DiscoveryStore.self) private var discovery

    @State private var manualHost = ""
    @State private var isProbing = false

    var body: some View {
        VStack(alignment: .leading, spacing: TDDSpacing.s12) {
            header

            if discovery.devices.isEmpty {
                EmptyStateView(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    title: "Ningún dispositivo todavía",
                    message: "Abre LocalSend en el ordenador y espera unos segundos, o añádelo por su IP."
                )
            } else {
                ForEach(discovery.devices) { device in
                    row(for: device)
                }
            }

            manualEntry

            if let error = discovery.lastError {
                Text(error)
                    .font(TDDFont.sans(TDDFont.sm.size))
                    .foregroundStyle(TDDColor.destructive)
            }
        }
    }

    private var header: some View {
        HStack(spacing: TDDSpacing.s8) {
            Text("Dispositivos LocalSend cercanos")
                .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                .foregroundStyle(TDDColor.foreground)
            Spacer()
            if discovery.isScanning {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func row(for device: Device) -> some View {
        HStack(spacing: TDDSpacing.s16) {
            ZStack {
                Circle()
                    .fill(TDDColor.primary.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon(for: device.deviceType))
                    .font(.system(size: TDDFont.base.size, weight: .semibold))
                    .foregroundStyle(TDDColor.primary)
            }

            VStack(alignment: .leading, spacing: TDDSpacing.s4) {
                Text(device.alias)
                    .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                    .foregroundStyle(TDDColor.foreground)
                Text("\(device.host):\(device.port)")
                    .font(TDDFont.sans(TDDFont.sm.size))
                    .foregroundStyle(TDDColor.mutedForeground)
            }

            Spacer()

            Text(device.useHTTPS ? "HTTPS" : "HTTP")
                .font(TDDFont.sans(TDDFont.xs.size, weight: .medium))
                .foregroundStyle(TDDColor.badgeAvailableFg)
                .padding(.horizontal, TDDSpacing.s8)
                .padding(.vertical, TDDSpacing.s4)
                .background(TDDColor.badgeAvailableBg)
                .clipShape(RoundedRectangle(cornerRadius: TDDRadius.sm))
        }
        .padding(TDDSpacing.s16)
        .background(TDDColor.card)
        .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: TDDRadius.xl)
                .stroke(TDDColor.border, lineWidth: 1)
        )
    }

    // Vía de respaldo por IP, para redes donde el barrido automático no llega.
    private var manualEntry: some View {
        HStack(spacing: TDDSpacing.s8) {
            TextField("Añadir por IP (p. ej. 192.168.1.20)", text: $manualHost)
                .textFieldStyle(.plain)
                .font(TDDFont.sans(TDDFont.sm.size))
                .foregroundStyle(TDDColor.foreground)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .padding(TDDSpacing.s12)
                .background(TDDColor.muted)
                .clipShape(RoundedRectangle(cornerRadius: TDDRadius.md))

            Button {
                Task {
                    isProbing = true
                    if await discovery.addManually(host: manualHost) {
                        manualHost = ""
                    }
                    isProbing = false
                }
            } label: {
                if isProbing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: TDDFont.base.size, weight: .semibold))
                }
            }
            .frame(width: 44, height: 44)
            .background(TDDColor.primary)
            .foregroundStyle(TDDColor.primaryForeground)
            .clipShape(RoundedRectangle(cornerRadius: TDDRadius.md))
            .disabled(manualHost.isEmpty || isProbing)
        }
    }

    private func icon(for type: LocalSendDeviceType?) -> String {
        switch type {
        case .mobile: return "iphone"
        case .desktop: return "desktopcomputer"
        case .web: return "globe"
        case .headless, .server: return "server.rack"
        case nil: return "questionmark.circle"
        }
    }
}
