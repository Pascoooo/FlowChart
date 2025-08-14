// dart
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

enum AuthenticationStatus { unknown, unauthenticated, emailNotVerified, authenticated }
enum AuthProvider { google, emailPassword }

class AuthenticationState extends Equatable {
  final AuthenticationStatus status;
  final MyUser? user;
  final bool isLoading;
  final AuthProvider? inProgressProvider;
  final String? error;

  const AuthenticationState({
    required this.status,
    this.user,
    this.isLoading = false,
    this.inProgressProvider,
    this.error,
  });

  const AuthenticationState.unknown({
    MyUser? user,
    bool isLoading = false,
    AuthProvider? inProgressProvider,
    String? error,
  }) : this(
    status: AuthenticationStatus.unknown,
    user: user,
    isLoading: isLoading,
    inProgressProvider: inProgressProvider,
    error: error,
  );

  const AuthenticationState.unauthenticated({
    bool isLoading = false,
    AuthProvider? inProgressProvider,
    String? error,
  }) : this(
    status: AuthenticationStatus.unauthenticated,
    isLoading: isLoading,
    inProgressProvider: inProgressProvider,
    error: error,
  );

  const AuthenticationState.emailNotVerified({
    MyUser? user,
    bool isLoading = false,
    AuthProvider? inProgressProvider,
    String? error,
  }) : this(
    status: AuthenticationStatus.emailNotVerified,
    user: user,
    isLoading: isLoading,
    inProgressProvider: inProgressProvider,
    error: error,
  );

  const AuthenticationState.authenticated(
      MyUser user, {
        bool isLoading = false,
        AuthProvider? inProgressProvider,
        String? error,
      }) : this(
    status: AuthenticationStatus.authenticated,
    user: user,
    isLoading: isLoading,
    inProgressProvider: inProgressProvider,
    error: error,
  );

  AuthenticationState copyWith({
    AuthenticationStatus? status,
    MyUser? user,
    bool? isLoading,
    AuthProvider? inProgressProvider,
    String? error,
  }) {
    return AuthenticationState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      inProgressProvider: inProgressProvider ?? this.inProgressProvider,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, user, isLoading, inProgressProvider, error];
}