import 'dart:convert';
import 'dart:io';
import '../../features/onboarding/domain/cluster_model.dart';

/// Android can give Dart either cache directory. Both have the same private
/// data root; include the original writer's private fallback locations.
String? androidStorePath(String tempPath, {
  required bool Function(String) exists,
  required bool Function(String) isSafe,
}) {
  final match = RegExp(
    r'^(/(?:data/(?:data|user(?:_de)?/[0-9]+)|mnt/expand/[a-zA-Z0-9-]+/user(?:_de)?/[0-9]+)/[a-zA-Z][a-zA-Z0-9_.]*)/(cache|code_cache)/?$',
  ).firstMatch(tempPath);
  if (match == null) return null;
  final root = match.group(1)!;
  final current = match.group(2)!;
  final paths = [
    for (final dir in ['app_flutter', 'files', current, current == 'cache' ? 'code_cache' : 'cache'])
      '$root/$dir/hungr_local_store.json',
  ];
  for (final path in paths) {
    if (isSafe(path) && exists(path)) return path;
  }
  return isSafe(paths.first) ? paths.first : null;
}

/// Customer preferences only. Firebase Auth owns the session and phone number.
class LocalStorageService {
  LocalStorageService._();
  LocalStorageService.inMemory() : _initialized = Future.value();
  static final LocalStorageService instance = LocalStorageService._();

  static const String _keyUid = 'hungr_uid';
  static const String _keyGate = 'hungr_selected_gate';
  static const String _keyHasActivePass = 'hungr_has_active_pass';
  static const String _keyPassTier = 'hungr_pass_tier';
  static const String _keyMealsRemaining = 'hungr_meals_remaining';
  static const String _keyTotalMeals = 'hungr_total_meals';
  static const String _keyTomorrowCombo = 'hungr_tomorrow_combo';
  static const String _keyReferralCount = 'hungr_referral_count';
  static const String _keyFreePassClaimed = 'hungr_free_pass_claimed';

  final Map<String, dynamic> _memoryCache = {};
  Future<void>? _initialized;
  Future<void> _pendingWrite = Future.value();
  File? _storeFile;
  bool _needsPrivateFile = false;

  Future<void> _ensureInitialized() => _initialized ??= _load();

  Future<void> _load() async {
    try {
      _storeFile = _resolveStoreFile();
      if (_storeFile != null && await _storeFile!.exists()) {
        final content = await _storeFile!.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            _memoryCache.addAll(decoded);
          }
        }
      }
    } catch (_) {
      // Graceful fallback to memoryCache if file system is inaccessible
    }
  }

  File? _resolveStoreFile() {
    try {
      // Do not write customer data to a desktop/shared temporary directory.
      if (!Platform.isAndroid) return null;
      _needsPrivateFile = true;
      final path = androidStorePath(Directory.systemTemp.path,
        exists: (path) => File(path).existsSync(),
        isSafe: (path) => !FileSystemEntity.isLinkSync(File(path).parent.path) &&
            !FileSystemEntity.isLinkSync(path),
      );
      if (path == null) return null;
      final file = File(path);
      file.parent.createSync(recursive: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistToDisk({bool requiredForGate = false}) async {
    final file = _storeFile;
    if (file == null) {
      if (_needsPrivateFile && requiredForGate) throw StateError('Private gate storage is unavailable.');
      return;
    }
    // Older, unawaited preference writes must not finish after a sign-out wipe.
    final content = jsonEncode(_memoryCache);
    final write = _pendingWrite.then((_) async {
      await file.writeAsString(content, flush: true);
    });
    // A failed write must not prevent a later wipe or retry.
    _pendingWrite = write.catchError((Object _) {});
    await (requiredForGate ? write : _pendingWrite);
  }

  /// Discard legacy unowned data and any previous customer's cache.
  Future<DeliveryCluster?> bindCustomer(String uid, {required String profileGate}) async {
    await _ensureInitialized();
    if (_memoryCache[_keyUid] != uid) {
      _memoryCache.clear();
      _memoryCache[_keyUid] = uid;
      await _persistToDisk();
      return null;
    }
    final gate = _savedGate;
    if (gate != null && gate.name == profileGate && gate.id.isNotEmpty && profileGate.isNotEmpty) {
      return gate;
    }
    // A remote name alone cannot identify a gate on a fresh device. Old
    // separate ID/name fields also could have been written by different saves.
    if (_memoryCache.remove(_keyGate) != null) await _persistToDisk();
    return null;
  }

  Future<void> clearUserSession() async {
    await _ensureInitialized();
    _memoryCache.clear();
    await _persistToDisk();
  }

  // --- Delivery Cluster ---

  DeliveryCluster? get _savedGate {
    final data = _memoryCache[_keyGate];
    if (data is! Map<String, dynamic>) return null;
    try {
      return DeliveryCluster.fromMap(data);
    } on TypeError {
      return null;
    }
  }

  Future<DeliveryCluster?> getSavedGate() async {
    await _ensureInitialized();
    return _savedGate;
  }

  Future<void> saveVerifiedGate(String uid, DeliveryCluster gate) async {
    await _ensureInitialized();
    if (_memoryCache[_keyUid] != uid) throw StateError('Customer changed.');
    final entry = gate.toMap();
    _memoryCache[_keyGate] = entry;
    try {
      await _persistToDisk(requiredForGate: true);
    } catch (_) {
      if (identical(_memoryCache[_keyGate], entry)) _memoryCache.remove(_keyGate);
      rethrow;
    }
  }

  // Legacy dashboard call: a display refresh must not select a different gate.
  Future<void> saveCluster({
    required String id, required String name, required String zone, required String landmark,
  }) async {
    await _ensureInitialized();
    final gate = _savedGate;
    if (gate == null || gate.id != id || gate.name != name) return;
    if (gate.addressZone == zone && gate.landmark == landmark) return;
    _memoryCache[_keyGate] = {...gate.toMap(), 'addressZone': zone, 'landmark': landmark};
    await _persistToDisk();
  }

  Future<Map<String, String>?> getSavedCluster() async {
    await _ensureInitialized();
    final gate = _savedGate;
    if (gate == null) return null;
    return {
      'id': gate.id, 'name': gate.name, 'zone': gate.addressZone, 'landmark': gate.landmark,
    };
  }

  // --- Active Pass ---

  Future<void> savePassState({
    required bool hasActivePass,
    required String tier,
    required int mealsRemaining,
    required int totalMeals,
    required String tomorrowCombo,
  }) async {
    await _ensureInitialized();
    if (_memoryCache[_keyUid] == null) return;
    _memoryCache[_keyHasActivePass] = hasActivePass;
    _memoryCache[_keyPassTier] = tier;
    _memoryCache[_keyMealsRemaining] = mealsRemaining;
    _memoryCache[_keyTotalMeals] = totalMeals;
    _memoryCache[_keyTomorrowCombo] = tomorrowCombo;
    await _persistToDisk();
  }

  Future<Map<String, dynamic>?> getSavedPassState() async {
    await _ensureInitialized();
    if (!_memoryCache.containsKey(_keyHasActivePass)) return null;
    return {
      'hasActivePass': _memoryCache[_keyHasActivePass] as bool? ?? false,
      'tier': (_memoryCache[_keyPassTier] as String?) ?? 'routine7Day',
      'mealsRemaining': (_memoryCache[_keyMealsRemaining] as int?) ?? 5,
      'totalMeals': (_memoryCache[_keyTotalMeals] as int?) ?? 7,
      'tomorrowCombo': (_memoryCache[_keyTomorrowCombo] as String?) ?? 'A',
    };
  }

  // --- Viral Referral Loop ---

  Future<void> saveReferralState({
    required int count,
    required bool isClaimed,
  }) async {
    await _ensureInitialized();
    if (_memoryCache[_keyUid] == null) return;
    _memoryCache[_keyReferralCount] = count;
    _memoryCache[_keyFreePassClaimed] = isClaimed;
    await _persistToDisk();
  }

  Future<Map<String, dynamic>> getReferralState() async {
    await _ensureInitialized();
    return {
      'count': (_memoryCache[_keyReferralCount] as int?) ?? 0,
      'isClaimed': (_memoryCache[_keyFreePassClaimed] as bool?) ?? false,
    };
  }
}
