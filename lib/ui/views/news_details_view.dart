// FLUTTER / DART / THIRD-PARTIES
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:notredame/core/models/news.dart';
import 'package:notredame/core/viewmodels/news_details_viewmodel.dart';
import 'package:notredame/ui/utils/app_theme.dart';
import 'package:notredame/ui/widgets/base_scaffold.dart';
import 'package:notredame/ui/widgets/report_news.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// SERVICES
import 'package:notredame/core/services/analytics_service.dart';

// OTHER
import 'package:notredame/locator.dart';

class NewsDetailsView extends StatefulWidget {
  final News news;

  const NewsDetailsView({this.news});

  @override
  _NewsDetailsViewState createState() => _NewsDetailsViewState();
}

class _NewsDetailsViewState extends State<NewsDetailsView> {
  final AnalyticsService _analyticsService = locator<AnalyticsService>();
  final content =
      "Le club scientifique qui conceptualise un robot de recherche et secourisme recrute pour ses nouveaux projets!";

  @override
  void initState() {
    super.initState();

    _analyticsService.logEvent("NewsDetailsView", "Opened");
  }

  @override
  Widget build(BuildContext context) =>
      ViewModelBuilder<NewsDetailsViewModel>.reactive(
        viewModelBuilder: () => NewsDetailsViewModel(news: widget.news),
        builder: (context, model, child) => BaseScaffold(
          showBottomBar: false,
          body: Material(
            child: NestedScrollView(
              physics: const ClampingScrollPhysics(),
              headerSliverBuilder: (context, innerBoxScrolled) => [
                SliverAppBar(
                  backgroundColor: Theme.of(context).brightness == Brightness.light
                          ? AppTheme.etsLightRed
                          : Theme.of(context).bottomAppBarColor,
                  pinned: true,
                  onStretchTrigger: () {
                    return Future<void>.value();
                  },
                  titleSpacing: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    AppIntl.of(context).news_details_title,
                    style: Theme.of(context).textTheme.bodyText1.copyWith(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  ),
                  actions: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () async {
                        model.shareNews(); // TODO
                        }
                      ),
                    IconButton(
                      icon: const Icon(Icons.warning_amber_sharp),
                      color: AppTheme.etsLightRed,
                      onPressed: () async {
                        await showModalBottomSheet(
                          isDismissible: true,
                          enableDrag: true,
                          isScrollControlled: true,
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10))),
                          builder: (context) => const ReportNews());
                        }
                      )
                  ],
                ),
              ],
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTitle("Merci à McGill Robotics pour l’invitation au RoboHacks 2023!"), // TODO: Change for widget.news.title
                    _buildDate(
                        context,
                        DateTime.now(),
                        DateTime.now().add(const Duration(days: 3))), // TODO: Change for widget.news.publishedDate
                    _buildImage("https://picsum.photos/400/200"), // TODO: Change for widget.news.image
                    _buildAuthor("Capra", "Club scientifique"), // TODO: Change for widget.news.author
                    _buildContent(content), // TODO: Change for widget.news.description
                    const Spacer(),
                    _buildTags(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyText1.copyWith(
            color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildImage(String image) {
    if (image == null) {
      return const SizedBox.shrink();
    }

    return Image.network(
      image,
      fit: BoxFit.cover,
    );
  }

  Widget _buildAuthor(String author, String activity) {
    return Container(
      color: const Color(0xff1e1e1e),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red,
          child: Image.asset('assets/capra_logo.png'),
        ),
        title: Text(
          author,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            activity,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDate(BuildContext context, DateTime publishedDate, DateTime eventDate) {
    final String formattedPublishedDate =
        DateFormat('d MMMM yyyy', Localizations.localeOf(context).toString())
            .format(publishedDate);
    final String formattedEventDate =
        DateFormat('d MMMM yyyy', Localizations.localeOf(context).toString())
            .format(eventDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 5.0, 16.0, 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                formattedPublishedDate,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12.0),
            ],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.etsDarkGrey,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event, size: 20.0, color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppIntl.of(context).news_event_date,
                          style: const TextStyle(color: AppTheme.etsLightGrey),
                        ),
                        Text(
                          formattedEventDate,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String content) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        content,
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildTags() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              5, // TODO : Change
              (index) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Robotique",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
