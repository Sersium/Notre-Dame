// Package imports:
import 'package:ets_api_clients/models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Project imports:
import 'package:notredame/core/constants/router_paths.dart';
import 'package:notredame/core/managers/cache_manager.dart';
import 'package:notredame/core/managers/course_repository.dart';
import 'package:notredame/core/managers/settings_manager.dart';
import 'package:notredame/core/managers/user_repository.dart';
import 'package:notredame/core/services/navigation_service.dart';
import 'package:notredame/core/services/preferences_service.dart';
import 'package:notredame/core/services/remote_config_service.dart';
import 'package:notredame/core/viewmodels/more_viewmodel.dart';
import '../helpers.dart';
import '../mock/managers/cache_manager_mock.dart';
import '../mock/managers/course_repository_mock.dart';
import '../mock/managers/settings_manager_mock.dart';
import '../mock/managers/user_repository_mock.dart';
import '../mock/services/remote_config_service_mock.dart';

void main() {
  // Needed to support FlutterToast.
  TestWidgetsFlutterBinding.ensureInitialized();

  CacheManagerMock cacheManagerMock;
  SettingsManagerMock settingsManagerMock;
  CourseRepositoryMock courseRepositoryMock;
  PreferencesService preferenceService;
  RemoteConfigService remoteConfigService;
  UserRepositoryMock userRepositoryMock;
  NavigationService navigationService;

  AppIntl appIntl;
  MoreViewModel viewModel;

  final List<Session> sessions = [
    Session(
        name: 'Hivers 2XXX',
        shortName: 'H1',
        deadlineCancellationASEQ: null,
        deadlineCancellationWithoutRefundNewStudent: null,
        deadlineCancellationWithRefund: null,
        deadlineCancellationWithRefundNewStudent: null,
        deadlineRegistration: null,
        startDate: null,
        startDateCancellationWithoutRefundNewStudent: null,
        startDateCancellationWithRefund: null,
        startDateRegistration: null,
        endDate: null,
        endDateCourses: null),
  ];

  final List<CourseActivity> coursesActivities = [
    CourseActivity(
        courseName: 'sample course',
        courseGroup: '',
        activityName: '',
        activityDescription: '',
        activityLocation: '',
        startDateTime: null,
        endDateTime: null),
  ];

  final List<Course> courses = [
    Course(
        acronym: "ABC123",
        title: "testCourse",
        group: "09",
        session: "H2021",
        programCode: "XYZ",
        numberOfCredits: 3),
  ];

  /// Verify all the required functions that are called from the logout function
  void verifyEveryFunctionsInLogout() {
    verifyInOrder([
      // Check if the cacheManager has been emptied out
      cacheManagerMock.empty(),
      // Check if preference manager is clear
      preferenceService.clearWithoutPersistentKey(),
      // Check if user repository logOut is called
      userRepositoryMock.logOut(),
      // Check if the settings manager has reset lang and theme and notified his listener
      settingsManagerMock.resetLanguageAndThemeMode(),
    ]);
    verifyNoMoreInteractions(cacheManagerMock);
    verifyNoMoreInteractions(preferenceService);
    verifyNoMoreInteractions(userRepositoryMock);
    verifyNoMoreInteractions(settingsManagerMock);

    // Make sure that the registered cache
    expect(courseRepositoryMock.sessions.length, 0,
        reason: 'has emptied out the sessions list');
    expect(courseRepositoryMock.coursesActivities.length, 0,
        reason: 'has emptied out the courseActivities list');
    expect(courseRepositoryMock.courses.length, 0,
        reason: 'has emptied out the courses list');

    // Check if navigation has been rerouted to login page
    verifyInOrder([
      navigationService.pushNamedAndRemoveUntil(
          RouterPaths.login, RouterPaths.chooseLanguage)
    ]);

    verifyNoMoreInteractions(navigationService);
  }

  group('MoreViewModel - ', () {
    setUp(() async {
      cacheManagerMock = setupCacheManagerMock() as CacheManagerMock;
      settingsManagerMock = setupSettingsManagerMock() as SettingsManagerMock;
      courseRepositoryMock =
          setupCourseRepositoryMock() as CourseRepositoryMock;
      remoteConfigService = setupRemoteConfigServiceMock();
      preferenceService = setupPreferencesServiceMock();
      userRepositoryMock = setupUserRepositoryMock() as UserRepositoryMock;
      navigationService = setupNavigationServiceMock();
      appIntl = await setupAppIntl();
      setupLogger();

      viewModel = MoreViewModel(intl: appIntl);

      CourseRepositoryMock.stubCourses(courseRepositoryMock, toReturn: courses);
      CourseRepositoryMock.stubSessions(courseRepositoryMock,
          toReturn: sessions);
      CourseRepositoryMock.stubCoursesActivities(courseRepositoryMock,
          toReturn: coursesActivities);
      RemoteConfigServiceMock.stubGetPrivacyPolicyEnabled(
          remoteConfigService as RemoteConfigServiceMock);
    });

    tearDown(() {
      unregister<CacheManager>();
      unregister<SettingsManager>();
      unregister<CourseRepository>();
      unregister<PreferencesService>();
      unregister<UserRepository>();
      unregister<NavigationService>();
    });

    group('logout - ', () {
      test('If the correct function have been called when logout occur',
          () async {
        RemoteConfigServiceMock.stubGetPrivacyPolicyEnabled(
            remoteConfigService as RemoteConfigServiceMock,
            toReturn: false);
        setupFlutterToastMock();
        UserRepositoryMock.stubLogOut(userRepositoryMock);

        await viewModel.logout();

        verifyEveryFunctionsInLogout();
      });

      test(
          'If an error occur from the cache manager that the logout function finishes out',
          () async {
        RemoteConfigServiceMock.stubGetPrivacyPolicyEnabled(
            remoteConfigService as RemoteConfigServiceMock,
            toReturn: false);
        setupFlutterToastMock();
        CacheManagerMock.stubEmptyException(cacheManagerMock);
        UserRepositoryMock.stubLogOut(userRepositoryMock);

        await viewModel.logout();

        verifyEveryFunctionsInLogout();
      });
    });
  });
}
