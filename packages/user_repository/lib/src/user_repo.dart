import 'models/models.dart';

abstract class UserRepository{

  Stream<MyUser?> get user;

  Future<void> setUserData(MyUser user);

  Future<void> signIn(String email,String password);

  Future<void> signOut();

  Future<MyUser> signUp(MyUser myUser,String password);

  Future<String> getUid();

  Future<MyUser> signInWithGoogle();

  Future<MyUser?> getCurrentUser();


  //Future<bool> isEmailVerified();

  //void sendEmailVerification();

  //void postProfileImage(String path);

  //Future<String> postImage(String path);

  //String get getPhotoUrl;

  //Future<void> changeEmail(String text);

  //Future<void> deleteAccount();

  //Future<void> emailChanged();

  //Future<void> changePhoneNumber(String text);
}