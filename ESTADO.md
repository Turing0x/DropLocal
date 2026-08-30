# ESTADO — Nexo

Progreso frente al `HANDOFF.md`. Se actualiza al cerrar cada sprint.

Última actualización: 2026-08-30.

---

## Sprint 0 — Saneamiento ✅ COMPLETO

Commit: `01a1162` (pusheado a `main`).

**Hecho:**

- Nombre unificado a Nexo: `@main NexoApp` (`NexoApp.swift`, sustituye a `DropLocalApp.swift`, borrado), bundle `com.threedotsdev.nexo`, `CFBundleDisplayName` = Nexo.
- Target macOS retirado: `SUPPORTED_PLATFORMS` solo `iphoneos iphonesimulator`, cero `#if os(macOS)` / `canImport(AppKit)` en el código.
- `SWIFT_VERSION = 6.0` e `IPHONEOS_DEPLOYMENT_TARGET = 18.0` en las 4 configuraciones del `.pbxproj`. Compila limpio con `xcodebuild` (sin errores ni warnings).
- `ObservableObject`/`@Published` migrado a `@Observable` en `HomeViewModel` y `LocalTransferService`.
- `RootView.swift`: de 525 a 45 líneas. Troceado en `Views/Send/` (`SendView`, `DeviceCard`, `DevicePickerView`, `FileDropZone`, `FileQueueView`), `Views/Receive/ReceiveView.swift`, `Views/Activity/` (`ActivityView`, `TransferProgressRow`), `Views/Components/` (`EmptyStateView`, `HeaderView`, `PrimaryButtonStyle`, `TabButton`). Ningún fichero pasa de 250 líneas (el más largo es `LocalTransferService.swift`, 238).
- `DesignTokens.swift` integrado (`TDDColor`, `TDDSpacing`); extensión privada de `Color` en `RootView` eliminada.
- Ambos `preferredColorScheme(.dark)` (en `DropLocalApp` y `RootView`) eliminados.
- `Nexo.entitlements` limpiado: fuera las claves de sandbox macOS (`app-sandbox`, `network.client/server`, `files.user-selected.read-write`), dict vacío.
- Bug #1 (doble reanudación de continuación en `waitForReady`): arreglado con `OneShotFlag` (lock + bandera de una sola vía), handler se limpia tras resolver.
- Bug #4 (condición de fin de `IncomingTransfer.receive` frágil): paréntesis explícitos en la condición + guarda `finished` en `finish()` para que no cierre el `FileHandle` dos veces.
- Bug #7 (`SelectedFile.size` releía disco en cada evaluación del body): calculado una sola vez en `init`, dentro del ámbito de seguridad (`startAccessingSecurityScopedResource`).
- Limpieza de raíz: borrados `droplocal.zip` y `files.zip` (sueltos, no trackeados, no pertenecían a la estructura del proyecto).

**Explícitamente no tocado (correcto para esta sprint):**

- Protocolo sigue siendo el artesanal `_locdrop._tcp` / `POST /v1/transfer`. Se sustituye en la Sprint 1.
- `Info.plist` conserva `_locdrop._tcp` en `NSBonjourServices`.
- Bugs #2 (sin cifrado), #3 (receptor sin consentimiento), #5 (sin timeouts), #6 (sin cancelación) quedan pendientes — se resuelven en Sprints 1-3 como parte natural del protocolo LocalSend, no en Sprint 0.

**Criterios de aceptación de la sprint:** cumplidos los cuatro (compila con concurrencia estricta sin warnings, sigue enviando entre dos iPhones con el protocolo viejo intacto, ningún fichero >250 líneas, cero colores a mano fuera de tokens).

---

## Sprint 1 — Protocolo: lectura, descubrimiento y presentación

Estado: **no iniciada.**

Pendiente: leer especificación oficial de LocalSend (`github.com/localsend/protocol`) y reportar resumen antes de escribir código. Puerta de decisión: si mDNS no interopera con cliente de escritorio real, parar y avisar antes de Sprint 2.

---

## Sprints 2-7

Estado: **no iniciadas.** Ver `HANDOFF.md` sección 9 para alcance y criterios de aceptación de cada una.

---

## Notas abiertas / riesgos a vigilar

- No se ha probado aún el entitlement de multicast ni se ha solicitado — pendiente de Sprint 1, en paralelo, sin bloquear.
- El nombre de la carpeta del repo sigue siendo `DropLocal`; el handoff dice explícitamente que no importa.
