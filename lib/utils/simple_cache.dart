/// Système de cache simple pour optimiser les performances
class SimpleCache<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final Duration _defaultTtl;

  SimpleCache({Duration defaultTtl = const Duration(minutes: 5)})
      : _defaultTtl = defaultTtl;

  void set(String key, T value, {Duration? ttl}) {
    final expiry = DateTime.now().add(ttl ?? _defaultTtl);
    _cache[key] = _CacheEntry(value, expiry);
  }

  T? get(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }

  void clear() => _cache.clear();

  void remove(String key) => _cache.remove(key);

  bool contains(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiry;

  _CacheEntry(this.value, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}