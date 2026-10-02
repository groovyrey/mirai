class AppConfig {
  AppConfig._();

  /// The aniwaves catalog + resolver worker (worker8652).
  static const aniwavesBase = 'https://worker8652.appleflux.workers.dev/api/aniwaves';

  /// Optional user-supplied base set from Settings; when non-empty it shadows
  /// [aniwavesBase]. Kept in [AppState], mutated before API calls.
  static String aniwavesBaseOverride = '';

  static String get resolverBase {
    final over = aniwavesBaseOverride.trim();
    return over.isNotEmpty ? over : aniwavesBase;
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