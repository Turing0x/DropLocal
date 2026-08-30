# HANDOFF — Nexo

**Transferencia local de ficheros entre iOS, Android, Windows, macOS y Linux.**

Documento de traspaso para Claude Code. Autor del encargo: Raúl García Fernández (ThreeDotsDev).
Fecha: 30 de agosto de 2026.

Este handoff **no arranca un proyecto vacío**. Parte de un código existente que ya funciona parcialmente, y su primera mitad consiste en corregir el rumbo. Lee las secciones 2 y 3 antes de tocar nada.

---

## 1. Qué hay que construir

Una app iOS nativa que envíe y reciba ficheros por la red Wi-Fi local, directamente entre dispositivos, sin nube, sin cuenta, sin límite de tamaño y sin que los datos salgan de la red.

Lo que la hace valiosa no es enviar entre dos iPhones: eso ya lo hace AirDrop. Lo que la hace valiosa es **enviar de un iPhone a un PC con Windows, a un portátil Linux o a un Android, y al revés**. Todo lo demás está subordinado a eso.

## 2. Auditoría de lo que ya existe

He revisado el proyecto completo: 1.093 líneas repartidas en `DropLocalApp.swift`, `Models/TransferModels.swift`, `ViewModels/HomeViewModel.swift`, `Views/RootView.swift` y `Services/LocalTransferService.swift`, más `Info.plist`, `Nexo.entitlements` y el `.xcodeproj`.

### Lo que está bien y se conserva

- El descubrimiento con `NWBrowser` sobre Bonjour funciona y está bien planteado. La estructura de `startListener` con `NWListener.Service` también.
- El envío por streaming en bloques de 64 KB con `FileHandle`, sin cargar el fichero entero en memoria, es correcto y es justo lo que hay que hacer.
- El manejo de recursos con ámbito de seguridad (`startAccessingSecurityScopedResource`) en el envío está bien puesto.
- La estructura de tres pestañas (Enviar / Recibir / Actividad) es la correcta para esta app. Se conserva.
- `TransferModels.swift` está limpio y sirve casi tal cual como base.
- El `Info.plist` con `NSLocalNetworkUsageDescription` y `NSBonjourServices` está bien planteado.

### El problema de fondo: el protocolo es propio

Esta es la corrección más importante del documento y condiciona todas las sprints.

El servicio anunciado es `_locdrop._tcp` y el contrato es un HTTP artesanal con cabeceras inventadas (`X-File-Name-Base64`, `X-Sender-Name`) hacia `POST /v1/transfer`. Funciona, pero **solo habla consigo mismo**. No existe ningún cliente de Nexo para Windows, Android, macOS ni Linux, y construirlos son cuatro proyectos más que no vas a hacer.

Resultado: una app cuya propuesta de valor entera es la interoperabilidad y que ahora mismo no interopera con nada.

**Decisión: se adopta el protocolo de LocalSend.** Es abierto, está documentado, y ya tiene clientes maduros en Windows, macOS, Linux, Android y ChromeOS. En el momento en que Nexo hable ese protocolo, el ecosistema completo aparece de golpe sin escribir una línea de código para otras plataformas. Además el cliente iOS de LocalSend es la parte más floja de ese ecosistema, que es exactamente el hueco que ocupamos: un cliente iOS nativo, pulido y con buen comportamiento en segundo plano.

Esto no es negociable ni se reabre. El protocolo propio se retira por completo.

**Aviso importante sobre la especificación:** no implementes el protocolo de memoria ni a partir de lo que yo escriba aquí. La fuente de verdad es el repositorio oficial de la especificación (`github.com/localsend/protocol`) y el código del cliente de referencia. **Primera tarea de la Sprint 1: leer la especificación vigente y reportarme un resumen de los endpoints, los campos y la versión de protocolo antes de implementar nada.** Lo que apunto en la sección 8 es orientativo y puede estar desactualizado.

### Bugs y agujeros concretos que hay que arreglar

Ordenados por gravedad.

**1. `waitForReady` puede reanudar la continuación dos veces y hace crashear la app.** El `stateUpdateHandler` se invoca en cada cambio de estado. Si la conexión pasa a `.ready` y luego a `.failed` o `.cancelled`, se llama `resume` sobre una continuación ya consumida, y eso es un fallo fatal en Swift, no un warning. Hace falta una bandera de una sola vía, y además limpiar el handler tras reanudar.

**2. No hay cifrado.** Todo viaja en TCP plano, incluidos el nombre del fichero y su contenido. En una red Wi-Fi compartida, un café o un coworking, cualquiera con Wireshark ve el contenido. LocalSend usa HTTPS con certificados autofirmados y verificación por huella; hay que hacer lo mismo.

**3. El receptor no pide permiso.** `accept(_:)` acepta cualquier conexión entrante y `IncomingTransfer` escribe el fichero en `Documents/Received` sin que el usuario se entere. Cualquiera en la misma red puede escribir ficheros en el iPhone de otro. Es un agujero de seguridad, es un problema de revisión en la App Store, y tu propio README ya lo señalaba como pendiente. Hace falta una pantalla de aceptación explícita antes de escribir un solo byte.

**4. La condición de fin de `IncomingTransfer.receive` es frágil.** `error != nil || isComplete || self.receivedBodyLength >= self.expectedBodyLength && self.headerParsed` depende de la precedencia entre `&&` y `||` para leerse correctamente, y `finish()` puede llamarse más de una vez, cerrando un `FileHandle` ya cerrado. Añade paréntesis explícitos y una guarda de finalización única.

**5. No hay tiempos de espera en ninguna parte.** Ni al conectar, ni al recibir la respuesta, ni durante la transferencia. Una conexión que se queda a medias deja la interfaz colgada en "Enviando" para siempre.

**6. No se puede cancelar una transferencia en curso.** Ni desde el emisor ni desde el receptor.

**7. `SelectedFile.size` lee el disco cada vez que se accede**, y se accede desde el cuerpo de las vistas, que SwiftUI reevalúa constantemente. Además lo hace sin abrir el ámbito de seguridad, así que en ficheros de fuera del sandbox puede devolver cero. Hay que calcular el tamaño una sola vez, al añadir el fichero, y guardarlo.

**8. Los colores viven en una extensión privada al final de `RootView.swift`** (`appBackground`, `appSurface`, `appMint`, `appBlue`). Eso se sustituye por el sistema de tokens de Raúl.

**9. `preferredColorScheme(.dark)` está forzado en dos sitios**, en `DropLocalApp` y en `RootView`. La app debe seguir la apariencia del sistema.

**10. La app no maneja el paso a segundo plano.** iOS suspende el proceso, el `NWListener` muere y el dispositivo desaparece de la red sin que la interfaz se entere ni lo explique. Es la queja número uno en las reseñas de este tipo de apps y hay que abordarlo de frente.

### Deuda estructural

- **`RootView.swift` tiene 525 líneas** con las tres pantallas, ocho componentes, un estilo de botón y la paleta de color. Hay que trocearlo.
- **`SWIFT_VERSION = 5.0`.** Se pasa a Swift 6 con concurrencia estricta. Con `NWConnection`, callbacks en colas propias y actualizaciones de interfaz, es donde más se nota la diferencia entre un bug raro y un error de compilación.
- **`ObservableObject` con `@Published`.** Se migra a la macro `@Observable`.
- **`IPHONEOS_DEPLOYMENT_TARGET = 17.0`.** Se sube a iOS 18.
- **El nombre está fragmentado en cuatro variantes**: el repositorio es `DropLocal`, la app se llama `Nexo`, el bundle es `com.nexo.localdrop`, el servicio Bonjour es `_locdrop._tcp` y el `@main` es `DropLocalApp`. Se unifica todo en la Sprint 0.
- **`SUPPORTED_PLATFORMS` incluye macOS** y hay condicionales `#if os(macOS)` repartidos. Ver la decisión en la sección 5.

## 3. Qué NO hay que construir

- **Nada de nube, cuentas ni registro.** Igual que en Nítido, es la propuesta de valor.
- **Nada de relay ni transferencia por internet.** Si los dos dispositivos no están en la misma red local, la app lo dice y no ofrece alternativa.
- **Nada de protocolo propio.** Ver sección 2.
- **Nada de anuncios.**
- **Nada de SDKs de terceros ni dependencias.** Solo frameworks del sistema.
- **Nada de telemetría.** Ni siquiera anónima.
- **Nada de sincronización de carpetas ni de copia de seguridad.** Esta app transfiere; no es Dropbox ni Resilio Sync.
- **Nada de cliente para otras plataformas.** Para eso ya está el ecosistema de LocalSend.

## 4. Realismo comercial

Conviene tenerlo claro antes de invertir meses: **el competidor directo es gratis y de código abierto**. Esta app no va a ser un negocio como el escáner. Es una app de marca y de ecosistema, con una capa Pro modesta.

Consecuencia práctica para el desarrollo: la versión gratuita tiene que ser completamente usable, sin límites en lo esencial. Lo de pago son comodidades. Si en algún momento una decisión de producto empuja hacia mutilar la función principal para forzar la compra, es la decisión equivocada. Detalles en la sección 12.

## 5. Stack y decisiones cerradas

- **Swift 6 con concurrencia estricta**, SwiftUI, nativo.
- **Deployment target iOS 18.**
- **Solo iOS en la v1.** Se retira macOS de `SUPPORTED_PLATFORMS` y se eliminan todos los condicionales `#if os(macOS)`. Motivo: LocalSend ya tiene cliente de escritorio maduro para las tres plataformas, así que un target macOS propio duplicaría trabajo sin aportar nada al usuario. Los condicionales sobran y ensucian.
- **Protocolo LocalSend**, en la versión vigente de la especificación.
- **Cero dependencias externas.** Solo `Network`, `SwiftUI`, `SwiftData`, `CryptoKit`, `Security`, `PhotosUI`, `UniformTypeIdentifiers`, `StoreKit`, `AppIntents`.
- **`Network.framework` para todo lo de red.** Nada de `URLSession` para el transporte entre pares, nada de librerías de servidor HTTP.
- **SwiftData** para el historial de transferencias y los dispositivos favoritos.
- **Arquitectura**: vistas SwiftUI, stores `@Observable` por área, y una capa de red sin estado de interfaz. Ningún fichero de red importa SwiftUI.
- **Nombre unificado: Nexo.** Bundle `com.threedotsdev.nexo`. El `@main` pasa a llamarse `NexoApp`. El nombre de la carpeta del repositorio da igual.
- **`DesignTokens.swift`** lo aporta Raúl, igual que en Nítido. No inventes valores de color, tipografía, espaciado, radio ni sombra. Si el fichero no está, para y pídelo.

## 6. Configuración del proyecto

### Info.plist

Se conservan `NSLocalNetworkUsageDescription` y `NSBonjourServices`, pero el tipo de servicio cambia al que indique la especificación de LocalSend. También hará falta `NSPhotoLibraryAddUsageDescription` cuando se implemente guardar en Fotos.

### Entitlements

El fichero actual `Nexo.entitlements` contiene claves de sandbox de macOS (`com.apple.security.app-sandbox`, `com.apple.security.network.client`, `com.apple.security.network.server`, `com.apple.security.files.user-selected.read-write`). **En iOS no hacen nada.** Al retirar el target de macOS, revisa qué queda y déjalo limpio; no arrastres claves que no aplican.

### El asunto del multicast

Presta atención aquí porque puede costar días. LocalSend descubre pares por multicast UDP, y **en iOS el multicast requiere el entitlement `com.apple.developer.networking.multicast`, que Apple concede solo previa solicitud justificada**, con un formulario y una espera.

La estrategia para no depender de eso:

1. **Descubrimiento por mDNS/Bonjour con `NWBrowser`**, que no requiere entitlement especial y que ya tienes implementado y funcionando. La especificación de LocalSend contempla mDNS, así que hay que confirmar en la Sprint 1 que los clientes de escritorio también anuncian por esa vía.
2. **Registro HTTP directo** como respaldo: si un par no aparece por mDNS, permitir añadirlo escribiendo su IP, o escaneando un código QR que muestre el otro dispositivo.
3. Solicitar el entitlement de multicast en paralelo, sin bloquear el desarrollo. Si llega, se añade como tercera vía de descubrimiento.

**Reporta en la Sprint 1 si el descubrimiento mDNS funciona de verdad contra un cliente de escritorio real.** Si no funciona, el proyecto necesita replantearse y quiero saberlo antes de la Sprint 2, no en la 5.

## 7. Estructura de ficheros objetivo

```
Nexo/
├── NexoApp.swift
├── DesignTokens.swift              // lo aporta Raúl. No editar.
├── Models/
│   ├── Device.swift                // sustituye a DiscoveredDevice
│   ├── TransferSession.swift
│   ├── TransferItem.swift
│   ├── TransferState.swift
│   └── Formatting.swift            // fileSizeLabel y similares
├── Network/
│   ├── ProtocolSpec.swift          // constantes, versión, rutas
│   ├── DTOs.swift                  // Codable del protocolo
│   ├── Discovery.swift             // NWBrowser + anuncio mDNS
│   ├── HTTPServer.swift            // NWListener, enrutado, TLS
│   ├── HTTPClient.swift            // peticiones salientes
│   ├── TLSIdentity.swift           // certificado autofirmado y huella
│   ├── Sender.swift
│   └── Receiver.swift
├── Storage/
│   ├── ReceivedFileStore.swift
│   ├── TransferHistory.swift       // @Model SwiftData
│   └── KnownDevice.swift           // @Model, favoritos y auto-aceptar
├── Stores/
│   ├── DiscoveryStore.swift
│   ├── SendStore.swift             // sustituye a HomeViewModel
│   └── ReceiveStore.swift
├── Purchases/
│   └── StoreManager.swift
└── Views/
    ├── Send/
    ├── Receive/
    ├── Activity/
    ├── Consent/
    ├── Settings/
    └── Components/
```

Regla: las vistas conocen los stores, los stores conocen la capa de red, la capa de red no conoce a nadie. Si un fichero de `Network/` acaba importando SwiftUI, algo se ha torcido.

## 8. Notas orientativas sobre el protocolo

Repito el aviso: **verifica todo esto contra la especificación oficial antes de implementarlo.** Lo escribo solo para que sepas la forma general de lo que vas a encontrar.

El modelo es el de un servidor HTTP en cada dispositivo, escuchando en un puerto conocido, con TLS mediante certificado autofirmado. Los dispositivos se identifican por una huella derivada de su certificado, y se anuncian con un alias visible, el modelo de dispositivo y su tipo.

El flujo de envío tiene tres fases: el emisor pregunta al receptor por sus datos, le propone una tanda de ficheros con sus metadatos, y el receptor responde aceptando o rechazando; si acepta, devuelve un identificador de sesión y un token por fichero, y solo entonces el emisor sube cada fichero. Hay también una llamada de cancelación.

Lo que importa de ese diseño para nosotros: **la aceptación del receptor es parte del protocolo, no un añadido nuestro**. Eso resuelve el agujero número 3 de la auditoría de forma natural.

Puntos donde hay que ser especialmente cuidadoso:

- **Los identificadores de fichero del protocolo no son nombres de fichero.** No los uses para construir rutas.
- **Sanea siempre el nombre de fichero recibido.** El código actual usa `lastPathComponent`, que ya evita lo peor, pero conviene además rechazar nombres vacíos, nombres que empiecen por punto y nombres con caracteres de control.
- **Valida el tamaño anunciado contra el recibido** y descarta el fichero si no cuadra.
- **Impón un límite de conexiones concurrentes** para que un par malicioso no pueda abrir cientos de conexiones.

## 9. Sprints

Cada sprint termina con algo instalable y un resumen corto. No avances sin enseñar resultado.

---

### Sprint 0 — Saneamiento

Sin funcionalidad nueva. El objetivo es dejar el terreno firme.

Unificar el nombre a Nexo en todas partes: `@main`, bundle, esquema, display name. Retirar el target de macOS y todos los condicionales `#if os(macOS)`. Subir a Swift 6 con concurrencia estricta y a iOS 18, y arreglar todo lo que eso rompa. Migrar `ObservableObject` a `@Observable`.

Trocear `RootView.swift` según la estructura de la sección 7, moviendo cada componente a su fichero. Integrar `DesignTokens.swift` y eliminar la extensión privada de `Color`. Quitar los dos `preferredColorScheme(.dark)`.

Arreglar los bugs 1, 4 y 7 de la auditoría: la doble reanudación de la continuación, la condición de fin de recepción con su guarda de finalización única, y el cálculo del tamaño de fichero, que pasa a hacerse una sola vez al añadirlo, dentro del ámbito de seguridad.

En este punto la app sigue usando el protocolo viejo. No lo toques todavía.

**Criterio de aceptación:** compila con concurrencia estricta sin warnings, sigue enviando entre dos iPhones igual que antes, ningún fichero pasa de 250 líneas, y no queda un solo valor de color escrito a mano fuera de los tokens.

---

### Sprint 1 — Protocolo: lectura, descubrimiento y presentación

Primero, leer la especificación oficial de LocalSend y **reportarme un resumen** antes de escribir código: versión vigente, endpoints, campos obligatorios, cómo se hace el descubrimiento y cómo se gestionan los certificados.

Después: generar y persistir en el llavero un certificado autofirmado con su clave, calcular la huella, y montar el `NWListener` con TLS. `TLSIdentity.swift` se encarga de todo eso.

Adaptar el descubrimiento existente al tipo de servicio y a los datos anunciados que exija la especificación, conservando la base de `NWBrowser` que ya funciona. Implementar el endpoint informativo del protocolo y el registro entre pares.

Añadir la vía de respaldo: añadir un dispositivo manualmente por IP.

**Criterio de aceptación:** el iPhone aparece en la lista de dispositivos de un cliente de escritorio de LocalSend corriendo en el ordenador de Raúl, y ese ordenador aparece en la lista del iPhone. Sin esto no se sigue.

---

### Sprint 2 — Recepción con consentimiento

Implementar la fase de propuesta del protocolo: cuando llega una petición de envío, la app muestra quién envía, cuántos ficheros, qué son y cuánto pesan, y el usuario acepta o rechaza. Nada se escribe en disco antes de aceptar.

Presentación de la pantalla de aceptación por encima de lo que haya, y notificación local si la app está en segundo plano.

Recepción real de los ficheros con validación de nombre y tamaño, escritura por streaming a disco, progreso por fichero y por tanda, y cancelación desde el receptor.

Destino: un directorio propio dentro del contenedor, expuesto en la app Archivos declarando la app como proveedora de documentos, para que el usuario pueda sacar sus ficheros sin depender de Nexo.

Retirar el manejador antiguo `IncomingTransfer` y todo el HTTP artesanal.

**Criterio de aceptación:** desde un PC con Windows se envían tres ficheros al iPhone, el iPhone pregunta, Raúl acepta, los tres llegan íntegros y se abren correctamente; en un segundo intento Raúl rechaza y el PC lo refleja.

---

### Sprint 3 — Envío

Reescribir el emisor contra el protocolo nuevo: proponer la tanda, esperar la respuesta, subir los ficheros con los tokens obtenidos, informar del progreso real y permitir cancelar.

Selección de contenido desde tres fuentes: el selector de ficheros que ya existe, `PhotosPicker` para fotos y vídeos, y texto o enlaces desde el portapapeles.

Tiempos de espera en todas las operaciones de red, con mensajes de error que digan qué ha pasado en lugar de un genérico.

**Criterio de aceptación:** se envía un vídeo de más de un giga desde el iPhone a un portátil Linux, se ve el progreso avanzar de forma realista, se cancela a mitad y el receptor no se queda con un fichero corrupto.

---

### Sprint 4 — Comportamiento en segundo plano y robustez

La parte que decide si la gente deja la app instalada.

Gestionar de forma explícita el ciclo de vida: cuando la app pasa a segundo plano, iOS acaba suspendiendo el proceso y el dispositivo deja de ser visible. En lugar de fingir que no pasa, la interfaz lo dice con claridad: mientras la pantalla de recepción está abierta, se muestra el estado visible; al salir, se explica que hay que volver a abrir la app para recibir.

Usar `beginBackgroundTask` para no cortar en seco una transferencia en curso cuando el usuario cambia de app, y reanudar el descubrimiento y el anuncio al volver a primer plano.

Manejar los casos reales que rompen las cosas: cambio de red Wi-Fi a mitad de transferencia, pérdida de conexión, disco lleno, permiso de red local denegado (con instrucciones para concederlo en Ajustes), y el caso de estar en una red con aislamiento de clientes, donde el descubrimiento simplemente no puede funcionar y hay que explicarlo.

Historial de transferencias persistido con SwiftData, sustituyendo el array en memoria actual.

**Criterio de aceptación:** una transferencia grande sobrevive a que el usuario cambie de app unos segundos; con el permiso de red local denegado la app explica exactamente qué hacer; ninguno de los casos anteriores deja la interfaz colgada.

---

### Sprint 5 — Integración con el sistema

Share Extension para enviar desde cualquier app con el botón de compartir. Es la vía por la que la gente va a usar la app la mayor parte del tiempo, y es más importante que la pantalla de envío.

Guardar en Fotos las imágenes y vídeos recibidos, con la opción de hacerlo automáticamente.

App Intents para Atajos.

Código QR: mostrar uno con los datos de conexión del dispositivo y poder escanear el de otro, como forma de emparejar sin depender del descubrimiento automático.

**Criterio de aceptación:** desde Fotos se comparte una selección a Nexo y llega al ordenador sin abrir la app manualmente.

---

### Sprint 6 — Ajustes, seguridad y confianza

Ajustes: alias del dispositivo, carpeta de destino, guardar automáticamente en Fotos, y gestión de dispositivos conocidos.

Dispositivos de confianza: recordar un dispositivo por su huella y permitir aceptar sus envíos automáticamente. Si la huella de un dispositivo conocido cambia, avisar de forma destacada, porque eso significa o una reinstalación o una suplantación.

PIN opcional para exigir un código antes de aceptar transferencias.

Repaso de seguridad completo: sanitización de nombres, validación de tamaños, límite de conexiones concurrentes, y verificación de que nada se escribe fuera del directorio previsto.

Accesibilidad: VoiceOver en todos los controles, Dynamic Type hasta tamaños de accesibilidad, y anuncio del progreso de transferencia para quien no ve la barra.

**Criterio de aceptación:** un dispositivo marcado como de confianza envía sin preguntar; al cambiar su huella la app avisa; la app entera se navega con VoiceOver.

---

### Sprint 7 — Monetización y salida a tienda

StoreKit 2 con los productos de la sección 12, un único punto de comprobación de derechos, paywall honesto con precio visible y restaurar compras, y fichero `.storekit` para pruebas.

Localización completa en español e inglés. Privacy manifest con la ficha en *Data Not Collected*. Icono, capturas, texto de ficha.

En la descripción de la App Store, mencionar explícitamente la compatibilidad con LocalSend: es un argumento de venta y además es honesto respecto a de dónde viene el protocolo. Revisa las condiciones de la licencia del proyecto para citarlo correctamente y para saber qué se puede y qué no se puede afirmar sobre la compatibilidad.

**Criterio de aceptación:** build en TestFlight, instalado en dos dispositivos, transferencias contra Windows y Android sin incidencias.

## 10. Trampas técnicas conocidas

**El simulador miente en todo lo que toca red local.** El descubrimiento entre simulador y dispositivo físico funciona a veces y falla otras. Todas las pruebas de red se hacen entre dispositivos reales.

**El permiso de red local se pide una sola vez.** Si el usuario lo deniega, no vuelve a preguntarse y la app queda inútil sin explicación. Detecta la situación y lleva al usuario a Ajustes.

**Las continuaciones de Swift y los callbacks de `Network` no se llevan bien.** Cada `withCheckedThrowingContinuation` alrededor de un handler que puede dispararse varias veces necesita protección contra la doble reanudación. Ya hay un caso en el código; revisa que no aparezcan más.

**Concurrencia estricta con `NWConnection`.** Los handlers llegan en colas propias, no en el actor principal. Cruza al actor principal solo para actualizar estado de interfaz, y no pases tipos no `Sendable` entre fronteras.

**No cargues ficheros en memoria.** El código actual ya hace streaming en el envío; mantenlo también en la recepción y en cualquier cálculo de hash.

**El progreso tiene que ser honesto.** No lo interpoles ni lo animes por encima de lo real. Un progreso que salta a 99% y se queda ahí es peor que uno lento.

**Vigila el ámbito de seguridad de los ficheros importados.** Ábrelo antes de leer y ciérralo después, incluso para consultar atributos.

**Redes con aislamiento de clientes.** Muchas Wi-Fi de hoteles y aeropuertos impiden que dos dispositivos se vean entre sí. Ninguna app puede sortearlo. Detéctalo y explícalo en lugar de dejar la lista de dispositivos vacía sin motivo aparente.

## 11. Nota sobre la nomenclatura del historial

`TransferRecord` implementa `==` comparando solo algunos campos, lo cual funciona pero es frágil si alguien añade un campo y espera que cuente. Al migrar el historial a SwiftData, este tipo desaparece o se reduce a un modelo con identidad propia. No arrastres la comparación parcial.

## 12. Monetización

Identificadores:

- `com.threedotsdev.nexo.pro` — compra única, 6,99 €.

Un solo producto, sin suscripción. Para una utilidad que compite contra una alternativa gratuita, una suscripción sería difícil de justificar y fácil de resentir.

**Gratis, y esto es la app entera funcionando:**

- Enviar y recibir sin límite de tamaño, de cantidad ni de velocidad.
- Todas las fuentes de contenido y la Share Extension.
- Historial de transferencias.
- Descubrimiento automático y manual.

**Pro:**

- Dispositivos de confianza con aceptación automática.
- Envío a varios dispositivos a la vez.
- Guardado automático en Fotos y elección de carpeta de destino por tipo de fichero.
- Atajos y automatizaciones.
- Personalización del alias y del icono de la app.

Ninguna de esas cosas es necesaria para transferir un fichero. Esa es la prueba de que el reparto está bien hecho.

## 13. Cómo quiere Raúl que trabajes

- **No avances de sprint sin enseñar resultado.** Cada una acaba con algo instalable y un resumen de qué salió y qué quedó pendiente.
- **La Sprint 1 tiene una puerta de decisión.** Si el descubrimiento mDNS no funciona contra clientes de escritorio reales, para y dilo. No sigas construyendo sobre una base que no interopera.
- **No inventes diseño.** Los valores vienen del fichero de tokens.
- **Comentarios en castellano** en la capa de red y en el parseo del protocolo.
- **Si algo no responde como esperabas, dilo.** Vale más "el cliente de Windows no me ve por mDNS y no sé por qué" que un descubrimiento que solo funciona entre iPhones y que aparenta que todo va bien.
- **Prueba entre dispositivos reales y contra al menos dos plataformas distintas** antes de dar por buena cualquier sprint que toque red.

## 14. Referencias

- [Especificación del protocolo LocalSend](https://github.com/localsend/protocol) — fuente de verdad, léela antes de implementar.
- [Cliente de referencia de LocalSend](https://github.com/localsend/localsend)
- [Network framework](https://developer.apple.com/documentation/network)
- [NWBrowser](https://developer.apple.com/documentation/network/nwbrowser)
- [NWListener](https://developer.apple.com/documentation/network/nwlistener)
- [Multicast entitlement](https://developer.apple.com/contact/request/networking-multicast)
- [Local network privacy](https://developer.apple.com/news/?id=0oi77447)
- [StoreKit 2](https://developer.apple.com/documentation/storekit/in-app-purchase)
