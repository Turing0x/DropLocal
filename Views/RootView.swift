import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var service: LocalTransferService
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 1:
                        ReceiveView()
                    case 2:
                        ActivityView(records: viewModel.records)
                    default:
                        SendView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack {
                    TabButton(title: "Enviar", systemImage: "arrow.up.circle.fill", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Recibir", systemImage: "arrow.down.circle.fill", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "Actividad", systemImage: "clock.arrow.circlepath", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.appSurface.opacity(0.96))
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SendView: View {
    @EnvironmentObject private var service: LocalTransferService
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HeaderView(
                        eyebrow: "TRANSFERENCIA LOCAL",
                        title: "Envía sin límites.",
                        subtitle: "Directo entre dispositivos. Sin nube, sin cuentas."
                    )

                    FileDropZone {
                        viewModel.isFileImporterPresented = true
                    }

                    if !viewModel.selectedFiles.isEmpty {
                        FileQueueView(files: viewModel.selectedFiles, onRemove: viewModel.removeFile)
                    }

                    DevicePickerView(
                        devices: service.devices,
                        selectedDevice: $viewModel.selectedDevice,
                        isDiscovering: service.isDiscovering
                    )

                    Button {
                        viewModel.send(using: service)
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(viewModel.isSending ? "Enviando…" : "Enviar archivos")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isSending)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .fileImporter(
                isPresented: $viewModel.isFileImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                if case let .success(urls) = result {
                    viewModel.addFiles(urls)
                }
            }
            .alert(
                "No se pudo enviar",
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { if !$0 { viewModel.alertMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }
}

private struct ReceiveView: View {
    @EnvironmentObject private var service: LocalTransferService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HeaderView(
                        eyebrow: "MODO RECEPTOR",
                        title: "Todo listo para recibir.",
                        subtitle: "Mantén esta pantalla abierta y aparecerás como dispositivo cercano."
                    )

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.appMint.opacity(0.14))
                                .frame(width: 48, height: 48)
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.appMint)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Visible en la red local")
                                .font(.headline)
                            Text("Otros dispositivos pueden encontrarte ahora")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(Color.appMint)
                            .frame(width: 9, height: 9)
                    }
                    .padding(18)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    if service.receivedFiles.isEmpty {
                        EmptyStateView(
                            icon: "tray.and.arrow.down",
                            title: "Aún no has recibido nada",
                            message: "Los archivos aparecerán aquí al terminar una transferencia."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recibidos recientemente")
                                .font(.headline)
                            ForEach(service.receivedFiles, id: \.self) { url in
                                Label(url.lastPathComponent, systemImage: "doc.fill")
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }
}

private struct ActivityView: View {
    let records: [TransferRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HeaderView(
                        eyebrow: "HISTORIAL",
                        title: "Tu actividad.",
                        subtitle: "Un vistazo a tus transferencias recientes."
                    )

                    if records.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "Sin transferencias todavía",
                            message: "Cuando envíes un archivo, verás aquí el estado y el dispositivo de destino."
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(records) { record in
                                TransferProgressRow(record: record)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }
}

private struct HeaderView: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.appMint)
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FileDropZone: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.appMint.opacity(0.15))
                        .frame(width: 62, height: 62)
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(Color.appMint)
                }
                Text("Añadir archivos")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Fotos, vídeos, documentos y más")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.appMint.opacity(0.42), style: StrokeStyle(lineWidth: 1.2, dash: [7]))
                    .background(Color.appMint.opacity(0.04).clipShape(RoundedRectangle(cornerRadius: 22)))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FileQueueView: View {
    let files: [SelectedFile]
    let onRemove: (SelectedFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Archivos seleccionados")
                    .font(.headline)
                Spacer()
                Text("\(files.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appMint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.appMint.opacity(0.13))
                    .clipShape(Capsule())
            }
            ForEach(files) { file in
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(Color.appBlue)
                        .frame(width: 34, height: 34)
                        .background(Color.appBlue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(file.size.fileSizeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        onRemove(file)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
        }
    }
}

private struct DevicePickerView: View {
    let devices: [DiscoveredDevice]
    @Binding var selectedDevice: DiscoveredDevice?
    let isDiscovering: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dispositivos cercanos")
                    .font(.headline)
                Spacer()
                if isDiscovering {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.appMint)
                }
            }

            if devices.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "wifi")
                        .foregroundStyle(Color.appMint)
                    Text("Buscando dispositivos en tu red…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(17)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
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

private struct DeviceCard: View {
    let device: DiscoveredDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "iphone")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.appBackground : Color.appMint)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.appMint : Color.appMint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(device.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.appMint : Color.white.opacity(0.2))
            }
            .padding(13)
            .background(isSelected ? Color.appMint.opacity(0.12) : Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.appMint.opacity(0.7) : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct TransferProgressRow: View {
    let record: TransferRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: record.state == .completed ? "checkmark" : "arrow.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(record.state == .completed ? Color.appMint : Color.appBlue)
                    .frame(width: 34, height: 34)
                    .background((record.state == .completed ? Color.appMint : Color.appBlue).opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.fileName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text("\(record.deviceName) · \(record.size.fileSizeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(record.state.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(record.state == .completed ? Color.appMint : .secondary)
            }
            if record.state == .transferring {
                ProgressView(value: record.progress)
                    .tint(Color.appMint)
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.appMint)
                .frame(width: 64, height: 64)
                .background(Color.appMint.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 22)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.appMint : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.appBackground)
            .background(
                LinearGradient(
                    colors: [Color.appMint, Color.appMint.opacity(0.78)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private extension Color {
    static let appBackground = Color(red: 0.035, green: 0.055, blue: 0.09)
    static let appSurface = Color(red: 0.075, green: 0.105, blue: 0.15)
    static let appMint = Color(red: 0.34, green: 0.92, blue: 0.74)
    static let appBlue = Color(red: 0.36, green: 0.67, blue: 1)
}