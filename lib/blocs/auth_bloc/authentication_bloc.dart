
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';
import 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc extends Bloc<AuthenticationEvent, AuthenticationState> {
  final UserRepository userRepository;
  late final StreamSubscription<MyUser?> _userSubscription;

  AuthenticationBloc({required this.userRepository})
      : super(const AuthenticationState.unknown()) {

    _userSubscription = userRepository.user.listen(
          (user) => add(AuthenticationUserChanged(user)),
      onError: (_) => add(AuthenticationUserChanged(MyUser.empty)),
    );

    on<AuthenticationUserChanged>((event, emit) async {
      final user = event.user;
      if (user == MyUser.empty || user == null) {
        emit(const AuthenticationState.unauthenticated());
        return;
      }
      // Utente autenticato - il provider non è rilevante qui
      emit(AuthenticationState.authenticated(user));
    });

    on<AuthenticationLogoutRequested>((event, emit) async {
      try {
        await userRepository.signOut();
        emit(const AuthenticationState.unauthenticated());
      } catch (e) {
        debugPrint('Logout error: $e');
        emit(const AuthenticationState.unauthenticated());
      }
    });

    on<AuthenticationGoogleSignInRequested>((event, emit) async {
      try {
        await userRepository.signInWithGoogle();
        // Lo stato cambierà automaticamente tramite lo stream user
      } catch (e) {
        debugPrint('Google sign in error: $e');
        // Il metodo può lanciare un'eccezione che verrà catturata nell'UI
        rethrow;
      }
    });

    on<AuthenticationEmailLinkRequested>((event, emit) async {
      try {
        await userRepository.sendEmailLink(event.email);
        // Successo - nessun cambiamento di stato necessario
      } catch (e) {
        debugPrint('Send email link error: $e');
        rethrow;
      }
    });

    on<AuthenticationEmailLinkSignInRequested>((event, emit) async {
      try {
        await userRepository.signInWithEmailLink(event.email, event.emailLink);
        // Lo stato cambierà automaticamente tramite lo stream user
      } catch (e) {
        debugPrint('Email link sign in error: $e');
        rethrow;
      }
    });
  }

  @override
  Future<void> close() async {
    await _userSubscription.cancel();
    await super.close();
  }
}