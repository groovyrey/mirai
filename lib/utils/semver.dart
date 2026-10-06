/// Minimal semantic-version helpers for release comparison.
///
/// Handles the shapes Mirai tags actually use: `1.1.0`, `v1.1.0`,
/// `1.2.0-beta.1`, `1.2.0-rc.3+17`. Returns 0 when a component is missing so
/// partial tags like `1.2` still order correctly against `1.2.0`.
class SemVer implements Comparable<SemVer> {
  SemVer(this.raw) : _parsed = _parse(raw);

  final String raw;
  final _SemVerParts _parsed;

  static final _pattern = RegExp(
    r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
  );

  static _SemVerParts _parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return const _SemVerParts(0, 0, 0, '');
    return _SemVerParts(
      int.tryParse(match.group(1)!) ?? 0,
      int.tryParse(match.group(2) ?? '0') ?? 0,
      int.tryParse(match.group(3) ?? '0') ?? 0,
      match.group(4) ?? '',
    );
  }

  int get major => _parsed.major;
  int get minor => _parsed.minor;
  int get patch => _parsed.patch;
  String get preRelease => _parsed.preRelease;
  bool get isPreRelease => _parsed.preRelease.isNotEmpty;

  /// Strips the leading `v` and any build metadata for display.
  String get label {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return raw.trim();
    final core = [
      int.tryParse(match.group(1)!) ?? 0,
      int.tryParse(match.group(2) ?? '0') ?? 0,
      int.tryParse(match.group(3) ?? '0') ?? 0,
    ].join('.');
    final pre = match.group(4);
    return pre == null || pre.isEmpty ? core : '$core-$pre';
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return _comparePreRelease(preRelease, other.preRelease);
  }

  /// A release with no pre-release tag outranks one that has it.
  static int _comparePreRelease(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 0;
    if (a.isEmpty) return 1;
    if (b.isEmpty) return -1;
    final left = a.split('.');
    final right = b.split('.');
    for (var i = 0; i < left.length || i < right.length; i++) {
      final l = i < left.length ? left[i] : '0';
      final r = i < right.length ? right[i] : '0';
      final ln = int.tryParse(l);
      final rn = int.tryParse(r);
      final result = (ln != null && rn != null)
          ? ln.compareTo(rn)
          : l.compareTo(r);
      if (result != 0) return result;
    }
    return 0;
  }

  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator <(SemVer other) => compareTo(other) < 0;
  bool operator >=(SemVer other) => compareTo(other) >= 0;

  @override
  String toString() => label;
}

class _SemVerParts {
  const _SemVerParts(this.major, this.minor, this.patch, this.preRelease);

  final int major;
  final int minor;
  final int patch;
  final String preRelease;
}

/// Filters [releases] down to those newer than [installed], newest first.
///
/// Ordering is semantic rather than by publish date so a backfilled release
/// still sorts into the correct position in the skipped-version list.
List<T> releasesNewerThan<T>(
  List<T> releases,
  String installed,
  String Function(T) versionOf,
) {
  final base = SemVer(installed);
  final newer = releases.where((r) => SemVer(versionOf(r)) > base).toList()
    ..sort((a, b) => SemVer(versionOf(b)).compareTo(SemVer(versionOf(a))));
  return newer;
}