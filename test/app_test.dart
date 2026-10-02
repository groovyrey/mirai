import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mirai/main.dart';
import 'package:mirai/screens/more_screen.dart';
import 'package:mirai/screens/saved_screen.dart';
import 'package:mirai/screens/shell.dart';
import 'package:mirai/services/saved.dart';
import 'package:mirai/services/version_checker.dart';
import 'package:mirai/services/watch_history.dart';
import 'package:mirai/widgets/mirai_wordmark.dart';

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

  testWidgets('app boots through the splash into the shell', (tester) async {
    await boot(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(MiraiWordmark), findsWidgets);
  });

  testWidgets('shell carries the section tab strip', (tester) async {
    await boot(tester);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('TRENDING'), findsOneWidget);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('FIND'), findsOneWidget);
    expect(find.text('MORE'), findsOneWidget);
  });

  testWidgets('saved shows its empty state', (tester) async {
    await boot(tester);

    await tester.tap(find.text('SAVED'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SavedScreen), findsOneWidget);
    expect(find.text('NOTHING SAVED YET.'), findsOneWidget);
  });

  testWidgets('more exposes the settings column', (tester) async {
    await boot(tester);

    await tester.tap(find.text('MORE'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('PLAYBACK'), findsOneWidget);
    expect(find.text('ACCOUNT & DATA'), findsOneWidget);

    // Let the delayed auto-update check and its network call finish so no
    // timers are left pending.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
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

    test('announces the newer stable release', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v1.0.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://github.com/groovyrey/mirai/releases/tag/v1.0.0',
          },
        ]),
      );
      final info = await checker.check(enabled: true);
      expect(info, isNotNull);
      expect(info!.version, '1.0.0');
    });

    test('skips the prerelease on the stable channel', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v2.0.0-beta.1',
            'prerelease': true,
            'draft': false,
            'html_url': 'https://example.com/beta',
          },
          {
            'tag_name': 'v1.0.0',
            'prerelease': false,
            'draft': false,
            'html_url': 'https://example.com/stable',
          },
        ]),
      );
      final info = await checker.check(includePrerelease: false);
      expect(info!.version, '1.0.0');
    });

    test('includes the prerelease when the beta channel is on', () async {
      final checker = VersionChecker(
        client: releasesResponse([
          {
            'tag_name': 'v2.0.0-beta.1',
            'prerelease': true,
            'draft': false,
            'html_url': 'https://example.com/beta',
          },
        ]),
      );
      final info = await checker.check(includePrerelease: true);
      expect(info!.version, '2.0.0-beta.1');
    });

    test('disabled checks never hit the network', () async {
      final checker = VersionChecker(
        client: MockClient((request) async {
          fail('network should not be reached');
        }),
      );
      final info = await checker.check(enabled: false);
      expect(info, isNull);
    });
  });
}