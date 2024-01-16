// FLUTTER / DART / THIRD-PARTIES
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:notredame/core/models/news.dart';
import 'package:notredame/core/viewmodels/news_details_viewmodel.dart';
import 'package:notredame/ui/utils/app_theme.dart';
import 'package:notredame/ui/widgets/base_scaffold.dart';
import 'package:stacked/stacked.dart';

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
                  backgroundColor: Theme.of(context).bottomAppBarColor,
                  /*Theme.of(context).brightness == Brightness.light
                          ? AppTheme.etsLightRed
                          : Theme.of(context).bottomAppBarColor,*/
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
                    "Annonce",
                    style: Theme.of(context).textTheme.bodyText1.copyWith(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  ),
                  actions: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.warning_amber_sharp),
                      color: AppTheme.etsLightRed,
                      onPressed: () {
                        // Your action on button press
                      },
                    ),
                  ],
                ),
              ],
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitle(
                          "Séance d’information"), // TODO: Change for widget.news.title
                      _buildImage(
                          "https://picsum.photos/400/200"), // TODO: Change for widget.news.image
                      _buildPublishedOn(
                          DateTime.now(),
                          DateTime.now().add(const Duration(
                              days:
                                  3))), // TODO: Change for widget.news.publishedDate
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end, // Center the row content
                        children: <Widget>[
                          Container(
                            width: 200,
                            child: const Divider(
                              color: AppTheme.etsLightRed,
                              thickness: 2,
                            ),
                          ),
                        ],
                      ),
                      _buildContent(
                          content), // TODO: Change for widget.news.description
                      const Spacer(), // This will push everything above it upwards
                      _buildTags(), // This will now appear at the bottom
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildTitle(String title) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyText1.copyWith(
          color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildImage(String image) {
    if (image == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Image.network(
          image,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPublishedOn(DateTime publishedDate, DateTime eventDate) {
    final String formattedPublishedDate =
        DateFormat.yMMMMd(Localizations.localeOf(context).toString())
            .format(publishedDate);
    final String formattedEventDate =
        DateFormat.yMMMMd(Localizations.localeOf(context).toString())
            .format(eventDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "Publié le $formattedPublishedDate par Capra",
        ),
        Text(
          "Date de l’événement: $formattedEventDate",
        ),
      ],
    );
  }

  Widget _buildContent(String content) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Text(
        content,
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildTags() {
    return Column(
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
    );
  }
}
