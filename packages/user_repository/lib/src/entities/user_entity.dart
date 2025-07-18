class MyUserEntity {
  String userId;
  String email;
  String name;
  String photoURL;

  MyUserEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoURL,
  });

static MyUserEntity fromJson(Map<String, dynamic> json) {
    return MyUserEntity(
      userId: json['userId'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      photoURL: json['photoURL'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'photoURL': photoURL,
    };
  }
}
