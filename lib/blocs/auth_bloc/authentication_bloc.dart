import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';
import 'authentication_event.dart';
import 'authentication_state.dart' as s;

class AuthenticationBloc extends Bloc<AuthenticationEvent, s.AuthenticationState> {
  final UserRepository userRepository;
  late final StreamSubscription<MyUser?> _userSubscription;

  AuthenticationBloc({required this.userRepository})
      : super(const s.AuthenticationState.unknown()) {

    _userSubscription = userRepository.user
        .listen(
          (user) => add(AuthenticationUserChanged(user)),
      onError: (error) {
        add(AuthenticationUserChanged(MyUser.empty));
      },
    );

    on<AuthenticationUserChanged>((event, emit) {
      final user = event.user;
      if (user == MyUser.empty || user == null) {
        emit(const s.AuthenticationState.unauthenticated());
      } else {
        emit(s.AuthenticationState.authenticated(user));
      }
    });

    on<AuthenticationLogoutRequested>((event, emit) async {
      await userRepository.signOut();
      emit(const s.AuthenticationState.unauthenticated());
    });
  }

  @override
  Future<void> close() async {
    await _userSubscription.cancel();
    return super.close();
  }
}