// FLUTTER / DART / THIRD-PARTIES
import 'package:notredame/core/models/news.dart';
import 'package:stacked/stacked.dart';

class NewsDetailsViewModel extends FutureViewModel<News> {
  News news;

  NewsDetailsViewModel({this.news});

  @override
  Future<News> futureToRun() {
    return Future.value(news);
  }

  void shareNews() {
    print('todo');
  }
}
