import '../entities/entities.dart';

class MyUser {
  String userId;
  String email;
  String name;
  String photoURL;

  MyUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoURL,
  });

  static final empty = MyUser(
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
}