/// One anime episode as listed on the detail page.
class Episode {
  const Episode({required this.ep, required this.sub, required this.dub});

  final int ep;
  final bool sub;
  final bool dub;

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        ep: json['ep'] as int? ?? 0,
        sub: json['sub'] == true,
        dub: json['dub'] == true,
      );
}

/// A catalog entry for one anime title (search / list / detail).
class AnimeItem {
  const AnimeItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.href,
    this.originalTitle,
    this.image,
    this.type,
    this.rating,
    this.year,
  });

  final int id;
  final String slug;
  final String title;
  final String href;

  /// The original/Japanese name when the site presents one (`data-jp`).
  final String? originalTitle;
  final String? image;
  final String? type;
  final String? rating;
  final String? year;

  bool get hasImage => image != null && image!.isNotEmpty;

  factory AnimeItem.fromJson(Map<String, dynamic> json) => AnimeItem(
        id: json['id'] as int? ?? 0,
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        href: json['href'] as String? ?? '',
        originalTitle: json['originalTitle'] as String?,
        image: json['image'] as String?,
        type: json['type'] as String?,
        rating: json['rating'] as String?,
        year: json['year'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'href': href,
        'originalTitle': originalTitle,
        'image': image,
        'type': type,
        'rating': rating,
        'year': year,
      };
}

/// Expanded detail fetched from `/api/aniwaves/detail`, including episodes.
class AnimeDetail {
  const AnimeDetail({
    required this.item,
    this.synopsis,
    this.coverUrl,
    this.aired,
    this.duration,
    this.status,
    this.quality,
    this.ageRating,
    this.premiered,
    this.broadcast,
    this.country,
    this.source,
    this.reviews,
    this.otherNames = const [],
    this.genres = const [],
    this.studios = const [],
    this.producers = const [],
    this.licensors = const [],
    this.totalEps = 0,
    this.subEps = 0,
    this.dubEps = 0,
    this.episodes = const [],
  });

  final AnimeItem item;
  final String? synopsis;
  final String? coverUrl;
  final String? aired;
  final String? duration;
  final String? status;
  final String? quality;
  final String? ageRating;
  final String? premiered;
  final String? broadcast;
  final String? country;
  final String? source;
  final String? reviews;
  final List<String> otherNames;
  final List<String> genres;
  final List<String> studios;
  final List<String> producers;
  final List<String> licensors;
  final int totalEps;
  final int subEps;
  final int dubEps;
  final List<Episode> episodes;

  bool get hasEpisodes => episodes.isNotEmpty;

  /// Returns the first episode available (typically EP 1), used for queue display.
  Episode? get nextEpisode {
    if (episodes.isEmpty) return null;
    // Prefer first episode with sub, fallback to first episode
    return episodes.firstWhere(
      (e) => e.sub,
      orElse: () => episodes.first,
    );
  }

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'synopsis': synopsis,
        'coverUrl': coverUrl,
        'aired': aired,
        'duration': duration,
        'status': status,
        'quality': quality,
        'ageRating': ageRating,
        'premiered': premiered,
        'broadcast': broadcast,
        'country': country,
        'source': source,
        'reviews': reviews,
        'otherNames': otherNames,
        'genres': genres,
        'studios': studios,
        'producers': producers,
        'licensors': licensors,
        'totalEps': totalEps,
        'subEps': subEps,
        'dubEps': dubEps,
        'episodes': [
          for (final e in episodes) {'ep': e.ep, 'sub': e.sub, 'dub': e.dub},
        ],
      };

  factory AnimeDetail.fromJson(Map<String, dynamic> json) => AnimeDetail(
        item: (json['item'] is Map<String, dynamic>)
            ? AnimeItem.fromJson(json['item'] as Map<String, dynamic>)
            : AnimeItem.fromJson(json),
        synopsis: json['synopsis'] as String?,
        coverUrl: json['coverUrl'] as String?,
        aired: json['aired'] as String?,
        duration: json['duration'] as String?,
        status: json['status'] as String?,
        quality: json['quality'] as String?,
        ageRating: json['ageRating'] as String?,
        premiered: json['premiered'] as String?,
        broadcast: json['broadcast'] as String?,
        country: json['country'] as String?,
        source: json['source'] as String?,
        reviews: json['reviews'] as String?,
        otherNames: (json['otherNames'] as List?)?.cast<String>() ?? const [],
        genres: (json['genres'] as List?)?.cast<String>() ?? const [],
        studios: (json['studios'] as List?)?.cast<String>() ?? const [],
        producers: (json['producers'] as List?)?.cast<String>() ?? const [],
        licensors: (json['licensors'] as List?)?.cast<String>() ?? const [],
        totalEps: json['totalEps'] as int? ?? 0,
        subEps: json['subEps'] as int? ?? 0,
        dubEps: json['dubEps'] as int? ?? 0,
        episodes: (json['episodes'] as List?)
                ?.map((e) => e is Map<String, dynamic>
                    ? Episode.fromJson(e)
                    : Episode.fromJson((e as Map).cast<String, dynamic>()))
                .where((e) => e.ep > 0)
                .toList() ??
            const [],
      );
}