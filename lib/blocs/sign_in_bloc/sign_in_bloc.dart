import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

part 'sign_in_event.dart';
part 'sign_in_state.dart';

class SignInBloc extends Bloc<SignInEvent, SignInState> {
  final UserRepository _userRepository;

  SignInBloc(this._userRepository) : super(SignInInitial()) {

    // Login con email/password
    on<SignInWithEmailRequested>((event, emit) async {
      emit(SignInProcess());
      try {
        await _userRepository.signIn(event.email, event.password);
        emit(SignInSuccess());
      } on FirebaseException catch (e) {
        emit(SignInFailure(e.message ?? 'An unknown error occurred'));
      }
    });

    // Login con Google
    on<SignInWithGoogleRequested>((event, emit) async {
      emit(SignInProcess());
      try {
        await _userRepository.signInWithGoogle();
        emit(SignInSuccess());
      } on FirebaseException catch (e) {
        emit(SignInFailure(e.message ?? 'An unknown error occurred'));
      }
    });

    // Reset dello stato
    on<SignInReset>((event, emit) {
      emit(SignInInitial());
    });
  }
}