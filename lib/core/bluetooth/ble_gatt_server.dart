import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'ble_constants.dart';
import 'link/ble_link.dart';

/// Hosts the U Chat GATT service (peripheral role) and turns remote centrals
/// into [PeripheralLink]s.
///
/// A link is created when a central subscribes to TX or writes to RX, NOT
/// when it connects: Android also reports this phone's own outgoing (central)
/// connections to the GATT server, and those must not become links.
class BleGattServer {
  BleGattServer(this._manager, {required this.onLink});

  final PeripheralManager _manager;
  final void Function(PeripheralLink link) onLink;

  late final GATTCharacteristic _rx = GATTCharacteristic.mutable(
    uuid: BleConstants.rxUuid,
    properties: [GATTCharacteristicProperty.write],
    permissions: [GATTCharacteristicPermission.write],
    descriptors: [],
  );
  late final GATTCharacteristic _tx = GATTCharacteristic.mutable(
    uuid: BleConstants.txUuid,
    properties: [GATTCharacteristicProperty.notify],
    permissions: [GATTCharacteristicPermission.read],
    descriptors: [],
  );
  late final GATTService _service = GATTService(
    uuid: BleConstants.serviceUuid,
    isPrimary: true,
    includedServices: [],
    characteristics: [_rx, _tx],
  );

  final _links = <UUID, PeripheralLink>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _serviceAdded = false;
  Future<void>? _adding;

  void attach() {
    _subscriptions
      ..add(_manager.characteristicWriteRequested.listen(_onWrite))
      ..add(_manager.characteristicNotifyStateChanged.listen(_onNotifyState))
      ..add(_manager.connectionStateChanged.listen(_onConnectionState));
  }

  /// Publishes the service if it isn't yet. Call when the peripheral manager
  /// is powered on (the plugin recreates the GATT server on every power-on).
  Future<void> ensureService() {
    if (_serviceAdded) return Future.value();
    return _adding ??= () async {
      try {
        try {
          await _manager.removeAllServices();
        } catch (_) {}
        await _manager.addService(_service);
        _serviceAdded = true;
      } finally {
        _adding = null;
      }
    }();
  }

  /// Bluetooth went off: the OS dropped the server and all connections.
  void reset() {
    _serviceAdded = false;
    for (final link in _links.values.toList()) {
      link.markClosed();
    }
    _links.clear();
  }

  PeripheralLink _linkFor(Central central) {
    final existing = _links[central.uuid];
    if (existing != null && !existing.isDisposed) return existing;
    final link = PeripheralLink(_manager, central, _tx);
    _links[central.uuid] = link;
    link.closed.then((_) {
      if (identical(_links[central.uuid], link)) _links.remove(central.uuid);
    });
    onLink(link);
    return link;
  }

  Future<void> _onWrite(GATTCharacteristicWriteRequestedEventArgs event) async {
    if (event.characteristic.uuid != BleConstants.rxUuid) {
      try {
        await _manager.respondWriteRequestWithError(
          event.request,
          error: GATTError.writeNotPermitted,
        );
      } catch (_) {}
      return;
    }
    final link = _linkFor(event.central);
    try {
      await _manager.respondWriteRequest(event.request);
    } catch (e) {
      debugPrint('respondWriteRequest failed: $e');
    }
    link.deliver(event.request.value);
  }

  void _onNotifyState(GATTCharacteristicNotifyStateChangedEventArgs event) {
    if (event.characteristic.uuid != BleConstants.txUuid) return;
    if (event.state) {
      _linkFor(event.central).markSubscribed();
    } else {
      _links.remove(event.central.uuid)?.markClosed();
    }
  }

  void _onConnectionState(CentralConnectionStateChangedEventArgs event) {
    if (event.state == ConnectionState.disconnected) {
      _links.remove(event.central.uuid)?.markClosed();
    }
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    reset();
  }
}
