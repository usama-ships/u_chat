import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'ble_constants.dart';
import 'link/ble_link.dart';

class BleConnectException implements Exception {
  BleConnectException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Connects to remote GATT servers (central role) and routes their
/// notifications and disconnections to the right [CentralLink].
class BleConnector {
  BleConnector(this._manager);

  final CentralManager _manager;
  final _links = <UUID, CentralLink>{};
  final _subscriptions = <StreamSubscription<Object?>>[];

  void attach() {
    _subscriptions
      ..add(_manager.characteristicNotified.listen((event) {
        if (event.characteristic.uuid != BleConstants.txUuid) return;
        _links[event.peripheral.uuid]?.deliver(event.value);
      }))
      ..add(_manager.connectionStateChanged.listen((event) {
        if (event.state == ConnectionState.disconnected) {
          _links.remove(event.peripheral.uuid)?.markClosed();
        }
      }));
  }

  /// Connects, negotiates MTU, finds the U Chat service and subscribes to TX.
  Future<CentralLink> connect(Peripheral peripheral) async {
    final existing = _links[peripheral.uuid];
    if (existing != null && !existing.isDisposed) {
      throw BleConnectException('Already connected to this device');
    }
    try {
      await _manager.connect(peripheral).timeout(BleConstants.connectTimeout);
    } on TimeoutException {
      await _safeDisconnect(peripheral);
      throw BleConnectException('Connection timed out');
    } catch (e) {
      throw BleConnectException('Could not connect ($e)');
    }

    try {
      try {
        await _manager
            .requestMTU(peripheral, mtu: BleConstants.requestedMtu)
            .timeout(BleConstants.gattOperationTimeout);
      } catch (e) {
        // Not fatal: fragmentation works with the default 23-byte MTU.
        debugPrint('requestMTU failed: $e');
      }

      final services =
          await _manager.discoverGATT(peripheral).timeout(BleConstants.gattOperationTimeout);
      GATTCharacteristic? rx;
      GATTCharacteristic? tx;
      for (final service in services) {
        if (service.uuid != BleConstants.serviceUuid) continue;
        for (final c in service.characteristics) {
          if (c.uuid == BleConstants.rxUuid) rx = c;
          if (c.uuid == BleConstants.txUuid) tx = c;
        }
      }
      if (rx == null || tx == null) {
        throw BleConnectException('The device is not running U Chat');
      }

      // Register before subscribing so the first notification isn't lost.
      final link = CentralLink(_manager, peripheral, rx, tx);
      _links[peripheral.uuid] = link;
      link.closed.then((_) {
        if (identical(_links[peripheral.uuid], link)) _links.remove(peripheral.uuid);
      });
      await _manager
          .setCharacteristicNotifyState(peripheral, tx, state: true)
          .timeout(BleConstants.gattOperationTimeout);
      return link;
    } catch (e) {
      _links.remove(peripheral.uuid)?.dispose();
      await _safeDisconnect(peripheral);
      if (e is BleConnectException) rethrow;
      throw BleConnectException('Setting up the connection failed ($e)');
    }
  }

  Future<void> _safeDisconnect(Peripheral peripheral) async {
    try {
      await _manager.disconnect(peripheral).timeout(BleConstants.gattOperationTimeout);
    } catch (_) {}
  }

  /// Bluetooth went off.
  void reset() {
    for (final link in _links.values.toList()) {
      link.markClosed();
    }
    _links.clear();
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    reset();
  }
}
