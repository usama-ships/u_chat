# U Chat

Offline, peer-to-peer, end-to-end encrypted chat over Bluetooth Low Energy.
No internet, servers, accounts, or cloud services. Android only for now.

## Features

- Discover nearby U Chat users and connect with one tap
- Text chat with delivery status: Pending → Sending → Sent → Delivered (or Failed, tap to retry)
- Reliable delivery: ACK after the receiver stores the message, retries, duplicate protection, in-order delivery
- Automatic reconnection after unexpected drops; queued messages are sent when a contact reconnects
- End-to-end encryption with a signed handshake, plus safety numbers to verify contacts in person
- Block contacts, or accept connections only from existing contacts
- Chat history stored locally (SQLite / Drift) and kept across restarts

## Build and run

```bash
flutter pub get
dart run build_runner build      # regenerates Drift code after schema changes
flutter test                     # unit and protocol tests (no device needed)
flutter run                      # needs a physical Android phone (emulators have no BLE)
```

Requirements: Android 7.0+ (API 24) with Bluetooth Low Energy. To test chatting
you need two phones. See [docs/TESTING.md](docs/TESTING.md).

## Architecture

```
lib/
  app/            routes, theme, startup dependency wiring (AppDependencies)
  core/
    bluetooth/    radio layer
      bluetooth_service.dart   owns availability, advertising, scanning, sessions, reconnection
      ble_advertiser.dart      manufacturer-data advertising ("UC" + ID prefix + name)
      ble_scanner.dart         filtered, self-expiring discovery list
      ble_gatt_server.dart     peripheral role: GATT service, RX writes, TX notifications
      ble_connector.dart       central role: connect, MTU, service discovery, subscribe
      link/                    BleLink (one GATT connection), PeerSession (protocol state)
      transport/               packet fragmentation, frame format, HELLO/PROFILE codecs
    messaging/    MessagingService (queue, ACKs, retries), message protocol, PeerTransport interface
    security/     identity key, handshake + session cipher, safety numbers, peer policy
    database/     Drift tables and DAOs
  data/           models and repositories
  modules/        home, nearby_devices, chat, contact, settings (GetX binding/controller/view)
```

Dependencies only flow downwards: views → controllers → repositories/services →
Bluetooth. Controllers never touch BLE bytes, and the BLE plugin is only imported
under `core/bluetooth/`.

## Protocol

| Layer | Format |
|---|---|
| Advertisement | Manufacturer data `0xFFFF`: `"UC"`, version, 8-char device-ID prefix, display name (≤ 13 bytes) |
| GATT | Service `b7e3c1a0-…`; RX `…c1a1` (write with response, central → peripheral); TX `…c1a2` (notify, peripheral → central) |
| Packet | 7-byte header (version/flags, transferId, index, total) + chunk; sized to the negotiated MTU |
| Frame | `[type][body]`: `hello`, `auth`, `sealed` in the clear; everything else only inside `sealed` |
| Message | JSON `{v,id,senderId,receiverId,type,content,timestamp,seq}`; ACK `{ids:[…]}` |

### Security

- **Identity:** an Ed25519 key pair created on first launch and stored in Android Keystore-backed secure storage. Device ID = base32(SHA-256(public key)[0..16]), so an ID can't be claimed without its key.
- **Handshake (per connection):** HELLO carries the identity key, a fresh X25519 key and a nonce. Each side then signs the transcript of both HELLOs (AUTH). This proves key possession and binds the ephemeral keys, so a man in the middle can't swap them.
- **Session keys:** HKDF-SHA256 over the X25519 shared secret, salted with the transcript, with one AES-256 key per direction. Fresh keys each connection give forward secrecy.
- **Encryption:** AES-256-GCM. A counter-based nonce, authenticated as AAD, must strictly increase, so replayed, reordered or tampered frames close the connection.
- **Verification:** a 30-digit safety number derived from both identity keys, compared in person.
- **Policy:** blocked contacts are refused after authentication. Unknown devices can optionally be refused.
- **At rest:** app-private storage covered by Android file-based encryption. `allowBackup=false`.

All cryptography comes from the `cryptography` package (native-accelerated via `cryptography_flutter`). Nothing is home-made beyond composing these primitives in the standard signed-DH pattern.

## Known limitations

- **Android only.** iOS was deferred; the architecture allows adding it.
- **Foreground only.** Advertising and scanning pause in the background. Background messaging needs an Android foreground service.
- **1:1 chats, direct range only.** No groups or multi-hop relaying.
- **Unverified first contact is trust-on-first-use.** Compare safety numbers to rule out a man in the middle at first contact.
- **Before publishing:** register a Bluetooth SIG company ID (replace `0xFFFF` in `ble_constants.dart`) and configure release signing (currently the debug key).
- **Android 11 and older:** Location must be switched on for BLE scans to return results.
