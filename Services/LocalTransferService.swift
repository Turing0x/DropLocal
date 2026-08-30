import Foundation
import Network
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class LocalTransferService: ObservableObject {
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var isDiscovering = false
    @Published private(set) var receivedFiles: [URL] = []

    private let serviceType = "_locdrop._tcp"
    private let browserQueue = DispatchQueue(label: "com.locdrop.browser")
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var endpointByDeviceID: [String: NWEndpoint] = [:]

    init() {
        start()
    }

    func start() {
        guard browser == nil else { return }

        startListener()

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        self.browser = browser
        isDiscovering = true

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.isDiscovering = state == .ready || state == .setup
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let mapped = results.compactMap { result -> (DiscoveredDevice, NWEndpoint)? in
                guard case let .service(name, _, domain, _) = result.endpoint else {
                    return nil
                }
                let id = "\(name)|\(domain)"
                let device = DiscoveredDevice(
                    id: id,
                    name: name,
                    detail: "Red local"
                )
                return (device, result.endpoint)
            }

            Task { @MainActor in
                self?.devices = mapped.map { $0.0 }.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                self?.endpointByDeviceID = Dictionary(uniqueKeysWithValues: mapped.map { ($0.0.id, $0.1) })
            }
        }

        browser.start(queue: browserQueue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
        devices = []
        endpointByDeviceID = [:]
        isDiscovering = false
    }

    func send(file: SelectedFile, to device: DiscoveredDevice, progress: @escaping @MainActor (Double) -> Void) async throws {
        guard let endpoint = endpointByDeviceID[device.id] else {
            throw TransferServiceError.connectionFailed
        }

        let didAccess = file.url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                file.url.stopAccessingSecurityScopedResource()
            }
        }

        guard let handle = try? FileHandle(forReadingFrom: file.url) else {
            throw TransferServiceError.unreadableFile
        }
        defer { try? handle.close() }

        let fileSize = file.size
        let connection = NWConnection(to: endpoint, using: .tcp)
        let connectionQueue = DispatchQueue(label: "com.locdrop.send.\(file.id.uuidString)")
        connection.start(queue: connectionQueue)

        do {
            try await waitForReady(connection)

            let encodedName = Data(file.name.utf8).base64EncodedString()
            let header = """
            POST /v1/transfer HTTP/1.1\r
            Host: locdrop.local\r
            Content-Length: \(fileSize)\r
            X-File-Name-Base64: \(encodedName)\r
            X-Sender-Name: \(Self.currentDeviceName)\r
            Content-Type: application/octet-stream\r
            Connection: close\r
            \r
            """

            try await send(Data(header.utf8), on: connection)

            var sent: Int64 = 0
            while sent < fileSize {
                let remaining = fileSize - sent
                let chunkSize = Int(min(64 * 1024, remaining))
                let chunk = try handle.read(upToCount: chunkSize) ?? Data()
                guard !chunk.isEmpty else {
                    throw TransferServiceError.unreadableFile
                }
                try await send(chunk, on: connection)
                sent += Int64(chunk.count)
                progress(fileSize == 0 ? 1 : Double(sent) / Double(fileSize))
            }

            let response = try await receiveResponse(on: connection)
            connection.cancel()

            guard response.contains(" 200 ") else {
                throw TransferServiceError.remoteRejected("El dispositivo no aceptó el archivo.")
            }
            progress(1)
        } catch {
            connection.cancel()
            if let transferError = error as? TransferServiceError {
                throw transferError
            }
            throw TransferServiceError.connectionFailed
        }
    }

    private static var currentDeviceName: String {
        #if os(iOS)
        UIDevice.current.name
        #elseif os(macOS)
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #else
        ProcessInfo.processInfo.hostName
        #endif
    }

    private func startListener() {
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(
                name: Self.currentDeviceName,
                type: serviceType,
                txtRecord: nil
            )
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            listener.start(queue: browserQueue)
            self.listener = listener
        } catch {
            listener = nil
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: browserQueue)
        let incoming = IncomingTransfer(connection: connection) { [weak self] url in
            Task { @MainActor in
                self?.receivedFiles.insert(url, at: 0)
            }
        }
        incoming.receive()
    }

    private func waitForReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: ())
                case .failed, .cancelled:
                    continuation.resume(throwing: TransferServiceError.connectionFailed)
                default:
                    break
                }
            }
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func receiveResponse(on connection: NWConnection) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: TransferServiceError.invalidResponse)
                }
            }
        }
    }
}

private final class IncomingTransfer {
    private let connection: NWConnection
    private let onComplete: (URL) -> Void
    private var buffer = Data()
    private var headerParsed = false
    private var expectedBodyLength: Int64 = 0
    private var receivedBodyLength: Int64 = 0
    private var outputURL: URL?
    private var outputHandle: FileHandle?

    init(connection: NWConnection, onComplete: @escaping (URL) -> Void) {
        self.connection = connection
        self.onComplete = onComplete
    }

    func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                self.buffer.append(data)
                self.consumeBuffer()
            }

            if error != nil || isComplete || self.receivedBodyLength >= self.expectedBodyLength && self.headerParsed {
                self.finish()
            } else {
                self.receive()
            }
        }
    }

    private func consumeBuffer() {
        if !headerParsed {
            guard let separator = buffer.range(of: Data("\r\n\r\n".utf8)) else { return }
            let headerData = buffer.subdata(in: 0..<separator.lowerBound)
            let bodyStart = separator.upperBound
            buffer = buffer.subdata(in: bodyStart..<buffer.endIndex)
            parseHeaders(String(decoding: headerData, as: UTF8.self))
            headerParsed = true
        }

        guard headerParsed, let handle = outputHandle, !buffer.isEmpty else { return }
        let remaining = expectedBodyLength - receivedBodyLength
        let count = min(Int64(buffer.count), remaining)
        guard count > 0 else { return }
        let bodyChunk = buffer.prefix(Int(count))
        try? handle.write(contentsOf: Data(bodyChunk))
        receivedBodyLength += count
        buffer.removeFirst(Int(count))
    }

    private func parseHeaders(_ headers: String) {
        let lines = headers.components(separatedBy: "\r\n")
        var fileName = "archivo-recibido"
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            if key == "content-length" {
                expectedBodyLength = Int64(value) ?? 0
            } else if key == "x-file-name-base64", let data = Data(base64Encoded: value), let decoded = String(data: data, encoding: .utf8) {
                fileName = decoded
            }
        }

        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Received", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = uniqueURL(directory.appendingPathComponent(safeName))
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        outputURL = destination
        outputHandle = try? FileHandle(forWritingTo: destination)
    }

    private func finish() {
        try? outputHandle?.close()
        if receivedBodyLength == expectedBodyLength, let outputURL {
            let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
                self?.connection.cancel()
            })
            onComplete(outputURL)
        } else {
            connection.cancel()
        }
    }

    private func uniqueURL(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let suffix = UUID().uuidString.prefix(6)
        let name = ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
        return url.deletingLastPathComponent().appendingPathComponent(name)
    }
}