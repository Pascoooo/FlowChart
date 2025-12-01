/// Authentication BLoC gestisce lo stato di autenticazione dell'utente,
/// inclusi login con Google, logout e aggiornamenti profilo (nome, foto).
/// Ascolta i cambiamenti dello stream utente dal repository e propaga gli stati nell'applicazione.
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:user_repository/user_repository.dart';
import 'authentication_event.dart';
import 'authentication_state.dart';
import 'package:project_repository/project_repository.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final UserRepository _userRepository;
  late final StreamSubscription<MyUser?> _userSubscription;

  /// Inizializza il BLoC con UserRepository e sottoscrive lo stream utente.
  /// Registra gli event handler per autenticazione e gestione profilo.
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
    on<AuthenticationDisplayNameUpdateRequested>(_onDisplayNameUpdateRequested);
    on<AuthenticationPhotoUpdateRequested>(_onPhotoUpdateRequested);
    on<AuthenticationErrorCleared>(_onAuthenticationErrorCleared);
  }

  /// Gestisce i cambiamenti dello stato utente dallo stream del repository.
  /// Emette stato authenticated se l'utente è valido, altrimenti unauthenticated.
  void _onUserChanged(
      AuthenticationUserChanged event, Emitter<AuthenticationState> emit) {
    final user = event.user;
    if (user != null && user != MyUser.empty) {
      emit(AuthenticationState.authenticated(user));
    } else {
      emit(const AuthenticationState.unauthenticated());
    }
  }

  /// Metodo helper per gestire errori in modo uniforme.
  /// Estrae il messaggio da AuthenticationException o usa un messaggio di fallback.
  String _extractErrorMessage(Object error, String fallbackMessage) {
    return error is AuthenticationException ? error.message : fallbackMessage;
  }

  /// Gestisce la richiesta di login con Google.
  /// In caso di successo, lo stato viene aggiornato automaticamente da _onUserChanged.
  /// In caso di errore, emette stato unauthenticated con messaggio di errore.
  Future<void> _onGoogleSignInRequested(
      AuthenticationGoogleSignInRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.signInWithGoogle();
      // Il successo viene gestito da _onUserChanged
    } catch (e) {
      final errorMessage = _extractErrorMessage(e, 'Errore di autenticazione Google.');
      emit(state.copyWith(
        isLoading: false,
        status: AuthenticationStatus.unauthenticated,
        errorMessage: errorMessage,
      ));
    }
  }

  /// Gestisce la richiesta di logout dell'utente.
  /// Tenta di pulire le sessioni RTDB prima del logout (errori non bloccanti).
  /// In caso di errore nel logout principale, emette stato con messaggio di errore.
  Future<void> _onLogoutRequested(AuthenticationLogoutRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // Tentativo di pulizia sessioni RTDB (non bloccante)
      final uid = state.user.userId;
      if (uid.isNotEmpty) {
        try {
          final rtdbService = RtdbSessionService(uid: uid);
          await rtdbService.clearAllSessions();
        } catch (sessionError) {
          // Log dell'errore ma non blocca il logout
          // TODO: Considerare l'uso di un logger qui
        }
      }

      await _userRepository.signOut();
    } catch (e) {
      final errorMessage = _extractErrorMessage(e, 'Errore durante il logout.');
      emit(state.copyWith(
          isLoading: false, errorMessage: errorMessage));
    }
  }

  /// Gestisce la richiesta di eliminazione dell'account utente.
  /// Delega al repository l'eliminazione e gestisce eventuali errori.
  Future<void> _onDeleteAccountRequested(
      AuthenticationDeleteAccountRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.deleteAccount();
    } catch (e) {
      final errorMessage = _extractErrorMessage(e, 'Errore durante l\'eliminazione dell\'account.');
      emit(state.copyWith(
          isLoading: false,
          errorMessage: errorMessage));
    }
  }

  /// Gestisce l'aggiornamento del nome visualizzato dell'utente.
  /// Delega al repository l'aggiornamento e gestisce errori.
  Future<void> _onDisplayNameUpdateRequested(
      AuthenticationDisplayNameUpdateRequested event,
      Emitter<AuthenticationState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.updateUserDisplayName(event.displayName);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final errorMessage = _extractErrorMessage(e, "Errore durante l'aggiornamento del nome.");
      emit(state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      ));
    }
  }
  /// Gestisce l'aggiornamento della foto profilo dell'utente.
  /// Carica la nuova foto tramite repository e aggiorna lo stato con il nuovo URL.
  Future<void> _onPhotoUpdateRequested(
      AuthenticationPhotoUpdateRequested event,
      Emitter<AuthenticationState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final newPhotoURL = await _userRepository.updateUserPhoto(event.photoFileBytes);
      final updatedUser = state.user.copyWith(photoURL: newPhotoURL);
      emit(state.copyWith(
        user: updatedUser,
        isLoading: false,
      ));
    } catch (e) {
      final errorMessage = _extractErrorMessage(e, "Errore durante l'aggiornamento della foto.");
      emit(state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      ));
    }
  }

  /// Pulisce il messaggio di errore corrente dallo stato.
  /// Consente di dismissare messaggi di errore dalla UI.
  void _onAuthenticationErrorCleared(
      AuthenticationErrorCleared event,
      Emitter<AuthenticationState> emit,
      ) {
    emit(state.copyWith(clearErrorMessage: true));
  }

  /// Cancella la sottoscrizione allo stream utente prima di chiudere il BLoC.
  /// Previene memory leak cancellando le risorse attive.
  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
