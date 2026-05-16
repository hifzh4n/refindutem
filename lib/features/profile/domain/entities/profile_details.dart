import 'dart:typed_data';

class ProfileDetails {
  const ProfileDetails({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.avatarPath,
    required this.avatarUrl,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String? avatarPath;
  final String? avatarUrl;
}

class AvatarUploadResult {
  const AvatarUploadResult({required this.path, required this.url});

  final String path;
  final String? url;
}

class AvatarUploadInput {
  const AvatarUploadInput({
    required this.bytes,
    required this.fileExtension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileExtension;
  final String contentType;
}
