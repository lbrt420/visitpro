class Property {
  const Property({
    required this.id,
    required this.name,
    required this.address,
    required this.clientShareToken,
    this.companyLogoUrl = '',
    this.assignedClientAccounts = const <AssignedClientAccount>[],
  });

  final String id;
  final String name;
  final String address;
  final String clientShareToken;
  final String companyLogoUrl;
  final List<AssignedClientAccount> assignedClientAccounts;

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      clientShareToken: json['clientShareToken'] as String,
      companyLogoUrl: (json['companyLogoUrl'] as String?) ?? '',
      assignedClientAccounts:
          (json['assignedClientAccounts'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => item.map((key, value) => MapEntry('$key', value)))
              .map(AssignedClientAccount.fromJson)
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'clientShareToken': clientShareToken,
      'companyLogoUrl': companyLogoUrl,
      'assignedClientAccounts':
          assignedClientAccounts.map((item) => item.toJson()).toList(),
    };
  }
}

class AssignedClientAccount {
  const AssignedClientAccount({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? username;
  final String? avatarUrl;

  factory AssignedClientAccount.fromJson(Map<String, dynamic> json) {
    return AssignedClientAccount(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'avatarUrl': avatarUrl,
    };
  }
}
