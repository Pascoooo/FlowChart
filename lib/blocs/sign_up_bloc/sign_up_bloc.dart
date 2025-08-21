import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

part 'sign_up_event.dart';
part 'sign_up_state.dart';

class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  final UserRepository _userRepository;

  SignUpBloc(this._userRepository) : super(SignUpInitial()) {
    on<SignUpRequired>((event, emit) async {
      emit(SignUpProcess());
      try {
        MyUser newUser = await _userRepository.signUp(event.user, event.password);
        await _userRepository.setUserData(newUser);
        emit(SignUpSuccess());
      } on FirebaseException catch (e) {
        emit(SignUpFailure(e.message ?? 'An unknown error occurred'));
      }
    });

    // Reset dello stato
    on<SignUpReset>((event, emit) {
      emit(SignUpInitial());
    });
  }
}