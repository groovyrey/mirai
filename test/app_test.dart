import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mirai/main.dart';
import 'package:mirai/screens/saved_screen.dart';
import 'package:mirai/screens/settings_screen.dart';
import 'package:mirai/screens/shell.dart';
import 'package:mirai/screens/update_screen.dart';
import 'package:mirai/services/saved.dart';
import 'package:mirai/services/version_checker.dart';
import 'package:mirai/services/watch_history.dart';
import 'package:mirai/state/app_state.dart';
import 'package:mirai/state/update_notifier.dart';
import 'package:mirai/utils/semver.dart';
import 'package:mirai/widgets/mirai_wordmark.dart';
import 'package:mirai/widgets/release_notes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WatchHistory.instance.clear();
    await Saved.instance.clear();
  });

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(const MiraiApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('app boots through the splash into the shell', (tester) async {
    await boot(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(MiraiWordmark), findsWidgets);
  });

  testWidgets('shell navigation drawer lists every section', (tester) async {
    await boot(tester);

    expect(find.text('SAVED'), findsNothing);
    await openDrawer(tester);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('TRENDING'), findsOneWidget);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('FIND'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('saved shows its empty state', (tester) async {
    await boot(tester);

    await openDrawer(tester);
    await tester.tap(find.text('SAVED'));
    await tester.pumpAndSettle();

    expect(find.byType(SavedScreen), findsOneWidget);
    expect(find.text('NOTHING SAVED YET.'), findsOneWidget);
  });

  testWidgets('settings exposes the settings column', (tester) async {
    await boot(tester);

    await openDrawer(tester);
    await tester.tap(find.text('SETTINGS'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('PLAYBACK'), findsOneWidget);
    expect(find.text('ACCOUNT & DATA'), findsOneWidget);

    // Let the delayed auto-update check and its network call finish so no
    // timers are left pending.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('update screen lists every skipped release with notes', (
    tester,
  ) async {
    final checker = VersionChecker(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.2.0',
              'prerelease': false,
              'draft': false,
              'html_url': 'https://example.com/v1.2.0',
              'body': '## Fixed\n- AniWatch source',
              'published_at': '2026-10-05T10:00:00Z',
            },
            {
              'tag_name': 'v0.0.1',
              'prerelease': false,
              'draft': false,
              'html_url': 'https://example.com/v0.0.1',
              'body': 'First cut',
              'published_at': '2026-01-01T10:00:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState()..init(),
        child: MaterialApp(
          home: UpdateScreen(checker: checker),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('AniWatch source'), findsOneWidget);
    expect(find.text('ALL RELEASES'), findsOneWidget);

    // Drain the PackageInfo platform call.
    await tester.pump(const Duration(milliseconds: 300));
  });

  group('version checker', () {
    http.Client releasesResponse(List<Map<String, dynamic>> releases) {
      return MockClient((request) async {
        expect(request.url.path, contains('/repos/groovyrey/mirai/releases'));
        return http.Response(
          '[${releases.map((r) => jsonEncode(r)).join(',')}]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
    }

    test('announces the newest stable release', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v1.0.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://github.com/groovyrey/mirai/releases/tag/v1.0.0',
            'published_at': '2026-10-04T01:37:04Z',
          },
        ]),
      );
      final latest = await checker.latest(includePrerelease: false);
      expect(latest, isNotNull);
      expect(latest!.version, '1.0.0');
    });

    test('skips the prerelease on the stable channel', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v2.0.0-beta.1',
            'prerelease': true,
            'draft': false,
            'html_url': 'https://example.com/beta',
            'published_at': '2026-10-05T01:45:00Z',
          },
          {
            'tag_name': 'v1.0.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/stable',
            'published_at': '2026-10-04T01:37:04Z',
          },
        ]),
      );
      expect((await checker.latest())!.version, '1.0.0');
    });

    test('includes the prerelease when the beta channel is on', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v2.0.0-beta.1',
            'prerelease': true,
            'draft': false,
            'html_url': 'https://example.com/beta',
            'published_at': '2026-10-05T01:45:00Z',
          },
        ]),
      );
      final latest = await checker.latest(includePrerelease: true);
      expect(latest!.version, '2.0.0-beta.1');
    });

    test('returns the newest first when several releases exist', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v1.0.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/a',
            'published_at': '2026-10-01T00:00:00Z',
          },
          {
            'tag_name': 'v1.2.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/c',
            'published_at': '2026-10-05T00:00:00Z',
          },
          {
            'tag_name': 'v1.1.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/b',
            'published_at': '2026-10-03T00:00:00Z',
          },
        ]),
      );
      final all = await checker.releases();
      expect(all.map((r) => r.version), ['1.2.0', '1.1.0', '1.0.0']);
    });

    test('disabled checks never hit the network', () async {
      final checker = VersionChecker(
        client: MockClient((request) async {
          fail('network should not be reached');
        }),
      );
      expect(await checker.latest(enabled: false), isNull);
      expect(await checker.releases(enabled: false), isEmpty);
    });

    test('keeps release notes, dates, and assets off each entry', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v1.2.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/v1.2.0',
            'body': '## Fixed\n- Playback retry',
            'published_at': '2026-10-05T10:00:00Z',
            'assets': [
              {
                'name': 'Mirai-1.2.0-arm64.apk',
                'browser_download_url': 'https://example.com/app.apk',
                'size': 33554432,
                'download_count': 12,
              },
            ],
          },
        ]),
      );
      final all = await checker.releases();
      expect(all, hasLength(1));
      expect(all.first.notes, contains('Playback retry'));
      expect(all.first.publishedAt, isNotNull);
      expect(all.first.assets.single.name, 'Mirai-1.2.0-arm64.apk');
      expect(all.first.assets.single.sizeLabel, '32 MB');
    });
  });

  group('semver', () {
    test('orders core components numerically', () {
      expect(SemVer('v1.10.0') > SemVer('1.9.9'), isTrue);
      expect(SemVer('1.1.0') < SemVer('1.1.1'), isTrue);
      expect(SemVer('2.0.0') > SemVer('1.99.99'), isTrue);
    });

    test('ranks a stable tag above its prereleases', () {
      expect(SemVer('1.1.0') > SemVer('1.1.0-beta.1'), isTrue);
      expect(SemVer('1.1.0-beta.2') > SemVer('1.1.0-beta.1'), isTrue);
      expect(SemVer('1.0.0') > SemVer('1.0.0-rc.3'), isTrue);
    });

    test('strips the v prefix and build metadata for display', () {
      expect(SemVer('v1.1.0').label, '1.1.0');
      expect(SemVer('v1.1.0+17').label, '1.1.0');
      expect(SemVer('1.1.0-beta.1').label, '1.1.0-beta.1');
      expect(SemVer('1.1.0').isPreRelease, isFalse);
    });

    test('keeps releases newer than the installed build, newest first', () {
      final releases = ['1.0.0', '1.3.0', '1.2.0', '0.9.0'];
      final newer = releasesNewerThan(releases, '1.1.0', (v) => v);
      expect(newer, ['1.3.0', '1.2.0']);
    });
  });

  group('release notes', () {
    test('splits headings, bullets, and paragraphs', () {
      final blocks = ReleaseNotesParser.parse(
        '## Fixed\n- Retry on failure\n- Subtitle offset\n\nLonger note.',
      );
      expect(blocks.first.text, 'Fixed');
      expect(blocks[0].level, 2);
      expect(blocks[1].isBullet, isTrue);
      expect(blocks[1].text, 'Retry on failure');
      expect(blocks.last.isBullet, isFalse);
      expect(blocks.last.text, 'Longer note.');
    });

    test('renders checkbox items as bullets', () {
      final blocks = ReleaseNotesParser.parse('- [x] AniWatch source');
      expect(blocks.single.text, 'AniWatch source');
    });

    test('an empty body produces no blocks', () {
      expect(ReleaseNotesParser.parse('   '), isEmpty);
    });
  });

  group('update notifier', () {
    VersionChecker checkerWith(List<Map<String, dynamic>> releases) =>
        VersionChecker(client: MockClient((_) async {
          return http.Response(
            '[${releases.map((r) => jsonEncode(r)).join(',')}]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }));

    test('flags a pending release newer than the installed build', () async {
      final notifier = UpdateNotifier(
        checker: checkerWith([
          {
            'tag_name': 'v9.0.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/v9.0.0',
            'published_at': '2026-10-05T10:00:00Z',
          },
        ]),
        installedVersion: '1.1.0',
      );
      await notifier.check(includePrerelease: false, enabled: true);
      expect(notifier.checked, isTrue);
      expect(notifier.latest!.version, '9.0.0');
      expect(notifier.hasUpdateOn(false), isTrue);
    });

    test('the installed build itself is not pending', () async {
      final notifier = UpdateNotifier(
        checker: checkerWith([
          {
            'tag_name': 'v1.1.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/v1.1.0',
            'published_at': '2026-10-04T15:04:14Z',
          },
        ]),
        installedVersion: '1.1.0',
      );
      await notifier.check(includePrerelease: false, enabled: true);
      expect(notifier.hasUpdateOn(false), isFalse);
    });

    test('a disabled check leaves the notifier empty', () async {
      final notifier = UpdateNotifier(
        checker: VersionChecker(
          client: MockClient((_) async => fail('network should not be reached')),
        ),
      );
      await notifier.check(includePrerelease: false, enabled: false);
      expect(notifier.hasUpdate, isFalse);
    });
  });
}