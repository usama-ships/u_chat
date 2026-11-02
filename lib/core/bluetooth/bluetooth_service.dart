import 'dart:async';
import 'dart:math' as math;

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart'
    show BluetoothLowEnergyState, CentralManager, PeripheralManager;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/repositories/settings_repository.dart';
import '../security/identity_service.dart';
import 'advertisement_codec.dart';
import 'ble_advertiser.dart';
import 'ble_connector.dart';
import 'ble_constants.dart';
import 'ble_gatt_server.dart';
import 'ble_scanner.dart';
import 'link/ble_link.dart';
import 'link/peer_session.dart';
import 'models/ble_availability.dart';
import '../messaging/peer_transport.dart';
import '../security/handshake.dart';
import 'models/discovered_device.dart';
import 'models/incoming_frame.dart';
import 'models/peer_info.dart';
import 'transport/frame.dart';
import 'transport/hello.dart';

export 'ble_connector.dart' show BleConnectException;
export 'models/incoming_frame.dart';

/// App-wide owner of the Bluetooth radio and of all peer connections.
///
/// Responsibilities: availability and permissions, advertising, scanning,
/// connecting (central role), accepting connections (peripheral role, via the
/// GATT server), one session per peer (duplicate links are resolved by a
/// deterministic tie-breaker), keep-alive and automatic reconnection.
///
/// UI controllers read the reactive fields; the messaging layer uses
/// [peerReady], [peerLost], [frames] and [sendFrame].
///
/// Foreground-only by design (MVP): advertising and scanning stop in the
/// background; existing connections are kept while Android allows.
class BluetoothService extends GetxService with WidgetsBindingObserver implements PeerTransport {
  BluetoothService(this._identity, this._settings);

  final IdentityService _identity;
  final SettingsRepository _settings;

  late final CentralManager _central;
  late final PeripheralManager _peripheral;
  late final BleAdvertiser _advertiser;
  late final BleScanner _scanner;
  late final BleGattServer _gattServer;
  late final BleConnector _connector;

  // ---- Reactive state for the UI ----
  final availability = BleAvailability.unknown.obs;
  final advertisingSupported = true.obs;
  final isAdvertising = false.obs;
  final advertisingError = RxnString();
  final isScanning = false.obs;
  final scanError = RxnString();
  final discovered = <DiscoveredDevice>[].obs;
  final permissionDenied = false.obs;

  /// Peers with a ready session, by device ID.
  final connectedPeers = <String, PeerInfo>{}.obs;

  /// Device-ID prefixes we're currently connecting to.
  final connectingPrefixes = <String>{}.obs;

  /// Last measured round-trip time per peer, in milliseconds.
  final peerLatencyMs = <String, int>{}.obs;

  // ---- Streams for the messaging layer ----
  final _peerReadyController = StreamController<PeerInfo>.broadcast();
  final _peerLostController = StreamController<String>.broadcast();
  final _framesController = StreamController<IncomingFrame>.broadcast();

  @override
  Stream<PeerInfo> get peerReady => _peerReadyController.stream;
  @override
  Stream<String> get peerLost => _peerLostController.stream;
  @override
  Stream<IncomingFrame> get frames => _framesController.stream;

  @override
  bool isPeerConnected(String peerId) => _sessionByPeer[peerId]?.isReady ?? false;

  /// Policy for authenticated peers (blocked / unknown devices). Set at startup.
  Future<bool> Function(PeerInfo peer)? admitPeer;

  // ---- Internal ----
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _sessions = <String, PeerSession>{}; // by link id
  final _sessionByPeer = <String, PeerSession>{}; // ready sessions
  final _targets = <String, _ConnectTarget>{}; // peers we want to (re)connect to
  final _waiters = <String, List<Completer<bool>>>{};
  final _userDisconnected = <String>{};
  Timer? _targetTimer;

  String _displayName = '';
  bool _foreground = true;
  bool _scanWanted = false;
  bool _syncingAdvertising = false;
  bool _syncAdvertisingAgain = false;

  String get myId => _identity.deviceId;
  String get _idPrefix => myId.substring(0, BleConstants.advertisedIdLength);

  Future<BluetoothService> init() async {
    _central = CentralManager();
    _peripheral = PeripheralManager();
    _advertiser = BleAdvertiser(_peripheral);
    _scanner = BleScanner(_central, ownDeviceIdPrefix: _idPrefix);
    _gattServer = BleGattServer(_peripheral, onLink: (link) => _startSession(link))..attach();
    _connector = BleConnector(_central)..attach();
    _displayName = await _settings.getDisplayName();

    _subscriptions
      ..add(_central.stateChanged.listen((_) => _onStateChanged()))
      ..add(_peripheral.stateChanged.listen((_) => _onStateChanged()))
      ..add(_scanner.devices.listen((devices) {
        discovered.assignAll(devices);
        _checkTargets(devices);
      }))
      ..add(_settings.watchDisplayName().listen((name) {
        if (name == _displayName) return;
        _displayName = name;
        _syncAdvertising();
        _broadcastProfile(name);
      }));

    WidgetsBinding.instance.addObserver(this);
    _onStateChanged();
    return this;
  }

  // ================================================================ state

  void _onStateChanged() {
    final central = _central.state;
    final peripheral = _peripheral.state;

    availability.value = switch (central) {
      BluetoothLowEnergyState.unknown => BleAvailability.unknown,
      BluetoothLowEnergyState.unsupported => BleAvailability.unsupported,
      BluetoothLowEnergyState.unauthorized => BleAvailability.unauthorized,
      BluetoothLowEnergyState.poweredOff => BleAvailability.poweredOff,
      BluetoothLowEnergyState.poweredOn => peripheral == BluetoothLowEnergyState.unauthorized
          ? BleAvailability.unauthorized
          : BleAvailability.ready,
    };
    advertisingSupported.value = peripheral != BluetoothLowEnergyState.unsupported;
    if (availability.value == BleAvailability.ready) permissionDenied.value = false;

    if (central != BluetoothLowEnergyState.poweredOn) {
      _scanner.markStopped();
      _scanner.clear();
      isScanning.value = false;
      _connector.reset();
      _targets.clear();
    }
    if (peripheral != BluetoothLowEnergyState.poweredOn) {
      _advertiser.markStopped();
      isAdvertising.value = false;
      _gattServer.reset();
    }
    _syncAdvertising();
    _syncScanning();
  }

  Future<bool> requestPermissions() async {
    try {
      final centralGranted = await _central.authorize();
      var peripheralGranted = true;
      if (_peripheral.state != BluetoothLowEnergyState.unsupported) {
        peripheralGranted = await _peripheral.authorize();
      }
      final granted = centralGranted && peripheralGranted;
      permissionDenied.value = !granted;
      return granted;
    } catch (e) {
      debugPrint('requestPermissions failed: $e');
      permissionDenied.value = true;
      return false;
    }
  }

  Future<void> openAppSettings() => _central.showAppSettings();

  // ========================================================== advertising

  Future<void> _syncAdvertising() async {
    if (_syncingAdvertising) {
      _syncAdvertisingAgain = true;
      return;
    }
    _syncingAdvertising = true;
    try {
      do {
        _syncAdvertisingAgain = false;
        final shouldAdvertise = _foreground &&
            availability.value == BleAvailability.ready &&
            _peripheral.state == BluetoothLowEnergyState.poweredOn;
        try {
          if (shouldAdvertise) {
            // Peers connect right after seeing us, so the service must exist first.
            await _gattServer.ensureService();
            await _advertiser.start(
              AdvertisementPayload(deviceIdPrefix: _idPrefix, displayName: _displayName),
            );
          } else {
            await _advertiser.stop();
          }
          advertisingError.value = null;
        } catch (e) {
          debugPrint('Advertising failed: $e');
          _advertiser.markStopped();
          advertisingError.value = BleAdvertiser.describeError(e);
        }
        isAdvertising.value = _advertiser.isAdvertising;
      } while (_syncAdvertisingAgain);
    } finally {
      _syncingAdvertising = false;
    }
  }

  /// Retries advertising if it isn't running (e.g. after an earlier failure).
  Future<void> ensureVisible() => _syncAdvertising();

  // ============================================================= scanning

  Future<void> startScan() async {
    _scanWanted = true;
    scanError.value = null;
    await _syncScanning();
  }

  Future<void> stopScan() async {
    _scanWanted = false;
    await _syncScanning();
  }

  Future<void> _syncScanning() async {
    final shouldScan = (_scanWanted || _targets.isNotEmpty) &&
        _foreground &&
        availability.value == BleAvailability.ready;
    try {
      if (shouldScan && !_scanner.isScanning) {
        await _scanner.start(onTimeout: () {
          _scanWanted = false;
          isScanning.value = false;
          // Restart if reconnect targets still need it.
          _syncScanning();
        });
      } else if (!shouldScan && _scanner.isScanning) {
        await _scanner.stop();
      }
    } catch (e) {
      debugPrint('Scan failed: $e');
      _scanWanted = false;
      scanError.value = 'Scanning failed. Try again in a few seconds.';
    }
    isScanning.value = _scanner.isScanning;
  }

  // ========================================================== connecting

  bool isConnectingTo(String peerId) => connectingPrefixes.contains(peerId.substring(0, 8));

  /// Connects to a discovered device. Completes with the identified peer.
  /// Throws [BleConnectException] with a user-facing message on failure.
  Future<PeerInfo> connect(DiscoveredDevice device) async {
    final prefix = device.deviceIdPrefix;
    final existing = _readyPeerWithPrefix(prefix);
    if (existing != null) return existing;
    if (availability.value != BleAvailability.ready) {
      throw BleConnectException('Bluetooth is not ready');
    }
    if (connectingPrefixes.contains(prefix)) {
      throw BleConnectException('Already connecting to this device');
    }
    if (_sessionByPeer.length >= BleConstants.maxConnections) {
      throw BleConnectException('Too many connections (max ${BleConstants.maxConnections})');
    }

    connectingPrefixes.add(prefix);
    try {
      BleConnectException? lastError;
      // Android's GATT stack fails the first attempt now and then (status 133).
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) await Future<void>.delayed(const Duration(seconds: 1));
        try {
          final link = await _connector.connect(device.peripheral);
          final session = _startSession(link, expectedIdPrefix: prefix);
          try {
            return await session.ready;
          } on StateError catch (e) {
            throw BleConnectException(_describeHandshakeFailure(e.message));
          }
        } on BleConnectException catch (e) {
          lastError = e;
          final peer = _readyPeerWithPrefix(prefix);
          if (peer != null) return peer; // they connected to us meanwhile
        }
      }
      throw lastError!;
    } finally {
      connectingPrefixes.remove(prefix);
    }
  }

  /// Looks for a known peer nearby and connects. Returns false if it isn't
  /// found within [timeout].
  @override
  Future<bool> connectToKnownPeer(
    String peerId, {
    Duration timeout = BleConstants.manualConnectTimeout,
  }) async {
    if (connectedPeers.containsKey(peerId)) return true;
    if (availability.value != BleAvailability.ready) return false;
    _userDisconnected.remove(peerId);
    _addTarget(peerId, timeout);

    final waiter = Completer<bool>();
    _waiters.putIfAbsent(peerId, () => []).add(waiter);
    final timer = Timer(timeout, () {
      if (!waiter.isCompleted) waiter.complete(false);
    });
    _checkTargets(_scanner.currentDevices);
    final result = await waiter.future;
    timer.cancel();
    _waiters[peerId]?.remove(waiter);
    return result;
  }

  /// Disconnects from a peer on purpose. No automatic reconnection follows
  /// until the user connects again.
  Future<void> disconnectPeer(String peerId) async {
    _userDisconnected.add(peerId);
    _targets.remove(peerId);
    await _sessionByPeer[peerId]?.disconnectGracefully();
  }

  /// Sends a frame to a connected peer. Throws if not connected or the
  /// link fails.
  @override
  Future<void> sendFrame(String peerId, Frame frame) {
    final session = _sessionByPeer[peerId];
    if (session == null || !session.isReady) {
      return Future.error(StateError('Peer $peerId is not connected'));
    }
    return session.send(frame);
  }

  static String _describeHandshakeFailure(String reason) {
    if (reason.contains('incompatible')) return reason;
    if (reason == 'identity proof failed' || reason.startsWith('invalid hello')) {
      return 'The other device could not prove its identity. Connection refused for your safety.';
    }
    if (reason == 'peer not allowed') return 'This contact is blocked.';
    if (reason == 'peer said bye') return 'The other phone refused the connection.';
    if (reason == 'handshake timeout') return 'The other phone did not respond in time.';
    return 'Secure connection setup failed ($reason)';
  }

  PeerInfo? _readyPeerWithPrefix(String prefix) {
    for (final peer in connectedPeers.values) {
      if (peer.id.startsWith(prefix)) return peer;
    }
    return null;
  }

  // ============================================================ sessions

  PeerSession _startSession(BleLink link, {String? expectedIdPrefix}) {
    final session = PeerSession(
      link: link,
      identity: LocalIdentity(
        deviceId: myId,
        publicKey: _identity.publicKey.bytes,
        displayName: _displayName,
        sign: (message) async => (await _identity.sign(message)).bytes,
      ),
      expectedIdPrefix: expectedIdPrefix,
      admit: admitPeer,
      onReady: _onSessionReady,
      onFrame: _onSessionFrame,
      onClosed: _onSessionClosed,
      onLatency: (s, ms) => peerLatencyMs[s.peer!.id] = ms,
    );
    _sessions[link.id] = session;
    session.start();
    return session;
  }

  void _onSessionFrame(PeerSession session, Frame frame) {
    final peer = session.peer!;
    if (!identical(_sessionByPeer[peer.id], session)) return; // not the active link
    if (frame.type == FrameType.profile) {
      try {
        final name = ProfileCodec.decode(frame.body);
        connectedPeers[peer.id] = peer.copyWith(displayName: name);
      } on FormatException {
        return;
      }
    }
    _framesController.add(IncomingFrame(connectedPeers[peer.id] ?? peer, frame));
  }

  /// Tells connected peers about a new display name.
  void _broadcastProfile(String name) {
    for (final session in _sessionByPeer.values) {
      session.send(Frame(FrameType.profile, ProfileCodec.encode(name))).catchError((_) {});
    }
  }

  void _onSessionReady(PeerSession session) {
    final peer = session.peer!;
    final existing = _sessionByPeer[peer.id];
    if (existing != null && existing != session && existing.isReady) {
      // Both phones connected to each other at the same time. Both sides keep
      // the same link: the one where the lower device ID is the central.
      final keepNew = _isPreferred(session, over: existing, peerId: peer.id);
      final loser = keepNew ? existing : session;
      loser.closedLocally = true;
      // Only the GATT client of the losing link drops it; the server side just
      // stops using it. That keeps the shared radio connection alive.
      loser.close('duplicate link', disconnect: loser.link.isCentralRole);
      if (!keepNew) return;
    }

    _sessionByPeer[peer.id] = session;
    connectedPeers[peer.id] = peer;
    _targets.remove(peer.id);
    _userDisconnected.remove(peer.id);
    for (final waiter in _waiters.remove(peer.id) ?? const <Completer<bool>>[]) {
      if (!waiter.isCompleted) waiter.complete(true);
    }
    _peerReadyController.add(peer);
  }

  bool _isPreferred(PeerSession a, {required PeerSession over, required String peerId}) {
    String centralIdOf(PeerSession s) => s.link.isCentralRole ? myId : peerId;
    final lowerId = myId.compareTo(peerId) < 0 ? myId : peerId;
    final aPreferred = centralIdOf(a) == lowerId;
    final bPreferred = centralIdOf(over) == lowerId;
    return aPreferred && !bPreferred;
  }

  void _onSessionClosed(PeerSession session) {
    _sessions.remove(session.link.id);
    final peer = session.peer;
    if (peer == null || !identical(_sessionByPeer[peer.id], session)) return;

    _sessionByPeer.remove(peer.id);
    connectedPeers.remove(peer.id);
    peerLatencyMs.remove(peer.id);
    _peerLostController.add(peer.id);

    // Unexpected drop of a link we initiated: try to get it back.
    final unexpected = !session.byeReceived && !session.closedLocally;
    if (unexpected &&
        session.link.isCentralRole &&
        !_userDisconnected.contains(peer.id) &&
        availability.value == BleAvailability.ready) {
      _addTarget(peer.id, BleConstants.reconnectWindow);
    }
  }

  // ======================================================== reconnection

  void _addTarget(String peerId, Duration window) {
    final deadline = DateTime.now().add(window);
    final target = _targets[peerId];
    if (target == null) {
      _targets[peerId] = _ConnectTarget(peerId, deadline);
    } else if (deadline.isAfter(target.deadline)) {
      target.deadline = deadline;
    }
    _targetTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => _onTargetTick());
    _syncScanning();
  }

  void _onTargetTick() {
    final now = DateTime.now();
    _targets.removeWhere((_, t) => now.isAfter(t.deadline));
    if (_targets.isEmpty) {
      _targetTimer?.cancel();
      _targetTimer = null;
      _syncScanning();
      return;
    }
    _checkTargets(_scanner.currentDevices);
  }

  void _checkTargets(List<DiscoveredDevice> devices) {
    if (_targets.isEmpty) return;
    final now = DateTime.now();
    for (final target in _targets.values.toList()) {
      if (now.isBefore(target.nextAttempt) || connectedPeers.containsKey(target.peerId)) continue;
      final prefix = target.peerId.substring(0, BleConstants.advertisedIdLength);
      if (connectingPrefixes.contains(prefix)) continue;
      DiscoveredDevice? device;
      for (final d in devices) {
        if (d.deviceIdPrefix == prefix) device = d;
      }
      if (device == null) continue;
      target.attempts++;
      // Back off 2, 4, 8, 16, 30, 30… seconds between failed attempts.
      target.nextAttempt =
          now.add(Duration(seconds: math.min(30, 1 << math.min(target.attempts, 5))));
      connect(device).then((_) {}, onError: (Object e) {
        debugPrint('Reconnect to ${target.peerId} failed: $e');
      });
    }
  }

  // ============================================================ lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = switch (state) {
      AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached => false,
    };
    if (foreground == _foreground) return;
    _foreground = foreground;
    _syncAdvertising();
    _syncScanning();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subscriptions) {
      s.cancel();
    }
    _targetTimer?.cancel();
    for (final session in _sessions.values.toList()) {
      session.close('service closed', disconnect: true);
    }
    _advertiser.stop();
    _scanner.dispose();
    _gattServer.dispose();
    _connector.dispose();
    _peerReadyController.close();
    _peerLostController.close();
    _framesController.close();
    super.onClose();
  }
}

class _ConnectTarget {
  _ConnectTarget(this.peerId, this.deadline);

  final String peerId;
  DateTime deadline;
  DateTime nextAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  int attempts = 0;
}
