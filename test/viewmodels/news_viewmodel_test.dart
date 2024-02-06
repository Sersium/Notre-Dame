// FLUTTER / DART / THIRD-PARTIES
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// MANAGERS
import 'package:notredame/core/managers/settings_manager.dart';
import 'package:notredame/core/managers/news_repository.dart';

// MODEL
import 'package:notredame/core/models/news.dart';

// VIEWMODEL
import 'package:notredame/core/viewmodels/news_viewmodel.dart';

// UTILS
import 'package:notredame/locator.dart';
import 'package:logger/logger.dart';
import '../helpers.dart';
import '../mock/managers/news_repository_mock.dart';
import '../mock/managers/news_repository_mock.mocks.dart';

void main() {
  late NewsViewModel viewModel;
  late NewsRepositoryMock newsRepository;
  late AppIntl appIntl;

  List<News> news = [
    News(
      id: 1,
      title: 'Mock News 1',
      description: 'Mock Description 1',
      image: 'https://example.com/mock-image1.jpg',
      tags: [],
      date: DateTime.now(),
    ),
    News(
      id: 2,
      title: 'Mock News 2',
      description: 'Mock Description 2',
      image: 'https://example.com/mock-image2.jpg',
      tags: [],
      date: DateTime.now(),
    ),
  ];

  group('NewsViewModel tests', () {
    setUp(() async {
      newsRepository = setupNewsRepositoryMock();
      setupLogger();
      setupSettingsManagerMock();
      NewsRepositoryMock.stubNews(newsRepository, toReturn: news);
      appIntl = await setupAppIntl();
      viewModel = NewsViewModel(intl: appIntl);
    });

    tearDown(() {
      locator.unregister<Logger>();
      locator.unregister<NewsRepository>();
      locator.unregister<SettingsManager>();
    });

    test('Fetching news updates the news list', () async {
      expect(viewModel.isBusy, isFalse);

      await viewModel.futureToRun();

      expect(viewModel.news, hasLength(2));
      expect(viewModel.news?[0].title, equals('Mock News 1'));
      expect(viewModel.news?[1].title, equals('Mock News 2'));
      expect(viewModel.isBusy, isFalse);
    });
  });
}
