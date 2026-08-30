import SwiftUI

struct SendView: View {
    @Environment(LocalTransferService.self) private var service
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TDDSpacing.s24) {
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
                        HStack(spacing: TDDSpacing.s8) {
                            if viewModel.isSending {
                                ProgressView()
                                    .tint(TDDColor.ctaPrimaryFg)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(viewModel.isSending ? "Enviando…" : "Enviar archivos")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TDDSpacing.s16)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isSending)
                }
                .padding(.horizontal, TDDSpacing.s20)
                .padding(.top, TDDSpacing.s16)
                .padding(.bottom, TDDSpacing.s24)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
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
