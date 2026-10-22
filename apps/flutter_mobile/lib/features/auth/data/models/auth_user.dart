class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
  });
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneNumber;
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: '${json['id'] ?? json['_id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    email: '${json['email'] ?? ''}',
    role: '${json['role'] ?? ''}',
    phoneNumber: json['phoneNumber']?.toString(),
  );
}
