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
    on<AuthenticationDisplayNameUpdateRequested> (_onDisplayNameUpdateRequested);
    on<AuthenticationPhotoUpdateRequested>(_onPhotoUpdateRequested);
    on<AuthenticationDrivePermissionRequested>(_onDrivePermissionRequested);
    on<AuthenticationDrivePermissionRevoked>(_onDrivePermissionRevoked);
    on<ExportFlowchartToDriveRequested>(_onExportFlowchartToDriveRequested);
    on<AuthenticationErrorCleared>(_onAuthenticationErrorCleared);
  }

  void _onUserChanged(
      AuthenticationUserChanged event, Emitter<AuthenticationState> emit) {
    final user = event.user;
    if (user != null && user != MyUser.empty) {
      emit(AuthenticationState.authenticated(user));
    } else {
      emit(const AuthenticationState.unauthenticated());
    }
  }

  Future<void> _onGoogleSignInRequested(
      AuthenticationGoogleSignInRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.signInWithGoogle();
      // Il successo viene gestito da _onUserChanged
    } catch (e) {
      // Miglioramento: Propaga il messaggio di errore specifico
      final errorMessage = e is AuthenticationException ? e.message : 'Errore di autenticazione Google.';
      emit(state.copyWith(
        isLoading: false,
        status: AuthenticationStatus.unauthenticated,
        errorMessage: errorMessage,
      ));
    }
  }

  Future<void> _onLogoutRequested(AuthenticationLogoutRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.signOut();
    } catch (e) {
      // Miglioramento: Propaga il messaggio di errore specifico
      final errorMessage = e is AuthenticationException ? e.message : 'Errore durante il logout.';
      emit(state.copyWith(
          isLoading: false, errorMessage: errorMessage));
    }
  }

  Future<void> _onDeleteAccountRequested(
      AuthenticationDeleteAccountRequested event,
      Emitter<AuthenticationState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.deleteAccount();
    } catch (e) {
      // Miglioramento: Propaga il messaggio di errore specifico
      final errorMessage = e is AuthenticationException ? e.message : 'Errore durante l\'eliminazione dell\'account.';
      emit(state.copyWith(
          isLoading: false,
          errorMessage: errorMessage));
    }
  }

  Future<void> _onDisplayNameUpdateRequested(
      AuthenticationDisplayNameUpdateRequested event,
      Emitter<AuthenticationState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.updateUserDisplayName(event.displayName);
      emit(state.copyWith(isLoading: false));

    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthenticationException
            ? e.message
            : "Errore durante l'aggiornamento del nome.",
      ));
    }
  }
// bloc (authentication_bloc.dart)
  Future<void> _onPhotoUpdateRequested(
      AuthenticationPhotoUpdateRequested event,
      Emitter<AuthenticationState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // Now this returns the URL string
      final newPhotoURL = await _userRepository.updateUserPhoto(event.photoFileBytes);

      // Create an updated user object
      final updatedUser = state.user.copyWith(photoURL: newPhotoURL);

      // Emit the new state with the updated user and isLoading set to false
      emit(state.copyWith(
        user: updatedUser,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthenticationException
            ? e.message
            : "Errore durante l'aggiornamento della foto.",
      ));
    }
  }

  Future<void> _onDrivePermissionRequested(
      AuthenticationDrivePermissionRequested event,
      Emitter<AuthenticationState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final bool granted = await _userRepository.requestGoogleDrivePermission();
      if (!granted) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: "Autorizzazione per Google Drive non concessa.",
        ));
      } else {
        // Il listener dello stream `user` si occuperà di aggiornare la UI con
        // `driveConnected: true`, quindi qui basta fermare il caricamento.
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthenticationException
            ? e.message
            : "Errore durante la richiesta dei permessi.",
      ));
    }
  }

  Future<void> _onDrivePermissionRevoked(
      AuthenticationDrivePermissionRevoked event,
      Emitter<AuthenticationState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.revokeGoogleDrivePermission();
      // Anche qui, il listener dello stream `user` aggiornerà la UI.
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthenticationException
            ? e.message
            : "Errore durante la disconnessione da Drive.",
      ));
    }
  }

  Future<void> _onExportFlowchartToDriveRequested(
      ExportFlowchartToDriveRequested event,
      Emitter<AuthenticationState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _userRepository.uploadFileToDrive(
          event.fileName, event.fileBytes);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthenticationException
            ? e.message
            : "Errore durante l'esportazione su Google Drive.",
      ));
    }
  }


  void _onAuthenticationErrorCleared(
      AuthenticationErrorCleared event,
      Emitter<AuthenticationState> emit,
      ) {
    emit(state.copyWith(errorMessage: null));
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
