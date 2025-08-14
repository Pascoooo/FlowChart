import 'models/models.dart';

abstract class UserRepository{

  Stream<MyUser?> get user;

  Future<String> getUid();
  Future<MyUser?> getCurrentUser();
  Future<void> setUserData(MyUser user);
  Future<void> signOut();

  Future<MyUser> signIn(String email, String password);
  Future<MyUser> signUp(MyUser myUser, String password);
  Future<MyUser> signInWithGoogle();

  // Nuovi metodi per linking
  Future<MyUser> linkWithGoogle();
  Future<MyUser> linkWithEmailPassword(String email, String password);
  Future<bool> hasProvider(String providerId);
  Future<List<String>> getLinkedProviders();
}