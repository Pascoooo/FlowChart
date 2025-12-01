/// Stato di autenticazione per AuthenticationBloc.
/// Contiene lo status di autenticazione, l'utente corrente e stati di loading/errori.
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

enum AuthenticationStatus { unknown, authenticated, unauthenticated }

class AuthenticationState extends Equatable {
  final AuthenticationStatus status;
  final MyUser user;
  final bool isLoading;
  final String? errorMessage;

  const AuthenticationState._({
    required this.status,
    this.user = MyUser.empty,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Costruttore per stato unknown (inizializzazione BLoC).
  const AuthenticationState.unknown()
      : this._(status: AuthenticationStatus.unknown);

  /// Costruttore per stato authenticated con utente valido.
  const AuthenticationState.authenticated(MyUser user)
      : this._(
    status: AuthenticationStatus.authenticated,
    user: user,
  );

  /// Costruttore per stato unauthenticated, opzionalmente con messaggio di errore.
  const AuthenticationState.unauthenticated({String? errorMessage})
      : this._(
    status: AuthenticationStatus.unauthenticated,
    errorMessage: errorMessage,
  );

  /// Crea una copia dello stato con modifiche selettive.
  /// clearErrorMessage consente di pulire esplicitamente l'errorMessage anche se null.
  AuthenticationState copyWith({
    AuthenticationStatus? status,
    MyUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AuthenticationState._(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    isLoading,
    errorMessage,
  ];
}
