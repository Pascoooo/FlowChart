import 'models/models.dart';

abstract class UserRepository {
  // Stream of the currently authenticated user (or null if signed out)
  Stream<MyUser?> get user;

  // Persist user profile data in the backend (Firestore)
  Future<void> setUserData(MyUser user);

  // Sign out from Firebase (and providers where needed)
  Future<void> signOut();

  // Get current Firebase user uid or throw if no user
  Future<String> getUid();

  // Get current user mapped to MyUser (or null if not authenticated)
  Future<MyUser?> getCurrentUser();

  // Sign in with Google
  Future<MyUser> signInWithGoogle();

  // Send email magic link
  Future<void> sendEmailLink(String email);

  // Sign in with email link
  Future<MyUser> signInWithEmailLink(String email, String emailLink);

  // Check if string is valid email link
  bool isEmailLink(String link);
}