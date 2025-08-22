import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

enum AuthenticationStatus {
  unknown,
  unauthenticated,
  authenticated,
  emailNotVerified
}

class AuthenticationState extends Equatable {
  final AuthenticationStatus status;
  final MyUser? user;

  const AuthenticationState({
    required this.status,
    this.user,
  });

  const AuthenticationState.unknown({MyUser? user})
      : this(status: AuthenticationStatus.unknown, user: user);

  const AuthenticationState.unauthenticated()
      : this(status: AuthenticationStatus.unauthenticated);

  const AuthenticationState.authenticated(MyUser user)
      : this(status: AuthenticationStatus.authenticated, user: user);

  const AuthenticationState.emailNotVerified(MyUser user)
      : this(status: AuthenticationStatus.emailNotVerified, user: user);

  @override
  List<Object?> get props => [status, user];
}
