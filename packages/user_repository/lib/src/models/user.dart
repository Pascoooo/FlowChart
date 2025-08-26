// dart
import '../entities/entities.dart';

class MyUser {
  final String userId;
  final String email;
  final String name;
  final String photoURL;

  const MyUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoURL,
  });

  // Rendi 'empty' una variabile costante
  static const empty = MyUser(
    userId: '',
    email: '',
    name: '',
    photoURL: '',
  );

  MyUserEntity toEntity() {
    return MyUserEntity(
      userId: userId,
      email: email,
      name: name,
      photoURL: photoURL,
    );
  }

  static MyUser fromEntity(MyUserEntity entity) {
    return MyUser(
      userId: entity.userId,
      email: entity.email,
      name: entity.name,
      photoURL: entity.photoURL,
    );
  }

  @override
  String toString() {
    return 'MyUser: $userId, $email, $name, $photoURL';
  }

  bool get isEmpty => this == MyUser.empty;
}