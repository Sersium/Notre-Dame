// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Project imports:
import 'package:notredame/core/models/quick_link.dart';
import 'package:notredame/core/services/analytics_service.dart';
import 'package:notredame/core/services/internal_info_service.dart';
import 'package:notredame/core/services/launch_url_service.dart';
import 'package:notredame/core/services/navigation_service.dart';
import 'package:notredame/ui/widgets/web_link_card.dart';
import '../../helpers.dart';

final _quickLink = QuickLink(
    id: 1, image: const Icon(Icons.ac_unit), name: 'test', link: 'testlink');

void main() {
  AnalyticsService analyticsService;
  LaunchUrlService launchUrlService;

  group('WebLinkCard - ', () {
    setUp(() {
      analyticsService = setupAnalyticsServiceMock();
      launchUrlService = setupLaunchUrlServiceMock();
      setupInternalInfoServiceMock();
      setupNavigationServiceMock();
    });

    tearDown(() {
      unregister<NavigationService>();
      clearInteractions(analyticsService);
      clearInteractions(launchUrlService);
      unregister<AnalyticsService>();
      unregister<InternalInfoService>();
    });

    testWidgets('has an icon and a title', (WidgetTester tester) async {
      await tester.pumpWidget(localizedWidget(child: WebLinkCard(_quickLink)));
      await tester.pumpAndSettle();

      final text = find.byType(Text);
      final icon1 = find.byType(Icon);

      expect(text, findsNWidgets(1));
      expect(_quickLink.name, 'test');
      expect(icon1, findsNWidgets(1));
    });
  });
}
