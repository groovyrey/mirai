class AppConfig {
  AppConfig._();

  /// Root of the resolver worker (worker8652). Every endpoint group hangs off
  /// this host, so a settings override only needs to name the root once.
  static const workerRoot = 'https://worker8652.appleflux.workers.dev';

  /// The aniwaves catalog + resolver worker (worker8652).
  static const aniwavesBase = '$workerRoot/api/aniwaves';

  /// Optional user-supplied base set from Settings; when non-empty it shadows
  /// [aniwavesBase]. Kept in [AppState], mutated before API calls.
  static String aniwavesBaseOverride = '';

  static String get resolverBase {
    final over = aniwavesBaseOverride.trim();
    return over.isNotEmpty ? over : aniwavesBase;
  }

  /// aniwatch.lu source resolver. Lives on the same worker as a sibling group,
  /// so the settings override (which names the aniwaves base) maps across by
  /// swapping the trailing group instead of needing its own field.
  static String get aniwatchBase {
    final over = aniwavesBaseOverride.trim();
    if (over.isEmpty) return '$workerRoot/api/aniwatch';
    return over.replaceFirst(RegExp(r'/api/aniwaves$'), '') + '/api/aniwatch';
  }
}

/// Host suffixes a Mirai embed player may navigate to as the main frame.
///
/// These are the players aniwaves hands out: DoodStream (myvidplay/playmogo)
/// direct MP4s are played natively, but the echovideo and gn1r5n embeds run in
/// the WebView player with the ad layer stripped.
class EmbedSources {
  EmbedSources._();

  static const List<String> allowedNavHostSuffixes = [
    'echovideo.ru',
    'gn1r5n.org',
    'myvidplay.com',
    'playmogo.com',
  ];
}

/// Emit an aniwaves embed URL for an episode.
String aniwavesEmbedUrl({required int id, required String slug, required int ep}) {
  return 'https://aniwaves.ru/watch/$slug-$id?ep=$ep';
}