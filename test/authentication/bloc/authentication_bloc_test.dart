qimport 'package:flowchart_thesis/blocs/auth_bloc/authentication_bloc.dart';
import 'package:flowchart_thesis/blocs/auth_bloc/authentication_event.dart';
import 'package:flowchart_thesis/blocs/auth_bloc/authentication_state.dart' as s;
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:user_repository/user_repository.dart';

// IMPORTANTE: Questi import devono corrispondere alla tua struttura di progetto
// Modifica i path se necessario:
import '../../../lib/screens/error/auth_error_mapper.dart';

// Mock classes - questi saranno generati automaticamente
@GenerateMocks([UserRepository, fb.FirebaseAuth, fb.User])
import 'authentication_bloc_test.mocks.dart';

void main() {
  group('AuthenticationBloc Tests', () {
    late AuthenticationBloc authenticationBloc;
    late MockUserRepository mockUserRepository;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockUser mockFirebaseUser;

    final testUser = MyUser(
      userId: 'test-uid',
      email: 'test@example.com',
      name: 'Test User',
      photoURL: 'https://example.com/photo.jpg',
    );

    setUp(() {
      mockUserRepository = MockUserRepository();
      mockFirebaseAuth = MockFirebaseAuth();
      mockFirebaseUser = MockUser();

      // Setup default behaviors
      when(mockUserRepository.getCurrentUser())
          .thenAnswer((_) async => null);
      when(mockUserRepository.user)
          .thenAnswer((_) => Stream.value(null));
    });

    tearDown(() {
      authenticationBloc?.close();
    });

    group('Initialization Tests', () {
      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should start with unknown state',
        build: () {
          authenticationBloc = AuthenticationBloc(userRepository: mockUserRepository);
          return authenticationBloc;
        },
        verify: (bloc) {
          expect(bloc.state.status, s.AuthenticationStatus.unknown);
          expect(bloc.state.user, isNull);
          expect(bloc.state.isLoading, isFalse);
          expect(bloc.state.inProgressProvider, isNull);
          expect(bloc.state.error, isNull);
        },
        expect: () => [],
      );

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit authenticated when current user exists on init',
        build: () {
          when(mockUserRepository.getCurrentUser())
              .thenAnswer((_) async => testUser);
          when(mockUserRepository.user)
              .thenAnswer((_) => Stream.value(testUser));

          authenticationBloc = AuthenticationBloc(userRepository: mockUserRepository);
          return authenticationBloc;
        },
        expect: () => [
          s.AuthenticationState.authenticated(
            testUser,
            isLoading: false,
            inProgressProvider: null,
            error: null,
          ),
        ],
      );

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit unauthenticated when current user is empty on init',
        build: () {
          when(mockUserRepository.getCurrentUser())
              .thenAnswer((_) async => MyUser.empty);
          when(mockUserRepository.user)
              .thenAnswer((_) => Stream.value(MyUser.empty));

          authenticationBloc = AuthenticationBloc(userRepository: mockUserRepository);
          return authenticationBloc;
        },
        expect: () => [
          s.AuthenticationState.unauthenticated(
            isLoading: false,
            inProgressProvider: null,
            error: null,
          ),
        ],
      );
    });

    group('AuthenticationUserChanged Event Tests', () {
      setUp(() {
        when(mockUserRepository.user)
            .thenAnswer((_) => Stream.value(null));
        authenticationBloc = AuthenticationBloc(userRepository: mockUserRepository);
      });

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit authenticated when user changed to valid user',
        build: () => authenticationBloc,
        act: (bloc) => bloc.add(AuthenticationUserChanged(testUser)),
        expect: () => [
          s.AuthenticationState.authenticated(
            testUser,
            isLoading: false,
            inProgressProvider: null,
            error: null,
          ),
        ],
      );

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit unauthenticated when user changed to empty',
        build: () => authenticationBloc,
        act: (bloc) => bloc.add(AuthenticationUserChanged(MyUser.empty)),
        expect: () => [
          s.AuthenticationState.unauthenticated(
            isLoading: false,
            inProgressProvider: null,
            error: null,
          ),
        ],
      );

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit unauthenticated when user changed to null',
        build: () => authenticationBloc,
        act: (bloc) => bloc.add(AuthenticationUserChanged(null)),
        expect: () => [
          s.AuthenticationState.unauthenticated(
            isLoading: false,
            inProgressProvider: null,
            error: null,
          ),
        ],
      );
    });

    group('AuthenticationGoogleSignInRequested Event Tests', () {
      setUp(() {
        when(mockUserRepository.user)
            .thenAnswer((_) => Stream.value(null));
        authenticationBloc = AuthenticationBloc(userRepository: mockUserRepository);
      });

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit loading then success on successful Google sign in',
        build: () => authenticationBloc,
        setUp: () {
          when(mockUserRepository.signInWithGoogle())
              .thenAnswer((_) async => testUser);
        },
        act: (bloc) => bloc.add(AuthenticationGoogleSignInRequested()),
        expect: () => [
          s.AuthenticationState.unauthenticated(
            isLoading: true,
            inProgressProvider: s.AuthProvider.google,
            error: null,
          ),
        ],
        verify: (_) {
          verify(mockUserRepository.signInWithGoogle()).called(1);
        },
      );

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit loading then error on Google sign in Firebase exception',
        build: () => authenticationBloc,
        setUp: () {
          when(mockUserRepository.signInWithGoogle())
              .thenThrow(fb.FirebaseAuthException(
            code: 'user-disabled',
            message: 'User account disabled',
          ));
        },
        act: (bloc) => bloc.add(AuthenticationGoogleSignInRequested()),
        expect: () => [
          s.AuthenticationState.unauthenticated(
            isLoading: true,
            inProgressProvider: s.AuthProvider.google,
            error: null,
          ),
          s.AuthenticationState.unauthenticated(
            isLoading: false,
            inProgressProvider: null,
            error: AuthErrorMapper.fromFirebase(fb.FirebaseAuthException(
              code: 'user-disabled',
              message: 'User account disabled',
            )),
          ),
        ],
        verify: (_) {
          verify(mockUserRepository.signInWithGoogle()).called(1);
        },
      );
    });

    group('AuthenticationEmailSignInRequested Event Tests', () {
      setUp(() {
        when(mockUserRepository.user)
            .thenAnswer((_) => Stream.value(null));
        authenticationBloc = AuthenticationBloc(userRepository: mockUserRepository);
      });

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit loading then success on successful email sign in',
        build: () => authenticationBloc,
        setUp: () {
          when(mockUserRepository.signIn('test@example.com', 'password123'))
              .thenAnswer((_) async => testUser);
        },
        act: (bloc) => bloc.add(AuthenticationEmailSignInRequested(
          'test@example.com',
           'password123',
        )),
        expect: () => [
          s.AuthenticationState.unauthenticated(
            isLoading: true,
            inProgressProvider: s.AuthProvider.emailPassword,
            error: null,
          ),
        ],
        verify: (_) {
          verify(mockUserRepository.signIn('test@example.com', 'password123')).called(1);
        },
      );

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit loading then error on wrong password',
        build: () => authenticationBloc,
        setUp: () {
          when(mockUserRepository.signIn('test@example.com', 'wrongpass'))
              .thenThrow(fb.FirebaseAuthException(
            code: 'wrong-password',
            message: 'Wrong password',
          ));
        },
        act: (bloc) => bloc.add(AuthenticationEmailSignInRequested(
          'test@example.com',
           'wrongpass',
        )),
        expect: () => [
          s.AuthenticationState.unauthenticated(
            isLoading: true,
            inProgressProvider: s.AuthProvider.emailPassword,
            error: null,
          ),
          s.AuthenticationState.unauthenticated(
            isLoading: false,
            inProgressProvider: null,
            error: AuthErrorMapper.fromFirebase(fb.FirebaseAuthException(
              code: 'wrong-password',
              message: 'Wrong password',
            )),
          ),
        ],
      );
    });

    group('AuthenticationLogoutRequested Event Tests', () {
      setUp(() {
        when(mockUserRepository.user)
            .thenAnswer((_) => Stream.value(testUser));
        authenticationBloc = AuthenticationBloc(userRepository: mockUserRepository);
      });

      blocTest<AuthenticationBloc, s.AuthenticationState>(
        'should emit unauthenticated on successful logout',
        build: () => authenticationBloc,
        setUp: () {
          when(mockUserRepository.signOut())
              .thenAnswer((_) async {});
        },
        act: (bloc) => bloc.add(AuthenticationLogoutRequested()),
        expect: () => [
          s.AuthenticationState.authenticated(
            testUser,
            isLoading: false,
            inProgressProvider: null,
            error: null,
          ),
          s.AuthenticationState.unauthenticated(
            isLoading: false,
            inProgressProvider: null,
            error: null,
          ),
        ],
        verify: (_) {
          verify(mockUserRepository.signOut()).called(1);
        },
      );
    });

    // Qui puoi aggiungere altri test groups...
    // Ho incluso solo alcuni esempi per iniziare
  });
}