// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:calendar_view/calendar_view.dart' as calendar_view;
import 'package:calendar_view/calendar_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:github/github.dart';

// Project imports:
import 'package:notredame/ui/utils/app_theme.dart';
import 'package:notredame/ui/widgets/schedule_calendar_tile.dart';

class ScheduleDefault extends StatefulWidget {
  final List<CalendarEventData<Object>> calendarEvents;

  const ScheduleDefault({Key key, this.calendarEvents}) : super(key: key);

  @override
  _ScheduleDefaultState createState() => _ScheduleDefaultState();
}

class _ScheduleDefaultState extends State<ScheduleDefault> {
  static final List<String> weekTitles = ["L", "M", "M", "J", "V", "S", "D"];
  final GlobalKey<calendar_view.WeekViewState> weekViewKey =
      GlobalKey<calendar_view.WeekViewState>();

  final eventController = EventController();

  @override
  Widget build(BuildContext context) {
    // Check if there are no events
    if (widget.calendarEvents.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            AppIntl.of(context).no_schedule_available,
          ),
        ),
      );
    }

    // If there are events, display the calendar
    return Scaffold(
        body: AbsorbPointer(
      child: calendar_view.WeekView(
        key: weekViewKey,
        controller: eventController..addAll(widget.calendarEvents),
        backgroundColor: AppTheme.darkThemeBackground,
        weekDays: const [
          calendar_view.WeekDays.monday,
          calendar_view.WeekDays.tuesday,
          calendar_view.WeekDays.wednesday,
          calendar_view.WeekDays.thursday,
          calendar_view.WeekDays.friday,
          calendar_view.WeekDays.saturday
        ],
        scrollOffset: 340,
        heightPerMinute: 0.72,
        weekPageHeaderBuilder: customHeaderBuilder,
        eventTileBuilder: (date, events, boundary, startDuration,
                endDuration) =>
            _buildEventTile(
                date, events, boundary, startDuration, endDuration, context),
        weekDayBuilder: (DateTime date) => _buildWeekDay(date),
      ),
    ));
  }

  Widget customHeaderBuilder(DateTime startDate, DateTime endDate) {
    // Return an empty SizedBox, effectively creating no header space
    return const SizedBox.shrink();
  }

  Widget _buildEventTile(
      DateTime date,
      List<CalendarEventData<dynamic>> events,
      Rect boundary,
      DateTime startDuration,
      DateTime endDuration,
      BuildContext context) {
    if (events.isNotEmpty) {
      return ScheduleCalendarTile(
        title: events[0].title,
        description: events[0].description,
        start: events[0].startTime,
        end: events[0].endTime,
        titleStyle: TextStyle(
          fontSize: 8,
          color: events[0].color.accent,
        ),
        totalEvents: events.length,
        padding: const EdgeInsets.all(7.0),
        backgroundColor: events[0].color,
        borderRadius: BorderRadius.circular(6.0),
        buildContext: context,
      );
    } else {
      return Container();
    }
  }

  Widget _buildWeekDay(DateTime date) {
    return Center(
      child: Container(
        width: 40,
        height: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekTitles[date.weekday - 1]),
          ],
        ),
      ),
    );
  }
}
