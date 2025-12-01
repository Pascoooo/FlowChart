import 'dart:typed_data';

import 'models/models.dart';

abstract class UserRepository {
  // Stream of the currently authenticated user (or null if signed out)
  Stream<MyUser?> get user;

  // Persist user profile data in the backend (Firestore)
  Future<void> setUserData(MyUser user);

  // Sign out from Firebase (and providers where needed)
  Future<void> signOut();

  // Sign in with Google
  Future<MyUser> signInWithGoogle();

  // Account Deletetion
  Future<void> deleteAccount();

  // Update Display Name
  Future<void> updateUserDisplayName(String displayName);

  // Update Photo
  Future<String> updateUserPhoto(Uint8List photoFileBytes);
}
