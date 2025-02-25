// Package imports:
import 'package:ets_api_clients/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Project imports:
import 'package:notredame/core/constants/programs_credits.dart';
import 'package:notredame/core/managers/settings_manager.dart';
import 'package:notredame/core/managers/user_repository.dart';
import 'package:notredame/core/viewmodels/profile_viewmodel.dart';
import '../helpers.dart';
import '../mock/managers/user_repository_mock.dart';

UserRepository userRepository;
SettingsManager settingsManager;
ProfileViewModel viewModel;

void main() {
  // Needed to support FlutterToast.
  TestWidgetsFlutterBinding.ensureInitialized();
  final Program program1 = Program(
      name: 'program1',
      code: '0000',
      average: '0.00',
      accumulatedCredits: '99',
      registeredCredits: '99',
      completedCourses: '99',
      failedCourses: '0',
      equivalentCourses: '0',
      status: 'Actif');
  final Program program2 = Program(
      name: 'program2',
      code: '0001',
      average: '0.00',
      accumulatedCredits: '99',
      registeredCredits: '99',
      completedCourses: '99',
      failedCourses: '0',
      equivalentCourses: '0',
      status: 'Actif');
  final Program program3 = Program(
      name: 'program3',
      code: '0002',
      average: '0.00',
      accumulatedCredits: '99',
      registeredCredits: '99',
      completedCourses: '99',
      failedCourses: '99',
      equivalentCourses: '99',
      status: 'Actif');

  final List<Program> programs = [program1, program2, program3];

  final ProfileStudent info = ProfileStudent(
      balance: '99.99',
      firstName: 'John',
      lastName: 'Doe',
      permanentCode: 'DOEJ00000000');

  group("ProfileViewModel - ", () {
    setUp(() async {
      // Setting up mocks
      userRepository = setupUserRepositoryMock();
      setupAnalyticsServiceMock();

      viewModel = ProfileViewModel(intl: await setupAppIntl());
    });

    tearDown(() {
      unregister<UserRepository>();
    });

    group("futureToRun - ", () {
      test(
          "first load from cache then call SignetsAPI to get the latest events",
          () async {
        UserRepositoryMock.stubGetInfo(userRepository as UserRepositoryMock);
        UserRepositoryMock.stubGetPrograms(
            userRepository as UserRepositoryMock);

        expect(await viewModel.futureToRun(), []);

        verifyInOrder([
          userRepository.getInfo(fromCacheOnly: true),
          userRepository.getPrograms(fromCacheOnly: true),
          userRepository.getInfo(),
        ]);

        verifyNoMoreInteractions(userRepository);
      });

      test("Signets throw an error while trying to get new events", () async {
        setupFlutterToastMock();
        UserRepositoryMock.stubGetInfo(userRepository as UserRepositoryMock,
            fromCacheOnly: true);
        UserRepositoryMock.stubGetInfoException(
            userRepository as UserRepositoryMock,
            fromCacheOnly: false);
        UserRepositoryMock.stubGetPrograms(userRepository as UserRepositoryMock,
            fromCacheOnly: true);
        UserRepositoryMock.stubGetProgramsException(
            userRepository as UserRepositoryMock,
            fromCacheOnly: false);

        expect(await viewModel.futureToRun(), [],
            reason: "Even if SignetsAPI fails we should receives a list.");

        verifyInOrder([
          userRepository.getInfo(fromCacheOnly: true),
          userRepository.getPrograms(fromCacheOnly: true),
          userRepository.getInfo(),
        ]);

        verifyNoMoreInteractions(userRepository);
      });
    });

    group("info - ", () {
      test("build the info", () async {
        UserRepositoryMock.stubProfileStudent(
            userRepository as UserRepositoryMock,
            toReturn: info);

        expect(viewModel.profileStudent, info);

        verify(userRepository.info).called(1);

        verifyNoMoreInteractions(userRepository);
      });
    });

    group("programs - ", () {
      test("build the list of programs", () async {
        UserRepositoryMock.stubPrograms(userRepository as UserRepositoryMock,
            toReturn: programs);

        expect(viewModel.programList, programs);

        verify(userRepository.programs).called(2);

        verifyNoMoreInteractions(userRepository);
      });
    });

    group("programProgression - ", () {
      test("calculates program progression correctly", () {
        // Create a list of programs for testing
        final List<Program> testPrograms = [
          Program(
            name: 'Program A',
            code: '7625', // Program code with matching entry in ProgramCredits
            average: '3.50',
            accumulatedCredits: '30',
            registeredCredits: '60',
            completedCourses: '10',
            failedCourses: '0',
            equivalentCourses: '0',
            status: 'Actif',
          ),
          Program(
            name: 'Program B',
            code: '7694', // Program code with matching entry in ProgramCredits
            average: '3.20',
            accumulatedCredits: '45',
            registeredCredits: '90',
            completedCourses: '20',
            failedCourses: '5',
            equivalentCourses: '0',
            status: 'Actif',
          ),
        ];

        UserRepositoryMock.stubPrograms(userRepository as UserRepositoryMock,
            toReturn: testPrograms);

        // Create an instance of ProgramCredits
        final ProgramCredits programCredits = ProgramCredits();

        // Calculate the program progression
        final double progression = viewModel.programProgression;

        // Calculate the expected progression based on the defined ProgramCredits
        final double expectedProgression =
            (45 / programCredits.programsCredits['7694'] * 100).roundToDouble();

        // Verify that the calculated progression matches the expected value
        expect(progression, expectedProgression);
      });

      test("handles no matching program code", () {
        // Create a list of programs with no matching program code
        final List<Program> testPrograms = [
          Program(
            name: 'Program X',
            code:
                '9999', // Program code with no matching entry in ProgramCredits
            average: '3.00',
            accumulatedCredits: '20',
            registeredCredits: '40',
            completedCourses: '5',
            failedCourses: '2',
            equivalentCourses: '0',
            status: 'Actif',
          ),
        ];

        UserRepositoryMock.stubPrograms(userRepository as UserRepositoryMock,
            toReturn: testPrograms);

        // Calculate the program progression
        final double progression = viewModel.programProgression;

        // The expected progression should be 0 when there is no matching program code
        expect(progression, 0.0);
      });
    });

    group('refresh -', () {
      test('Call SignetsAPI to get the user info and programs', () async {
        UserRepositoryMock.stubProfileStudent(
            userRepository as UserRepositoryMock,
            toReturn: info);
        UserRepositoryMock.stubGetInfo(userRepository as UserRepositoryMock,
            toReturn: info);
        UserRepositoryMock.stubGetPrograms(
            userRepository as UserRepositoryMock);

        await viewModel.refresh();

        expect(viewModel.profileStudent, info);

        verifyInOrder([
          userRepository.getInfo(),
          userRepository.getPrograms(),
          userRepository.info,
        ]);

        verifyNoMoreInteractions(userRepository);
      });
    });
  });
}
