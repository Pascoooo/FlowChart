import 'models/models.dart';

abstract class UserRepository{

  Stream<MyUser?> get user;

  Future<void> setUserData(MyUser user);

  Future<void> signIn(String email,String password);

  Future<void> signOut();

  Future<MyUser> signUp(MyUser myUser,String password);

  Future<String> getUid();

  Future<MyUser> signInWithGoogle();

  Future<bool> isEmailVerified();

  void sendEmailVerification();

  Future<MyUser?> getCurrentUser();

  Future<MyUser> linkWithGoogle();

  Future<MyUser> linkWithEmailPassword(String email,String password);

  Future<List<String>> getLinkedProviders();

  Future<bool> hasProvider(String providerId);



}