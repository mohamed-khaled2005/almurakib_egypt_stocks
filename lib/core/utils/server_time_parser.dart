// lib/core/utils/server_time_parser.dart

class ServerTimeParser {
  static const List<String> _epochKeys = [
    'update',
    'updated',
    'timestamp',
    'ts',
    't',
    'time',
    'server_time',
    'serverTime',
    'last_update',
    'lastUpdate',
  ];

  static const List<String> _stringKeys = [
    'updateTime',
    'update_time',
    'lastUpdateTime',
    'last_update_time',
    'tm',
    'date',
    'datetime',
    'last_updated',
    'lastUpdated',
  ];

  static DateTime? _fromEpoch(dynamic v) {
    if (v == null) return null;

    int? n;
    if (v is num) {
      n = v.toInt();
    } else {
      n = int.tryParse(v.toString().trim());
    }
    if (n == null) return null;

    final digits = n.abs().toString().length;

    // 13+ digits => milliseconds
    if (digits >= 13) {
      return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toUtc();
    }

    // 10-12 digits => seconds
    if (digits >= 10) {
      return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true).toUtc();
    }

    return null;
  }

  static DateTime? _fromIsoString(dynamic v, {required bool assumeUtcIfNoZone}) {
    if (v == null) return null;
    final raw = v.toString().trim();
    if (raw.isEmpty) return null;

    final iso = (raw.contains(' ') && !raw.contains('T'))
        ? raw.replaceFirst(' ', 'T')
        : raw;

    // يقبل Z أو +02:00 أو +0200
    final hasZone = RegExp(r'(Z|[+-]\d\d:\d\d|[+-]\d{4})$').hasMatch(iso);

    // لو مفيش Zone:
    // - لو assumeUtcIfNoZone=true => نضيف Z ونعتبره UTC
    // - لو false => نرفضه (علشان Dart ممكن تعتبره local)
    final fixed = hasZone
        ? iso
        : (assumeUtcIfNoZone ? '${iso}Z' : iso);

    final dt = DateTime.tryParse(fixed);
    if (dt == null) return null;

    if (!hasZone && !assumeUtcIfNoZone) return null;

    return dt.toUtc();
  }

  static DateTime? parse(dynamic v, {bool assumeUtcIfNoZone = true}) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();

    // 1) epoch
    final epoch = _fromEpoch(v);
    if (epoch != null) return epoch;

    // 2) string
    return _fromIsoString(v, assumeUtcIfNoZone: assumeUtcIfNoZone);
  }

  static DateTime? extractFromMap(
    Map<String, dynamic> m, {
    bool assumeUtcIfNoZone = true,
  }) {
    // 1) epoch keys
    for (final k in _epochKeys) {
      final dt = parse(m[k], assumeUtcIfNoZone: assumeUtcIfNoZone);
      if (dt != null) return dt;
    }

    // 2) string keys
    for (final k in _stringKeys) {
      final dt = parse(m[k], assumeUtcIfNoZone: assumeUtcIfNoZone);
      if (dt != null) return dt;
    }

    // 3) أحيانًا الوقت جوه active
    final active = m['active'];
    if (active is Map) {
      final mm = Map<String, dynamic>.from(active);
      final dt = extractFromMap(mm, assumeUtcIfNoZone: assumeUtcIfNoZone);
      if (dt != null) return dt;
    }

    return null;
  }

  /// يجمع وقت التحديث من:
  /// - root
  /// - response (List/Map)
  /// ويختار "أحدث وقت"
  static DateTime? extractFromApiResponse(
    Map<String, dynamic> data, {
    bool assumeUtcIfNoZone = true,
  }) {
    final candidates = <DateTime>[];

    void add(DateTime? d) {
      if (d == null) return;
      candidates.add(d.toUtc());
    }

    add(extractFromMap(data, assumeUtcIfNoZone: assumeUtcIfNoZone));

    final resp = data['response'];
    if (resp is List) {
      for (final it in resp) {
        if (it is Map) {
          add(extractFromMap(
            Map<String, dynamic>.from(it),
            assumeUtcIfNoZone: assumeUtcIfNoZone,
          ));
        }
      }
    } else if (resp is Map) {
      for (final it in resp.values) {
        if (it is Map) {
          add(extractFromMap(
            Map<String, dynamic>.from(it),
            assumeUtcIfNoZone: assumeUtcIfNoZone,
          ));
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => a.compareTo(b));
    return candidates.last;
  }
}
