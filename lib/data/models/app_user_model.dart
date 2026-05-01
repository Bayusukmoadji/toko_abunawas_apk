class AppUserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final bool isActive;

  AppUserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
  });

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      isActive: map['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'isActive': isActive,
    };
  }
}
