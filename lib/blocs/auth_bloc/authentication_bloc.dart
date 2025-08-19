import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';
import 'authentication_event.dart';
import 'authentication_state.dart';

class AuthenticationBloc extends Bloc<AuthenticationEvent, AuthenticationState> {
  final UserRepository userRepository;
  late final StreamSubscription<MyUser?> _userSubscription;

  //impostato un utente fittizio per il test, dovrebbe essere super(const AuthenticationState.unknown)
  AuthenticationBloc({required this.userRepository})
      : super(AuthenticationState.authenticated(
          MyUser(
            userId: 'test',
            email: 'test@example.com',
            name: 'Test User',
            photoURL: 'https://example.com/photo.jpg',
            // aggiungi altri campi fittizi se necessario
          ),
        )) {
    // 1. Controllo immediato dell'utente corrente
    userRepository.getCurrentUser().then((currentUser) {
      if (currentUser != null && currentUser != MyUser.empty) {
        add(AuthenticationUserChanged(currentUser));
      } else {
        // Timeout di fallback: se dopo 3 sec ancora unknown, assumiamo utente non loggato
        Future.delayed(const Duration(seconds: 3), () {
          if (state.status == AuthenticationStatus.unknown) {
            add(AuthenticationUserChanged(MyUser.empty));
          }
        });
      }
    });

    // 2. Sottoscrizione allo stream
    _userSubscription = userRepository.user.listen(
      (user) => add(AuthenticationUserChanged(user)),
    );

    on<AuthenticationUserChanged>((event, emit) {
      final u = event.user;
      if (u == MyUser.empty) {
        emit(const AuthenticationState.unauthenticated());
      } else if (u != null) {
        emit(AuthenticationState.authenticated(u));
      }
    });

    on<AuthenticationGoogleSignInRequested>((event, emit) async {
      emit(const AuthenticationState.unauthenticated(
        isLoading: true,
        inProgressProvider: AuthProvider.google,
      ));
      try {
        await userRepository.signInWithGoogle();
      } catch (e) {
        emit(AuthenticationState.unauthenticated(
          isLoading: false,
          inProgressProvider: null,
          error: e.toString(),
        ));
      }
    });

    on<AuthenticationLogoutRequested>((event, emit) async {
      await userRepository.signOut();
      emit(const AuthenticationState.unauthenticated());
    });
  }

  @override
  Future<void> close() async {
    await _userSubscription.cancel();
    return super.close();
  }
}
