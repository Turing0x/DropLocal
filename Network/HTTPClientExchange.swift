import Foundation
import Network

// Ejecuta un intercambio HTTP completo sobre una `NWConnection`: conectar,
// enviar la petición y leer la respuesta hasta que el par cierra.
//
// Está en su propio fichero porque concentra toda la parte delicada: los
// callbacks de `Network` llegan en colas ajenas y pueden dispararse varias
// veces, así que la continuación necesita protección contra la doble
// reanudación (trampa conocida de la sección 10 del handoff — es exactamente
// el bug 1 de la auditoría, y aquí no se vuelve a cometer).
final class HTTPClientExchange: @unchecked Sendable {
    private let connection: NWConnection
    private let request: Data
    private let timeout: TimeInterval
    private let queue = DispatchQueue(label: "com.threedotsdev.nexo.httpclient")

    private let lock = NSLock()
    private var finished = false
    private var buffer = Data()
    private var continuation: CheckedContinuation<Data, Error>?
    private var timeoutItem: DispatchWorkItem?

    init(connection: NWConnection, request: Data, timeout: TimeInterval) {
        self.connection = connection
        self.request = request
        self.timeout = timeout
    }

    func run() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            // Reloj propio: `NWConnection` no tiene un tiempo de espera
            // global, solo el de establecimiento de TCP. Sin esto un par que
            // acepta la conexión y no contesta nunca colgaría el escaneo.
            let item = DispatchWorkItem { [weak self] in
                self?.complete(.failure(HTTPClient.ClientError.timedOut))
            }
            timeoutItem = item
            queue.asyncAfter(deadline: .now() + timeout, execute: item)

            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.send()
                case .failed(let error):
                    self.complete(.failure(HTTPClient.ClientError.connectionFailed("\(error)")))
                case .cancelled:
                    self.complete(.failure(HTTPClient.ClientError.connectionFailed("cancelada")))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private func send() {
        connection.send(content: request, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                self.complete(.failure(HTTPClient.ClientError.connectionFailed("\(error)")))
                return
            }
            self.receive()
        })
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.lock.lock()
                self.buffer.append(data)
                self.lock.unlock()
            }

            if let error {
                self.complete(.failure(HTTPClient.ClientError.connectionFailed("\(error)")))
                return
            }

            // Respondemos con `Connection: close`, así que el fin de la
            // respuesta es el cierre del par. Suficiente para los cuerpos
            // JSON pequeños de esta sprint; la subida por streaming de la
            // Sprint 3 usará su propio lector con Content-Length.
            if isComplete {
                self.lock.lock()
                let received = self.buffer
                self.lock.unlock()
                self.complete(.success(received))
                return
            }

            self.receive()
        }
    }

    // Único punto de salida. La bandera bajo cerrojo garantiza que la
    // continuación se reanuda exactamente una vez, pase lo que pase con los
    // handlers.
    private func complete(_ result: Result<Data, Error>) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let pending = continuation
        continuation = nil
        let timer = timeoutItem
        timeoutItem = nil
        lock.unlock()

        timer?.cancel()
        connection.stateUpdateHandler = nil
        connection.cancel()
        pending?.resume(with: result)
    }
}
