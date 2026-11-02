import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A 30-digit code derived from both identity keys. It is the same on both
/// phones, and different for every pair of identities. If the codes match
/// when compared in person, nobody is impersonating either side.
String safetyNumber(List<int> publicKeyA, List<int> publicKeyB) {
  final keys = [publicKeyA, publicKeyB]..sort(_compareBytes);
  final digest = sha256.convert([
    ...utf8.encode('uchat-safety-v1'),
    ...keys[0],
    ...keys[1],
  ]).bytes;
  final groups = <String>[];
  for (var g = 0; g < 6; g++) {
    var value = 0;
    for (var i = 0; i < 5; i++) {
      value = (value << 8) | digest[g * 5 + i];
    }
    groups.add((value % 100000).toString().padLeft(5, '0'));
  }
  return groups.join(' ');
}

int _compareBytes(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}
