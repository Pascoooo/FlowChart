import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final UserRepository userRepository;
  late final StreamSubscription<MyUser?> _userSubscription;

  AuthenticationBloc({required this.userRepository})
      : super(const AuthenticationState.unknown()) {
    _userSubscription = userRepository.user.listen((user) {
      add(AuthenticationUserChanged(user));
    });
    on<AuthenticationUserChanged>((event, emit) {
      if (event.user == MyUser.empty) {
        emit(const AuthenticationState.unauthenticated());
      } else {
        emit(AuthenticationState.authenticated(event.user!));
      }
    });

    on<AuthenticationUserVerified>((event, emit) async {
      await for (final user in userRepository.user) {
        if (user != MyUser.empty) {
          emit(AuthenticationState.authenticated(user!));
          break;
        }
      }
    });

    on<AuthenticationLogoutRequested>((event, emit) async {
      userRepository.signOut();
      add(AuthenticationUserChanged(MyUser.empty));
    });
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
