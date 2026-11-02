import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import '../ble_constants.dart';

/// One GATT connection to a peer, in either role, moving raw packets.
///
/// - [CentralLink]: this phone is the GATT client. Sends by writing RX, receives
///   TX notifications.
/// - [PeripheralLink]: this phone is the GATT server. Sends by notifying TX,
///   receives RX writes.
///
/// Links don't serialize writes themselves; the owning session does.
abstract class BleLink {
  BleLink(this.id);

  /// Unique per link, e.g. `c:<uuid>` / `p:<uuid>`.
  final String id;

  final _packets = StreamController<Uint8List>();
  final _closed = Completer<void>();
  bool _disposed = false;

  /// True when this phone is the GATT client on this link.
  bool get isCentralRole;

  Stream<Uint8List> get packets => _packets.stream;

  /// Completes when the underlying connection is gone.
  Future<void> get closed => _closed.future;
  bool get isClosed => _closed.isCompleted;

  /// No longer used by any session (closed, or abandoned after a tie-break).
  bool get isDisposed => _disposed;

  Future<int> maxPacketSize();
  Future<void> sendPacket(Uint8List packet);

  /// Tears down the connection in a role-appropriate way.
  Future<void> disconnect();

  /// Called by the router when a packet for this link arrives.
  void deliver(Uint8List packet) {
    if (!_disposed && !_packets.isClosed) _packets.add(packet);
  }

  /// Called by the router when the OS reports the connection lost.
  void markClosed() {
    if (!_closed.isCompleted) _closed.complete();
    dispose();
  }

  /// Stops delivering packets. Does not touch the physical connection.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _packets.close();
  }
}

class CentralLink extends BleLink {
  CentralLink(this._manager, this.peripheral, this._rx, this._tx) : super('c:${peripheral.uuid}');

  final CentralManager _manager;
  final Peripheral peripheral;
  final GATTCharacteristic _rx;
  final GATTCharacteristic _tx;

  @override
  bool get isCentralRole => true;

  GATTCharacteristic get tx => _tx;

  @override
  Future<int> maxPacketSize() => _manager.getMaximumWriteLength(
        peripheral,
        type: GATTCharacteristicWriteType.withResponse,
      );

  @override
  Future<void> sendPacket(Uint8List packet) => _manager.writeCharacteristic(
        peripheral,
        _rx,
        value: packet,
        type: GATTCharacteristicWriteType.withResponse,
      );

  @override
  Future<void> disconnect() async {
    try {
      await _manager.disconnect(peripheral).timeout(BleConstants.gattOperationTimeout);
    } catch (e) {
      debugPrint('CentralLink.disconnect: $e');
    }
    markClosed();
  }
}

class PeripheralLink extends BleLink {
  PeripheralLink(this._manager, this.central, this._tx) : super('p:${central.uuid}');

  final PeripheralManager _manager;
  final Central central;
  final GATTCharacteristic _tx;
  final _subscribed = Completer<void>();

  @override
  bool get isCentralRole => false;

  /// The central enabled TX notifications; we can now send.
  void markSubscribed() {
    if (!_subscribed.isCompleted) _subscribed.complete();
  }

  @override
  Future<int> maxPacketSize() => _manager.getMaximumNotifyLength(central);

  @override
  Future<void> sendPacket(Uint8List packet) async {
    await _subscribed.future.timeout(BleConstants.packetWriteTimeout);
    try {
      await _manager.notifyCharacteristic(central, _tx, value: packet);
    } catch (_) {
      // Android occasionally rejects a notify while the stack is busy; one
      // short retry covers that without masking a real failure.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _manager.notifyCharacteristic(central, _tx, value: packet);
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _manager.disconnect(central);
    } catch (e) {
      debugPrint('PeripheralLink.disconnect: $e');
    }
    markClosed();
  }
}
