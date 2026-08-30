# Nexo — transferencia local para iOS

Nexo es el primer cliente SwiftUI de una herramienta de transferencia directa entre dispositivos. Descubre pares en la red local con Bonjour y envía archivos por una conexión TCP local, sin cuenta, nube ni límite de tamaño impuesto por la app.

## Abrir en Xcode

1. Crea un proyecto nuevo de tipo **iOS > App** en Xcode.
2. Usa `Nexo` como nombre, `SwiftUI` como interfaz y `Swift` como lenguaje.
3. Arrastra las carpetas `Models`, `Services`, `ViewModels` y `Views`, además de `DropLocalApp.swift`, al target del proyecto.
4. Sustituye el `Info.plist` generado por el de esta carpeta o copia sus claves `NSLocalNetworkUsageDescription` y `NSBonjourServices`.
5. Ejecuta en dos dispositivos conectados a la misma red Wi-Fi. Un simulador no siempre permite validar Bonjour entre equipos.

## Alcance actual

- Descubrimiento real de dispositivos Nexo mediante `_locdrop._tcp`.
- Selección múltiple de archivos usando el selector nativo de iOS.
- Transferencia TCP local por streaming en bloques de 64 KB.
- Recepción automática en `Documents/Received`.
- Historial de transferencias y estados de progreso.

El tipo de servicio es propio para que el MVP sea seguro y controlable. El siguiente paso es sustituir o ampliar el contrato HTTP con el protocolo compatible con LocalSend, añadir confirmación antes de aceptar un archivo y completar los clientes Android, Windows, macOS y Linux.