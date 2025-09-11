import 'dart:async';
import 'package:bloc/bloc.dart';
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
    _userSubscription = _userRepository.user.listen((user) {
      add(AuthenticationUserChanged(user));
    });

    on<AuthenticationUserChanged>(_onUserChanged);
    on<AuthenticationGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthenticationLogoutRequested>(_onLogoutRequested);
    on<AuthenticationDeleteAccountRequested>(_onDeleteAccountRequested);
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
    } catch (e) {
      emit(const AuthenticationState.unauthenticated(
          errorMessage: 'Errore di autenticazione Google.'
      ));
    }
  }

  /// Gestisce la richiesta di logout.
  Future<void> _onLogoutRequested(
      AuthenticationLogoutRequested event, Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _userRepository.signOut();
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Errore durante il logout.'
      ));
    }
  }

  /// Gestisce la richiesta di eliminazione dell'account.
  /// Emette uno stato di caricamento e poi tenta di eliminare l'account.
  /// In caso di errore, emette uno stato con il messaggio di errore.
  /// Se l'eliminazione ha successo, l'utente verrà automaticamente disconnesso
  Future<void> _onDeleteAccountRequested(
      AuthenticationDeleteAccountRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _userRepository.deleteAccount();
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Errore durante l\'eliminazione dell\'account.'
      ));
    }
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
