import SwiftUI

struct DevicePickerView: View {
    let devices: [DiscoveredDevice]
    @Binding var selectedDevice: DiscoveredDevice?
    let isDiscovering: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: TDDSpacing.s12) {
            HStack {
                Text("Dispositivos cercanos")
                    .font(TDDFont.sans(TDDFont.base.size, weight: .semibold))
                    .foregroundStyle(TDDColor.foreground)
                Spacer()
                if isDiscovering {
                    ProgressView()
                        .controlSize(.small)
                        .tint(TDDColor.primary)
                }
            }

            if devices.isEmpty {
                HStack(spacing: TDDSpacing.s12) {
                    Image(systemName: "wifi")
                        .foregroundStyle(TDDColor.primary)
                    Text("Buscando dispositivos en tu red…")
                        .font(TDDFont.sans(TDDFont.sm.size))
                        .foregroundStyle(TDDColor.mutedForeground)
                    Spacer()
                }
                .padding(TDDSpacing.s16)
                .background(TDDColor.card)
                .clipShape(RoundedRectangle(cornerRadius: TDDRadius.xl))
            } else {
                ForEach(devices) { device in
                    DeviceCard(device: device, isSelected: selectedDevice?.id == device.id) {
                        selectedDevice = device
                    }
                }
            }
        }
    }
}
