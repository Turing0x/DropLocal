import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedFiles: [SelectedFile] = []
    @Published var selectedDevice: DiscoveredDevice?
    @Published var records: [TransferRecord] = []
    @Published var alertMessage: String?
    @Published var isFileImporterPresented = false
    @Published var isSending = false

    func addFiles(_ urls: [URL]) {
        let newFiles = urls.map(SelectedFile.init)
        let existingURLs = Set(selectedFiles.map(\.url))
        selectedFiles.append(contentsOf: newFiles.filter { !existingURLs.contains($0.url) })
    }

    func removeFile(_ file: SelectedFile) {
        selectedFiles.removeAll { $0.id == file.id }
    }

    func send(using service: LocalTransferService) {
        guard let selectedDevice else {
            alertMessage = TransferServiceError.noDevice.localizedDescription
            return
        }
        guard !selectedFiles.isEmpty else {
            alertMessage = "Añade al menos un archivo para empezar."
            return
        }

        isSending = true
        let filesToSend = selectedFiles
        Task {
            for file in filesToSend {
                let record = TransferRecord(
                    fileName: file.name,
                    size: file.size,
                    deviceName: selectedDevice.name,
                    date: Date(),
                    progress: 0,
                    state: .preparing
                )
                records.insert(record, at: 0)
                let recordID = record.id

                do {
                    update(recordID, progress: 0, state: .transferring)
                    try await service.send(file: file, to: selectedDevice) { [weak self] progress in
                        self?.update(recordID, progress: progress, state: .transferring)
                    }
                    update(recordID, progress: 1, state: .completed)
                } catch {
                    update(recordID, progress: 0, state: .failed(error.localizedDescription))
                }
            }
            isSending = false
            selectedFiles = []
        }
    }

    private func update(_ id: UUID, progress: Double, state: TransferState) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].progress = progress
        records[index].state = state
    }
}