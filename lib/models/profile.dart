class Profile {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarPath;

  const Profile(
      {required this.id, this.username, this.displayName, this.avatarPath});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        username: j['username'] as String?,
        displayName: j['display_name'] as String?,
        avatarPath: j['avatar_url'] as String?,
      );
}
