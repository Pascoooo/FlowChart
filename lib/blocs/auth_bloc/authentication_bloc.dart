import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';
import 'authentication_event.dart';
import 'authentication_state.dart';

class AuthenticationBloc extends Bloc<AuthenticationEvent, AuthenticationState> {
  final UserRepository userRepository;
  late final StreamSubscription<MyUser?> _userSubscription;

  AuthenticationBloc({required this.userRepository})
      : super(const AuthenticationState.unknown()) {

    _userSubscription = userRepository.user.listen(
          (user) => add(AuthenticationUserChanged(user)),
      onError: (error) {
        add(AuthenticationUserChanged(MyUser.empty));
      },
    );

    on<AuthenticationUserChanged>((event, emit) async {
      final user = event.user;
      if (user == MyUser.empty || user == null) {
        emit(const AuthenticationState.unauthenticated());
      } else {
        try {
          final isEmailVerified = await userRepository
              .isEmailVerified()
              .timeout(const Duration(seconds: 10));

          if (isEmailVerified) {
            emit(AuthenticationState.authenticated(user));
          } else {
            emit(AuthenticationState.emailNotVerified(user));
          }
        } catch (e) {
          print('Errore controllo verifica email: $e');
          emit(AuthenticationState.emailNotVerified(user));
        }
      }
    });

    on<AuthenticationLogoutRequested>((event, emit) async {
      await userRepository.signOut();
      emit(const AuthenticationState.unauthenticated());
    });

    on<AuthenticationUserVerified>((event, emit) async {
      final user = state.user;
      if (user != null) {
        try {
          final isEmailVerified = await userRepository.isEmailVerified();
          if (isEmailVerified) {
            emit(AuthenticationState.authenticated(user));
          }
        } catch (e) {
          // Se c'è un errore, mantieni lo stato attuale
          emit(state);
        }
      }
    });
  }

  @override
  Future<void> close() async {
    await _userSubscription.cancel();
    await super.close();
  }
}