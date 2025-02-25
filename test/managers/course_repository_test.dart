// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:ets_api_clients/clients.dart';
import 'package:ets_api_clients/exceptions.dart';
import 'package:ets_api_clients/models.dart';
import 'package:ets_api_clients/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';

// Project imports:
import 'package:notredame/core/managers/cache_manager.dart';
import 'package:notredame/core/managers/course_repository.dart';
import 'package:notredame/core/managers/user_repository.dart';
import 'package:notredame/core/services/analytics_service.dart';
import '../helpers.dart';
import '../mock/managers/cache_manager_mock.dart';
import '../mock/managers/user_repository_mock.dart';
import '../mock/services/networking_service_mock.dart';

void main() {
  AnalyticsService analyticsService;
  NetworkingServiceMock networkingService;
  UserRepository userRepository;
  CacheManager cacheManager;

  CourseRepository manager;
  SignetsAPIClient signetsApi;

  final Session session = Session(
      shortName: 'NOW',
      name: 'now',
      startDate: DateTime(2020),
      endDate: DateTime.now().add(const Duration(days: 10)),
      endDateCourses: DateTime(2020),
      startDateRegistration: DateTime(2020),
      deadlineRegistration: DateTime(2020),
      startDateCancellationWithRefund: DateTime(2020),
      deadlineCancellationWithRefund: DateTime(2020),
      deadlineCancellationWithRefundNewStudent: DateTime(2020),
      startDateCancellationWithoutRefundNewStudent: DateTime(2020),
      deadlineCancellationWithoutRefundNewStudent: DateTime(2020),
      deadlineCancellationASEQ: DateTime(2020));

  group("CourseRepository - ", () {
    setUp(() {
      // Setup needed services and managers
      analyticsService = setupAnalyticsServiceMock();
      signetsApi = setupSignetsApiMock();
      userRepository = setupUserRepositoryMock();
      cacheManager = setupCacheManagerMock();
      networkingService = setupNetworkingServiceMock() as NetworkingServiceMock;
      setupLogger();

      manager = CourseRepository();
    });

    tearDown(() {
      clearInteractions(analyticsService);
      unregister<AnalyticsService>();
      clearInteractions(signetsApi);
      unregister<SignetsAPIClient>();
      clearInteractions(userRepository);
      unregister<UserRepository>();
      clearInteractions(cacheManager);
      unregister<CacheManager>();
      clearInteractions(networkingService);
      unregister<NetworkingServiceMock>();
    });

    group("getCoursesActivities - ", () {
      final CourseActivity activity = CourseActivity(
          courseGroup: "GEN101",
          courseName: "Generic course",
          activityName: "TD",
          activityDescription: "Activity description",
          activityLocation: "location",
          startDateTime: DateTime(2020, 1, 1, 18),
          endDateTime: DateTime(2020, 1, 1, 21));

      final List<CourseActivity> activities = [activity];

      const String username = "username";

      setUp(() {
        // Stub a user
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, "password");

        // Stub some sessions
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, [session]);

        // Stub to simulate that the user has an active internet connection
        NetworkingServiceMock.stubHasConnectivity(networkingService);
      });

      test("Activities are loaded from cache.", () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        // Stub the SignetsAPI to return 0 activities
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, []);

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities(fromCacheOnly: true);

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, activities);
        expect(manager.coursesActivities, activities,
            reason: "The list of activities should not be empty");

        verifyInOrder(
            [cacheManager.get(CourseRepository.coursesActivitiesCacheKey)]);
      });

      test("Activities are only loaded from cache.", () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities(fromCacheOnly: true);

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, activities);
        expect(manager.coursesActivities, activities,
            reason: "The list of activities should not be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(userRepository);
      });

      test(
          "Trying to recover activities from cache but an exception is raised.",
          () async {
        // Stub the cache to throw an exception
        CacheManagerMock.stubGetException(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey);

        // Stub the SignetsAPI to return 0 activities
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, []);

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities();

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, isEmpty);
        expect(manager.coursesActivities, isEmpty,
            reason: "The list of activities should be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCoursesActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.coursesActivitiesCacheKey, any)
        ]);

        verify(signetsApi.getSessions(
                username: username, password: anyNamed("password")))
            .called(1);
      });

      test("Doesn't retrieve sessions if they are already loaded", () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        // Stub the SignetsAPI to return 1 activities
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, activities);

        // Load the sessions
        await manager.getSessions();
        expect(manager.sessions, isNotEmpty);
        clearInteractions(cacheManager);
        clearInteractions(userRepository);
        clearInteractions(signetsApi);

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities();

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, activities);
        expect(manager.coursesActivities, activities,
            reason: "The list of activities should not be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCoursesActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.coursesActivitiesCacheKey, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
      });

      test("getSessions fails", () async {
        // Stub SignetsApi to throw an exception
        reset(signetsApi);
        SignetsAPIClientMock.stubGetSessionsException(
            signetsApi as SignetsAPIClientMock, username);

        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        // Stub the SignetsAPI to return 0 activities
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, []);

        expect(manager.coursesActivities, isNull);
        expect(manager.getCoursesActivities(),
            throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.coursesActivities, isEmpty,
            reason: "The list of activities should be empty");

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);
      });

      test("User authentication fails.", () async {
        // Stub the cache to return 0 activities
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode([]));

        // Load the sessions
        await manager.getSessions();
        expect(manager.sessions, isNotEmpty);
        clearInteractions(signetsApi);

        // Stub an authentication error
        reset(userRepository);
        UserRepositoryMock.stubGetPasswordException(
            userRepository as UserRepositoryMock);

        expect(manager.getCoursesActivities(),
            throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.coursesActivities, isEmpty,
            reason:
                "There isn't any activities saved in the cache so the list should be empty");

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(userRepository);
      });

      test(
          "SignetsAPI returns new activities, the old ones should be maintained and the cache updated.",
          () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        final CourseActivity courseActivity = CourseActivity(
            courseGroup: "GEN102",
            courseName: "Generic course",
            activityName: "Another activity name",
            activityDescription: "Activity description",
            activityLocation: "Another location",
            startDateTime: DateTime(2020, 1, 2, 18),
            endDateTime: DateTime(2020, 1, 2, 21));

        // Stub the SignetsAPI to return 2 activities
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock,
            session.shortName,
            [activity, courseActivity]);

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities();

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, [activity, courseActivity]);
        expect(manager.coursesActivities, [activity, courseActivity],
            reason: "The list of activities should not be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCoursesActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.coursesActivitiesCacheKey,
              jsonEncode([activity, courseActivity]))
        ]);
      });

      test(
          "SignetsAPI returns activities that already exists, should avoid duplicata.",
          () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        // Stub the SignetsAPI to return the same activity as the cache
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, activities);

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities();

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, activities);
        expect(manager.coursesActivities, activities,
            reason: "The list of activities should not have duplicata");

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCoursesActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.coursesActivitiesCacheKey,
              jsonEncode(activities))
        ]);
      });

      test(
          "SignetsAPI returns activities that changed (for example class location changed).",
          () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        // Load the sessions
        await manager.getSessions();
        expect(manager.sessions, isNotEmpty);
        clearInteractions(cacheManager);
        clearInteractions(userRepository);
        clearInteractions(signetsApi);

        final changedActivity = CourseActivity(
            courseGroup: activity.courseGroup,
            courseName: activity.courseName,
            activityName: activity.activityName,
            activityDescription: 'Another description',
            activityLocation: 'Changed location',
            startDateTime: activity.startDateTime,
            endDateTime: activity.endDateTime);

        // Stub the SignetsAPI to return the same activity as the cache
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock,
            session.shortName,
            [changedActivity]);

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities();

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, [changedActivity]);
        expect(manager.coursesActivities, [changedActivity],
            reason: "The list of activities should be updated");

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCoursesActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.coursesActivitiesCacheKey,
              jsonEncode([changedActivity]))
        ]);
      });

      test("SignetsAPI raise a exception.", () async {
        // Stub the cache to return no activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode([]));

        // Stub the SignetsAPI to throw an exception
        SignetsAPIClientMock.stubGetCoursesActivitiesException(
            signetsApi as SignetsAPIClientMock, session.shortName,
            exceptionToThrow: const ApiException(prefix: CourseRepository.tag));

        expect(manager.coursesActivities, isNull);
        expect(manager.getCoursesActivities(),
            throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.coursesActivities, isEmpty,
            reason: "The list of activities should be empty");

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCoursesActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);
      });

      test(
          "Cache update fails, should still return the updated list of activities.",
          () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        // Stub the SignetsAPI to return 1 activity
        SignetsAPIClientMock.stubGetCoursesActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, activities);

        CacheManagerMock.stubUpdateException(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey);

        expect(manager.coursesActivities, isNull);
        final List<CourseActivity> results =
            await manager.getCoursesActivities();

        expect(results, isInstanceOf<List<CourseActivity>>());
        expect(results, activities);
        expect(manager.coursesActivities, activities,
            reason: "The list of activities should not be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCoursesActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName)
        ]);
      });

      test("Should force fromCacheOnly mode when user has no connectivity",
          () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesActivitiesCacheKey, jsonEncode(activities));

        //Stub the networkingService to return no connectivity
        reset(networkingService);
        NetworkingServiceMock.stubHasConnectivity(networkingService,
            hasConnectivity: false);

        final activitiesCache = await manager.getCoursesActivities();
        expect(activitiesCache, activities);
      });
    });

    group("getScheduleActivities - ", () {
      final Session session = Session(
          shortName: 'NOW',
          name: 'now',
          startDate: DateTime(2020),
          endDate: DateTime.now().add(const Duration(days: 10)),
          endDateCourses: DateTime(2020),
          startDateRegistration: DateTime(2020),
          deadlineRegistration: DateTime(2020),
          startDateCancellationWithRefund: DateTime(2020),
          deadlineCancellationWithRefund: DateTime(2020),
          deadlineCancellationWithRefundNewStudent: DateTime(2020),
          startDateCancellationWithoutRefundNewStudent: DateTime(2020),
          deadlineCancellationWithoutRefundNewStudent: DateTime(2020),
          deadlineCancellationASEQ: DateTime(2020));

      final ScheduleActivity scheduleActivity = ScheduleActivity(
          courseAcronym: 'GEN101',
          courseGroup: '01',
          dayOfTheWeek: 1,
          day: 'Lundi',
          activityCode: ActivityCode.labEvery2Weeks,
          name: 'Laboratoire aux 2 semaines',
          isPrincipalActivity: false,
          startTime: DateFormat('HH:mm').parse("08:30"),
          endTime: DateFormat('HH:mm').parse("12:30"),
          activityLocation: 'À distance',
          courseTitle: 'Generic title');

      final List<ScheduleActivity> scheduleActivities = [scheduleActivity];

      const String username = "username";

      setUp(() {
        // Stub a user
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, "password");

        // Stub some sessions
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, [session]);

        // Stub to simulate that the user has an active internet connection
        NetworkingServiceMock.stubHasConnectivity(networkingService);
      });

      test("Activities are loaded from cache.", () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(
            cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey,
            jsonEncode(scheduleActivities));

        // Stub the SignetsAPI to return 0 activities
        SignetsAPIClientMock.stubGetScheduleActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, []);

        expect(manager.coursesActivities, isNull);
        final List<ScheduleActivity> results =
            await manager.getScheduleActivities();

        expect(results, isInstanceOf<List<ScheduleActivity>>());
        expect(results, scheduleActivities);
        expect(manager.scheduleActivities, scheduleActivities,
            reason: "The list of activities should not be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getScheduleActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.scheduleActivitiesCacheKey, any)
        ]);
      });

      test("Activities are only loaded from cache.", () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(
            cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey,
            jsonEncode(scheduleActivities));

        expect(manager.scheduleActivities, isNull);
        final List<ScheduleActivity> results =
            await manager.getScheduleActivities(fromCacheOnly: true);

        expect(results, isInstanceOf<List<ScheduleActivity>>());
        expect(results, scheduleActivities);
        expect(manager.scheduleActivities, scheduleActivities,
            reason: "The list of activities should not be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(userRepository);
      });

      test(
          "Trying to recover activities from cache but an exception is raised.",
          () async {
        // Stub the cache to throw an exception
        CacheManagerMock.stubGetException(cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey);

        // Stub the SignetsAPI to return 0 activities
        SignetsAPIClientMock.stubGetScheduleActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, []);

        expect(manager.scheduleActivities, isNull);
        final List<ScheduleActivity> results =
            await manager.getScheduleActivities();

        expect(results, isInstanceOf<List<ScheduleActivity>>());
        expect(results, isEmpty);
        expect(manager.scheduleActivities, isEmpty,
            reason: "The list of activities should be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getScheduleActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.scheduleActivitiesCacheKey, any)
        ]);

        verify(signetsApi.getSessions(
                username: username, password: anyNamed("password")))
            .called(1);
      });

      test("Doesn't retrieve sessions if they are already loaded", () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(
            cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey,
            jsonEncode(scheduleActivities));

        // Stub the SignetsAPI to return 0 activities
        SignetsAPIClientMock.stubGetScheduleActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, []);

        // Load the sessions
        await manager.getSessions();
        expect(manager.sessions, isNotEmpty);
        clearInteractions(cacheManager);
        clearInteractions(userRepository);
        clearInteractions(signetsApi);

        expect(manager.scheduleActivities, isNull);
        final List<ScheduleActivity> results =
            await manager.getScheduleActivities();

        expect(results, isInstanceOf<List<ScheduleActivity>>());
        expect(results, scheduleActivities);
        expect(manager.scheduleActivities, scheduleActivities,
            reason: "The list of activities should not be empty");

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getScheduleActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.scheduleActivitiesCacheKey, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
      });

      test("getSessions fails", () async {
        // Stub SignetsApi to throw an exception
        reset(signetsApi);
        SignetsAPIClientMock.stubGetSessionsException(
            signetsApi as SignetsAPIClientMock, username);

        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(
            cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey,
            jsonEncode(scheduleActivities));

        // Stub the SignetsAPI to return 0 activities
        SignetsAPIClientMock.stubGetScheduleActivities(
            signetsApi as SignetsAPIClientMock, session.shortName, []);

        expect(manager.scheduleActivities, isNull);
        expect(manager.getScheduleActivities(),
            throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.scheduleActivities, isEmpty,
            reason: "The list of activities should be empty");

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);
      });

      test("User authentication fails.", () async {
        // Stub the cache to return 0 activities
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey, jsonEncode([]));

        // Load the sessions
        await manager.getSessions();
        expect(manager.sessions, isNotEmpty);
        clearInteractions(signetsApi);

        // Stub an authentication error
        reset(userRepository);
        UserRepositoryMock.stubGetPasswordException(
            userRepository as UserRepositoryMock);

        expect(manager.getScheduleActivities(),
            throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.scheduleActivities, isEmpty,
            reason:
                "There isn't any activities saved in the cache so the list should be empty");

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
          userRepository.getPassword(),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(userRepository);
      });

      test(
          "SignetsAPI returns activities that already exists, should avoid duplicata.",
          () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(
            cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey,
            jsonEncode(scheduleActivities));

        // Stub the SignetsAPI to return the same activity as the cache
        SignetsAPIClientMock.stubGetScheduleActivities(
            signetsApi as SignetsAPIClientMock,
            session.shortName,
            scheduleActivities);

        expect(manager.scheduleActivities, isNull);
        final List<ScheduleActivity> results =
            await manager.getScheduleActivities();

        expect(results, isInstanceOf<List<ScheduleActivity>>());
        expect(results, scheduleActivities);
        expect(manager.scheduleActivities, scheduleActivities,
            reason: "The list of activities should not have duplicata");

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getScheduleActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          cacheManager.update(CourseRepository.scheduleActivitiesCacheKey,
              jsonEncode(scheduleActivities))
        ]);
      });

      test("SignetsAPI raise a exception.", () async {
        // Stub the cache to return no activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.scheduleActivitiesCacheKey, jsonEncode([]));

        // Stub the SignetsAPI to throw an exception
        SignetsAPIClientMock.stubGetScheduleActivitiesException(
            signetsApi as SignetsAPIClientMock, session.shortName,
            exceptionToThrow: const ApiException(prefix: CourseRepository.tag));

        expect(manager.scheduleActivities, isNull);
        expect(manager.getScheduleActivities(),
            throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.scheduleActivities, isEmpty,
            reason: "The list of activities should be empty");

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.scheduleActivitiesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getScheduleActivities(
              username: username,
              password: anyNamed("password"),
              session: session.shortName),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);
      });
    });
    group("getSessions - ", () {
      final List<Session> sessions = [
        Session(
            shortName: 'H2018',
            name: 'Hiver 2018',
            startDate: DateTime(2018, 1, 4),
            endDate: DateTime(2018, 4, 23),
            endDateCourses: DateTime(2018, 4, 11),
            startDateRegistration: DateTime(2017, 10, 30),
            deadlineRegistration: DateTime(2017, 11, 14),
            startDateCancellationWithRefund: DateTime(2018, 1, 4),
            deadlineCancellationWithRefund: DateTime(2018, 1, 17),
            deadlineCancellationWithRefundNewStudent: DateTime(2018, 1, 31),
            startDateCancellationWithoutRefundNewStudent: DateTime(2018, 2),
            deadlineCancellationWithoutRefundNewStudent: DateTime(2018, 3, 14),
            deadlineCancellationASEQ: DateTime(2018, 1, 31))
      ];

      const String username = "username";
      const String password = "password";

      final MonETSUser user =
          MonETSUser(domain: "ENS", typeUsagerId: 1, username: username);

      setUp(() {
        // Stub to simulate presence of session cache
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode(sessions));

        // Stub SignetsApi answer to test only the cache retrieving
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, []);
        UserRepositoryMock.stubMonETSUser(
            userRepository as UserRepositoryMock, user);
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, password);

        // Stub to simulate that the user has an active internet connection
        NetworkingServiceMock.stubHasConnectivity(networkingService);
      });

      test("Sessions are loaded from cache", () async {
        expect(manager.sessions, isNull);
        final results = await manager.getSessions();

        expect(results, isInstanceOf<List<Session>>());
        expect(results, sessions);
        expect(manager.sessions, sessions,
            reason: 'The sessions list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.sessionsCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getSessions(username: username, password: password),
          cacheManager.update(
              CourseRepository.sessionsCacheKey, jsonEncode(sessions))
        ]);
      });

      test("Trying to load sessions from cache but cache doesn't exist",
          () async {
        // Stub to simulate an exception when trying to get the sessions from the cache
        reset(cacheManager as CacheManagerMock);
        CacheManagerMock.stubGetException(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey);

        expect(manager.sessions, isNull);
        final results = await manager.getSessions();

        expect(results, isInstanceOf<List<Session>>());
        expect(results, []);
        expect(manager.sessions, []);

        verifyInOrder([
          cacheManager.get(CourseRepository.sessionsCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getSessions(username: username, password: password),
          cacheManager.update(CourseRepository.sessionsCacheKey, jsonEncode([]))
        ]);
      });

      test("SignetsAPI return another session", () async {
        // Stub to simulate presence of session cache
        reset(cacheManager as CacheManagerMock);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));

        // Stub SignetsApi answer to test only the cache retrieving
        reset(signetsApi as SignetsAPIClientMock);
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, sessions);

        expect(manager.sessions, isNull);
        final results = await manager.getSessions();

        expect(results, isInstanceOf<List<Session>>());
        expect(results, sessions);
        expect(manager.sessions, sessions,
            reason: 'The sessions list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.sessionsCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getSessions(username: username, password: password),
          cacheManager.update(
              CourseRepository.sessionsCacheKey, jsonEncode(sessions))
        ]);
      });

      test("SignetsAPI return a session that already exists", () async {
        // Stub SignetsApi answer to test only the cache retrieving
        reset(signetsApi as SignetsAPIClientMock);
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, sessions);

        expect(manager.sessions, isNull);
        final results = await manager.getSessions();

        expect(results, isInstanceOf<List<Session>>());
        expect(results, sessions);
        expect(manager.sessions, sessions,
            reason: 'The sessions list should not have any duplicata..');

        verifyInOrder([
          cacheManager.get(CourseRepository.sessionsCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getSessions(username: username, password: password),
          cacheManager.update(
              CourseRepository.sessionsCacheKey, jsonEncode(sessions))
        ]);
      });

      test("SignetsAPI return an exception", () async {
        // Stub to simulate presence of session cache
        reset(cacheManager as CacheManagerMock);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));

        // Stub SignetsApi answer to test only the cache retrieving
        SignetsAPIClientMock.stubGetSessionsException(
            signetsApi as SignetsAPIClientMock, username);

        expect(manager.sessions, isNull);
        expect(manager.getSessions(), throwsA(isInstanceOf<ApiException>()));
        expect(manager.sessions, [],
            reason: 'The session list should be empty');

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.sessionsCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getSessions(username: username, password: password),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNever(
            cacheManager.update(CourseRepository.sessionsCacheKey, any));
      });

      test("Cache update fail", () async {
        // Stub to simulate presence of session cache
        reset(cacheManager as CacheManagerMock);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));

        // Stub to simulate exception when updating cache
        CacheManagerMock.stubUpdateException(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey);

        // Stub SignetsApi answer to test only the cache retrieving
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, sessions);

        expect(manager.sessions, isNull);
        final results = await manager.getSessions();

        expect(results, isInstanceOf<List<Session>>());
        expect(results, sessions);
        expect(manager.sessions, sessions,
            reason:
                'The sessions list should now be loaded even if the caching fails.');

        verifyInOrder([
          cacheManager.get(CourseRepository.sessionsCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getSessions(username: username, password: password)
        ]);
      });

      test("UserRepository return an exception", () async {
        // Stub to simulate presence of session cache
        reset(cacheManager as CacheManagerMock);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));

        // Stub UserRepository to throw a exception
        UserRepositoryMock.stubGetPasswordException(
            userRepository as UserRepositoryMock);

        expect(manager.sessions, isNull);
        expect(manager.getSessions(), throwsA(isInstanceOf<ApiException>()));
        expect(manager.sessions, [],
            reason: 'The session list should be empty');

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.sessionsCacheKey),
          userRepository.getPassword(),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNever(signetsApi.getSessions(
            username: anyNamed("username"), password: anyNamed("password")));
        verifyNever(
            cacheManager.update(CourseRepository.sessionsCacheKey, any));
      });

      test("Should not try to fetch from signets when offline", () async {
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode(sessions));

        //Stub the networkingService to return no connectivity
        reset(networkingService);
        NetworkingServiceMock.stubHasConnectivity(networkingService,
            hasConnectivity: false);

        final sessionsCache = await manager.getSessions();
        expect(sessionsCache, sessions);
        verifyNever(
            signetsApi.getSessions(username: username, password: password));
      });
    });

    group("activeSessions - ", () {
      const String username = "username";
      const String password = "password";

      final now = DateTime.now();

      final Session oldSession = Session(
          shortName: 'H2018',
          name: 'Hiver 2018',
          startDate: DateTime(2018, 1, 4),
          endDate: DateTime(2018, 4, 23),
          endDateCourses: DateTime(2018, 4, 11),
          startDateRegistration: DateTime(2017, 10, 30),
          deadlineRegistration: DateTime(2017, 11, 14),
          startDateCancellationWithRefund: DateTime(2018, 1, 4),
          deadlineCancellationWithRefund: DateTime(2018, 1, 17),
          deadlineCancellationWithRefundNewStudent: DateTime(2018, 1, 31),
          startDateCancellationWithoutRefundNewStudent: DateTime(2018, 2),
          deadlineCancellationWithoutRefundNewStudent: DateTime(2018, 3, 14),
          deadlineCancellationASEQ: DateTime(2018, 1, 31));

      test("current session ends today", () async {
        final Session active = Session(
            shortName: 'NOW',
            name: 'now',
            startDate: DateTime(2020),
            endDate: DateTime(now.year, now.month, now.day),
            endDateCourses: DateTime(2020),
            startDateRegistration: DateTime(2020),
            deadlineRegistration: DateTime(2020),
            startDateCancellationWithRefund: DateTime(2020),
            deadlineCancellationWithRefund: DateTime(2020),
            deadlineCancellationWithRefundNewStudent: DateTime(2020),
            startDateCancellationWithoutRefundNewStudent: DateTime(2020),
            deadlineCancellationWithoutRefundNewStudent: DateTime(2020),
            deadlineCancellationASEQ: DateTime(2020));

        final sessions = [oldSession, active];

        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, sessions);
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, password);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode(sessions));
        NetworkingServiceMock.stubHasConnectivity(networkingService);

        await manager.getSessions();

        expect(manager.activeSessions, [active]);
      });

      test("current session ended yesterday", () async {
        final Session old = Session(
            shortName: 'NOW',
            name: 'now',
            startDate: DateTime(2020),
            endDate: DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 1)),
            endDateCourses: DateTime(2020),
            startDateRegistration: DateTime(2020),
            deadlineRegistration: DateTime(2020),
            startDateCancellationWithRefund: DateTime(2020),
            deadlineCancellationWithRefund: DateTime(2020),
            deadlineCancellationWithRefundNewStudent: DateTime(2020),
            startDateCancellationWithoutRefundNewStudent: DateTime(2020),
            deadlineCancellationWithoutRefundNewStudent: DateTime(2020),
            deadlineCancellationASEQ: DateTime(2020));

        final sessions = [oldSession, old];

        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, sessions);
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, password);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode(sessions));
        NetworkingServiceMock.stubHasConnectivity(networkingService);

        await manager.getSessions();

        expect(manager.activeSessions, []);
      });

      test("current session ends tomorrow", () async {
        final Session active = Session(
            shortName: 'NOW',
            name: 'now',
            startDate: DateTime(2020),
            endDate: DateTime(now.year, now.month, now.day)
                .add(const Duration(days: 1)),
            endDateCourses: DateTime(2020),
            startDateRegistration: DateTime(2020),
            deadlineRegistration: DateTime(2020),
            startDateCancellationWithRefund: DateTime(2020),
            deadlineCancellationWithRefund: DateTime(2020),
            deadlineCancellationWithRefundNewStudent: DateTime(2020),
            startDateCancellationWithoutRefundNewStudent: DateTime(2020),
            deadlineCancellationWithoutRefundNewStudent: DateTime(2020),
            deadlineCancellationASEQ: DateTime(2020));

        final sessions = [oldSession, active];

        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, sessions);
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, password);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode(sessions));
        NetworkingServiceMock.stubHasConnectivity(networkingService);

        await manager.getSessions();

        expect(manager.activeSessions, [active]);
      });

      test("there is no session", () async {
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, []);
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, password);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));
        NetworkingServiceMock.stubHasConnectivity(networkingService);

        await manager.getSessions();

        expect(manager.activeSessions, []);
      });

      test("there is no session loaded", () async {
        expect(manager.activeSessions, []);
      });
    });

    group("getCourses - ", () {
      final Course courseWithGrade = Course(
          acronym: 'GEN101',
          group: '02',
          session: 'H2020',
          programCode: '999',
          grade: 'C+',
          numberOfCredits: 3,
          title: 'Cours générique',
          review: CourseReview(
              acronym: 'GEN101',
              group: '02',
              teacherName: 'April, Alain',
              startAt: DateTime(2020),
              endAt: DateTime(2020, 1, 1, 23, 59),
              isCompleted: true,
              type: 'Cours'));
      final Course courseWithGradeDuplicate = Course(
          acronym: 'GEN101',
          group: '02',
          session: 'É2020',
          programCode: '999',
          grade: 'C+',
          numberOfCredits: 3,
          title: 'Cours générique');

      final Course courseWithoutGrade = Course(
          acronym: 'GEN101',
          group: '02',
          session: 'H2020',
          programCode: '999',
          numberOfCredits: 3,
          title: 'Cours générique',
          summary: CourseSummary(
              currentMark: 5,
              currentMarkInPercent: 50,
              markOutOf: 10,
              passMark: 6,
              standardDeviation: 2.3,
              median: 4.5,
              percentileRank: 99,
              evaluations: [
                CourseEvaluation(
                    courseGroup: 'GEN101-02',
                    title: 'Test',
                    correctedEvaluationOutOf: "20",
                    weight: 10,
                    published: false,
                    teacherMessage: '',
                    ignore: false)
              ]));
      final Course courseWithoutGradeAndSummaryAndEvaluation = Course(
          acronym: 'GEN101',
          group: '02',
          session: 'H2020',
          programCode: '999',
          numberOfCredits: 3,
          title: 'Cours générique');

      const String username = "username";
      const String password = "password";

      setUp(() {
        // Stub a user
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, "password");

        // Stub some sessions
        SignetsAPIClientMock.stubGetSessions(
            signetsApi as SignetsAPIClientMock, username, [session]);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.sessionsCacheKey, jsonEncode([]));

        // Stub to simulate that the user has an active internet connection
        NetworkingServiceMock.stubHasConnectivity(networkingService);
      });

      test("Courses are loaded from cache and cache is updated", () async {
        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseWithGrade]);
        SignetsAPIClientMock.stubGetCourseReviews(
            signetsApi as SignetsAPIClientMock, username);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([courseWithGrade]));

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [courseWithGrade]);
        expect(manager.courses, [courseWithGrade],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseWithGrade]))
        ]);
      });

      test("Courses are only loaded from cache", () async {
        expect(manager.courses, isNull);
        CacheManagerMock.stubGet(
            cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey,
            jsonEncode([
              courseWithGrade,
              courseWithoutGrade,
              courseWithoutGradeAndSummaryAndEvaluation
            ]));
        final results = await manager.getCourses(fromCacheOnly: true);

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [
          courseWithGrade,
          courseWithoutGrade,
          courseWithoutGradeAndSummaryAndEvaluation
        ]);
        expect(
            manager.courses,
            [
              courseWithGrade,
              courseWithoutGrade,
              courseWithoutGradeAndSummaryAndEvaluation
            ],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([cacheManager.get(CourseRepository.coursesCacheKey)]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(cacheManager);
        verifyNoMoreInteractions(userRepository);
      });

      test("Signets return a updated version of a course", () async {
        final Course courseFetched = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            programCode: '999',
            grade: 'A+',
            numberOfCredits: 3,
            title: 'Cours générique');

        CacheManagerMock.stubGet(
            cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey,
            jsonEncode([courseWithGrade, courseWithGradeDuplicate]));
        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseFetched, courseWithGradeDuplicate]);
        SignetsAPIClientMock.stubGetCourseReviews(
            signetsApi as SignetsAPIClientMock, username);

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [courseFetched, courseWithGradeDuplicate]);
        expect(manager.courses, [courseFetched, courseWithGradeDuplicate],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          cacheManager.update(CourseRepository.coursesCacheKey,
              jsonEncode([courseFetched, courseWithGradeDuplicate]))
        ]);
      });

      test("Trying to recover courses from cache failed (exception raised)",
          () async {
        expect(manager.courses, isNull);
        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username);
        CacheManagerMock.stubGetException(
            cacheManager as CacheManagerMock, CourseRepository.coursesCacheKey);

        final results = await manager.getCourses(fromCacheOnly: true);

        expect(results, isInstanceOf<List<Course>>());
        expect(results, []);
        expect(manager.courses, [],
            reason: 'The courses list should be empty.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(cacheManager);
      });

      test("Signets raised an exception while trying to recover courses",
          () async {
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));
        SignetsAPIClientMock.stubGetCoursesException(
            signetsApi as SignetsAPIClientMock, username);

        expect(manager.courses, isNull);

        expect(manager.getCourses(), throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.courses, []);

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(cacheManager);
        verifyNoMoreInteractions(userRepository);
      });

      test("Student dropped out of a course, the course should disappear",
          () async {
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([courseWithoutGrade]));
        SignetsAPIClientMock.stubGetCoursesException(
            signetsApi as SignetsAPIClientMock, username);

        expect(manager.courses, isNull);

        expect(manager.getCourses(), throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.courses, []);

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(cacheManager);
        verifyNoMoreInteractions(userRepository);
      });

      test("Courses don't have grade so getCourseSummary is called", () async {
        final Course courseFetched = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique');
        final CourseSummary summary = CourseSummary(
            currentMark: 5,
            currentMarkInPercent: 50,
            markOutOf: 10,
            passMark: 6,
            standardDeviation: 2.3,
            median: 4.5,
            percentileRank: 99,
            evaluations: []);
        final Course courseUpdated = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique',
            summary: summary);

        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseFetched]);
        SignetsAPIClientMock.stubGetCourseReviews(
            signetsApi as SignetsAPIClientMock, username);
        SignetsAPIClientMock.stubGetCourseSummary(
            signetsApi as SignetsAPIClientMock, username, courseFetched,
            summaryToReturn: summary);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [courseUpdated]);
        expect(manager.courses, [courseUpdated],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          signetsApi.getCourseSummary(
              username: username, password: password, course: courseFetched),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseUpdated]))
        ]);
      });

      test("getCourseSummary fails", () async {
        final Course courseFetched = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique');

        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseFetched]);
        SignetsAPIClientMock.stubGetCourseReviews(
            signetsApi as SignetsAPIClientMock, username);
        SignetsAPIClientMock.stubGetCourseSummaryException(
            signetsApi as SignetsAPIClientMock, username, courseFetched);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [courseFetched]);
        expect(manager.courses, [courseFetched],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          signetsApi.getCourseSummary(
              username: username, password: password, course: courseFetched),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseFetched]))
        ]);
      });

      test("Cache update fails, should still return the list of courses",
          () async {
        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseWithGrade]);
        SignetsAPIClientMock.stubGetCourseReviews(
            signetsApi as SignetsAPIClientMock, username);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([courseWithGrade]));
        CacheManagerMock.stubUpdateException(
            cacheManager as CacheManagerMock, CourseRepository.coursesCacheKey);

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [courseWithGrade]);
        expect(manager.courses, [courseWithGrade],
            reason:
                'The courses list should now be loaded even if the caching fails.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseWithGrade]))
        ]);
      });

      test("UserRepository return an exception", () async {
        // Stub to simulate presence of session cache
        reset(cacheManager as CacheManagerMock);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));

        // Stub UserRepository to throw a exception
        UserRepositoryMock.stubGetPasswordException(
            userRepository as UserRepositoryMock);

        expect(manager.sessions, isNull);
        expect(manager.getCourses(), throwsA(isInstanceOf<ApiException>()));

        await untilCalled(networkingService.hasConnectivity());
        expect(manager.courses, [], reason: 'The courses list should be empty');

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNever(signetsApi.getCourses(
            username: anyNamed("username"), password: anyNamed("password")));
        verifyNever(cacheManager.update(CourseRepository.coursesCacheKey, any));
      });

      test("Should force fromCacheOnly mode when user has no connectivity",
          () async {
        // Stub the cache to return 1 activity
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([courseWithGrade]));

        //Stub the networkingService to return no connectivity
        reset(networkingService);
        NetworkingServiceMock.stubHasConnectivity(networkingService,
            hasConnectivity: false);

        final coursesCache = await manager.getCourses();
        expect(coursesCache, [courseWithGrade]);
      });

      test("there is no evaluation for a course, should return null", () async {
        final Course courseFetched = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            grade: 'A+',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique');

        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseFetched]);
        SignetsAPIClientMock.stubGetCourseReviews(
            signetsApi as SignetsAPIClientMock, username,
            session: session);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [courseFetched]);
        expect(manager.courses, [courseFetched],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          signetsApi.getCourseReviews(
              username: username, password: password, session: session),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseFetched]))
        ]);
      });

      test("there is an evaluation for a course, course should be updated",
          () async {
        final Course courseFetched = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'NOW',
            grade: 'A+',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique');

        final CourseReview review = CourseReview(
            acronym: 'GEN101',
            group: '02',
            teacherName: 'April, Alain',
            startAt: DateTime(2021, 03, 19),
            endAt: DateTime(2021, 03, 28, 23, 59),
            type: 'Cours',
            isCompleted: true);

        final Course updated = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'NOW',
            grade: 'A+',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique',
            review: review);

        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseFetched]);
        SignetsAPIClientMock.stubGetCourseReviews(
            signetsApi as SignetsAPIClientMock, username,
            session: session, reviewsToReturn: [review]);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [updated]);
        expect(manager.courses, [updated],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          signetsApi.getCourseReviews(
              username: username, password: password, session: session),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([updated]))
        ]);
      });

      test("_getCourseReviewss fails", () async {
        final Course courseFetched = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            grade: 'A+',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique');

        SignetsAPIClientMock.stubGetCourses(
            signetsApi as SignetsAPIClientMock, username,
            coursesToReturn: [courseFetched]);
        SignetsAPIClientMock.stubGetCourseReviewsException(
            signetsApi as SignetsAPIClientMock, username,
            session: session);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));

        expect(manager.courses, isNull);
        final results = await manager.getCourses();

        expect(results, isInstanceOf<List<Course>>());
        expect(results, [courseFetched]);
        expect(manager.courses, [courseFetched],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          cacheManager.get(CourseRepository.coursesCacheKey),
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourses(username: username, password: password),
          signetsApi.getCourseReviews(
              username: username, password: password, session: session),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseFetched]))
        ]);
      });
    });

    group("getCourseSummary - ", () {
      Course course;

      Course courseUpdated;

      const String username = "username";
      const String password = "password";

      setUp(() {
        // Stub a user
        UserRepositoryMock.stubMonETSUser(userRepository as UserRepositoryMock,
            MonETSUser(domain: null, typeUsagerId: null, username: username));
        UserRepositoryMock.stubGetPassword(
            userRepository as UserRepositoryMock, "password");

        // Reset models
        course = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique');
        courseUpdated = Course(
            acronym: 'GEN101',
            group: '02',
            session: 'H2020',
            programCode: '999',
            numberOfCredits: 3,
            title: 'Cours générique',
            summary: CourseSummary(
                currentMark: 5,
                currentMarkInPercent: 50,
                markOutOf: 10,
                passMark: 6,
                standardDeviation: 2.3,
                median: 4.5,
                percentileRank: 99,
                evaluations: [
                  CourseEvaluation(
                      courseGroup: 'GEN101-02',
                      title: 'Test',
                      correctedEvaluationOutOf: "20",
                      weight: 10,
                      published: false,
                      teacherMessage: '',
                      ignore: false)
                ]));

        // Stub to simulate that the user has an active internet connection
        NetworkingServiceMock.stubHasConnectivity(networkingService);
      });

      test("CourseSummary is fetched and cache is updated", () async {
        SignetsAPIClientMock.stubGetCourseSummary(
            signetsApi as SignetsAPIClientMock, username, course,
            summaryToReturn: courseUpdated.summary);

        expect(manager.courses, isNull);
        final results = await manager.getCourseSummary(course);

        expect(results, isInstanceOf<Course>());
        expect(results, courseUpdated);
        expect(manager.courses, [courseUpdated],
            reason: 'The courses list should now be loaded.');

        verifyInOrder([
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourseSummary(
              username: username, password: password, course: course),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseUpdated]))
        ]);
      });

      test("Course is updated on the repository", () async {
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([course]));
        SignetsAPIClientMock.stubGetCourseSummary(
            signetsApi as SignetsAPIClientMock, username, course,
            summaryToReturn: courseUpdated.summary);

        // Load a course
        await manager.getCourses(fromCacheOnly: true);

        clearInteractions(cacheManager);
        clearInteractions(signetsApi);
        clearInteractions(userRepository);

        expect(manager.courses, [course]);

        final results = await manager.getCourseSummary(course);

        expect(results, isInstanceOf<Course>());
        expect(results, courseUpdated);
        expect(manager.courses, [courseUpdated],
            reason: 'The courses list should now be updated.');

        verifyInOrder([
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourseSummary(
              username: username, password: password, course: course),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseUpdated]))
        ]);
      });

      test("Signets raised an exception while trying to recover summary",
          () async {
        SignetsAPIClientMock.stubGetCourseSummaryException(
            signetsApi as SignetsAPIClientMock, username, course);

        expect(manager.courses, isNull);

        expect(manager.getCourseSummary(course),
            throwsA(isInstanceOf<ApiException>()));
        expect(manager.courses, isNull);

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourseSummary(
              username: username, password: password, course: course),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(cacheManager);
        verifyNoMoreInteractions(userRepository);
      });

      test(
          "Cache update fails, should still return the course with its summary",
          () async {
        SignetsAPIClientMock.stubGetCourseSummary(
            signetsApi as SignetsAPIClientMock, username, course,
            summaryToReturn: courseUpdated.summary);
        CacheManagerMock.stubUpdateException(
            cacheManager as CacheManagerMock, CourseRepository.coursesCacheKey);

        expect(manager.courses, isNull);
        final results = await manager.getCourseSummary(course);

        expect(results, isInstanceOf<Course>());
        expect(results, courseUpdated);
        expect(manager.courses, [courseUpdated],
            reason:
                'The courses list should now be loaded even if the caching fails.');

        verifyInOrder([
          userRepository.getPassword(),
          userRepository.monETSUser,
          signetsApi.getCourseSummary(
              username: username, password: password, course: course),
          cacheManager.update(
              CourseRepository.coursesCacheKey, jsonEncode([courseUpdated]))
        ]);
      });

      test("UserRepository return an exception", () async {
        // Stub to simulate presence of session cache
        reset(cacheManager as CacheManagerMock);
        CacheManagerMock.stubGet(cacheManager as CacheManagerMock,
            CourseRepository.coursesCacheKey, jsonEncode([]));

        // Stub UserRepository to throw a exception
        UserRepositoryMock.stubGetPasswordException(
            userRepository as UserRepositoryMock);

        expect(manager.sessions, isNull);
        expect(manager.getCourseSummary(course),
            throwsA(isInstanceOf<ApiException>()));
        expect(manager.courses, isNull);

        await untilCalled(
            analyticsService.logError(CourseRepository.tag, any, any, any));

        verifyInOrder([
          userRepository.getPassword(),
          analyticsService.logError(CourseRepository.tag, any, any, any)
        ]);

        verifyNoMoreInteractions(signetsApi);
        verifyNoMoreInteractions(cacheManager);
      });

      test("Should not try to update course summary when offline", () async {
        //Stub the networkingService to return no connectivity
        reset(networkingService);
        NetworkingServiceMock.stubHasConnectivity(networkingService,
            hasConnectivity: false);

        final results = await manager.getCourseSummary(course);
        expect(results, course);
        verifyNever(signetsApi.getCourseSummary(
            username: username, password: password, course: course));
      });
    });
  });
}
