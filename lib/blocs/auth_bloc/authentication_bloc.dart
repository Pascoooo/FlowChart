import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:user_repository/user_repository.dart';
import 'authentication_event.dart';
import 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final UserRepository _userRepository;
  late final StreamSubscription<MyUser?> _userSubscription;

  AuthenticationBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const AuthenticationState.unknown()) {
    // Ascolta i cambiamenti dell'utente dal repository
    _userSubscription = _userRepository.user.listen((user) {
      add(AuthenticationUserChanged(user));
    });

    on<AuthenticationUserChanged>(_onUserChanged);
    on<AuthenticationGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthenticationLogoutRequested>(_onLogoutRequested);
  }

  /// Aggiorna lo stato del BLoC quando lo stato dell'utente cambia.
  void _onUserChanged(
      AuthenticationUserChanged event, Emitter<AuthenticationState> emit) {
    final user = event.user;
    if (user != null && user != MyUser.empty) {
      emit(AuthenticationState.authenticated(user));
    } else {
      emit(const AuthenticationState.unauthenticated());
    }
  }

  /// Gestisce la richiesta di autenticazione con Google.
  Future<void> _onGoogleSignInRequested(
      AuthenticationGoogleSignInRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.signInWithGoogle();
      // Non è necessario emettere uno stato qui,
      // lo stream dell'utente attiverà _onUserChanged
    } catch (e) {
      if (kDebugMode) {
        print('Errore di autenticazione Google: $e');
      }
      emit(const AuthenticationState.unauthenticated(
          errorMessage: 'Errore di autenticazione Google.'));
    }
  }

  /// Gestisce la richiesta di logout.
  Future<void> _onLogoutRequested(
      AuthenticationLogoutRequested event, Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _userRepository.signOut();
      // Lo stream dell'utente attiverà _onUserChanged con utente nullo
    } catch (e) {
      if (kDebugMode) {
        print('Errore durante il logout: $e');
      }
      // Se il logout fallisce, torniamo allo stato precedente ma senza caricamento
      emit(state.copyWith(
          isLoading: false, errorMessage: 'Errore durante il logout.'));
    }
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}