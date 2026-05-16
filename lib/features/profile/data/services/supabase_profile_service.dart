import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../auth/data/services/supabase_auth_service.dart';
import '../../domain/entities/profile_details.dart';
import '../../domain/repositories/profile_repository.dart';

class SupabaseProfileService implements ProfileRepository {
  SupabaseProfileService({SupabaseAuthService? authService})
    : _authService = authService ?? SupabaseAuthService();

  static const avatarBucket = 'profiles';
  static const _avatarSignedUrlExpiresIn = 3600;

  final SupabaseAuthService _authService;

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<User?> getCurrentUser() async {
    try {
      final response = await _client.auth.getUser();
      return response.user ?? currentUser;
    } catch (_) {
      return currentUser;
    }
  }

  @override
  Future<ProfileDetails> getProfile() async {
    final user = await getCurrentUser();
    final metadata = user?.userMetadata ?? {};
    final fallbackName = _splitName(
      metadata['name']?.toString() ?? metadata['full_name']?.toString() ?? '',
    );
    final firstName =
        metadata['first_name']?.toString() ??
        metadata['given_name']?.toString() ??
        fallbackName.first;
    final lastName =
        metadata['last_name']?.toString() ??
        metadata['family_name']?.toString() ??
        fallbackName.last;
    final avatarPath = metadata['avatar_path']?.toString();

    return ProfileDetails(
      email: user?.email ?? 'Not signed in',
      firstName: firstName,
      lastName: lastName,
      phone: user?.phone ?? metadata['phone']?.toString() ?? '',
      avatarPath: avatarPath,
      avatarUrl: await createSignedAvatarUrl(avatarPath),
    );
  }

  ({String first, String last}) _splitName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return (first: '', last: '');
    }

    if (parts.length == 1) {
      return (first: parts.first, last: '');
    }

    return (first: parts.first, last: parts.skip(1).join(' '));
  }

  @override
  Future<UserResponse> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? avatarPath,
  }) {
    try {
      final existingMetadata = Map<String, dynamic>.from(
        currentUser?.userMetadata ?? {},
      );

      final trimmedFirstName = firstName.trim();
      final trimmedLastName = lastName.trim();
      final fullName = '$trimmedFirstName $trimmedLastName'.trim();

      existingMetadata['name'] = fullName;
      existingMetadata['first_name'] = trimmedFirstName;
      existingMetadata['last_name'] = trimmedLastName;
      final normalizedPhone = normalizeMalaysiaPhone(phone);

      existingMetadata['phone'] = normalizedPhone;

      existingMetadata.remove('avatar_url');

      if (avatarPath != null) {
        existingMetadata['avatar_path'] = avatarPath;
      }

      return _updateProfileAndPhone(
        metadata: existingMetadata,
        phone: normalizedPhone,
      );
    } on AppServiceException {
      rethrow;
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not update profile. Please try again.',
        ),
      );
    }
  }

  Future<UserResponse> _updateProfileAndPhone({
    required Map<String, dynamic> metadata,
    required String phone,
  }) async {
    try {
      await _client.rpc('update_my_phone', params: {'phone_number': phone});
    } on AppServiceException {
      rethrow;
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.rpc(
          error,
          rpcName: 'update_my_phone',
          fallback: 'Could not update phone number. Please try again.',
        ),
      );
    }

    late final UserResponse response;

    try {
      response = await _client.auth.updateUser(UserAttributes(data: metadata));
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not update profile. Please try again.',
        ),
      );
    }

    try {
      await _client.auth.refreshSession();
      await _client.auth.getUser();
    } catch (_) {}

    return response;
  }

  Future<void> _safeRemoveAvatar({
    required dynamic storage,
    required String oldAvatarPath,
  }) async {
    try {
      await storage.remove([oldAvatarPath]);
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.storage(
          error,
          fallback: 'Could not update profile picture. Please try again.',
        ),
      );
    }
  }

  Future<void> _safeUploadAvatar({
    required dynamic storage,
    required String avatarPath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await storage.uploadBinary(
        avatarPath,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.storage(
          error,
          fallback: 'Could not update profile picture. Please try again.',
        ),
      );
    }
  }

  String _normalizeExtension(String fileExtension) {
    return fileExtension.replaceAll('.', '').toLowerCase();
  }

  String _avatarPathFor(String userId, String extension) {
    return 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  void _ensureSignedAvatarCreated(String? signedUrl) {
    if (signedUrl == null || signedUrl.isEmpty) {
      throw const AppServiceException(
        'Could not prepare profile picture access. Please try again.',
      );
    }
  }

  Future<String?> signedAvatarUrlForUser(User? user) {
    final avatarPath = user?.userMetadata?['avatar_path']?.toString();
    return createSignedAvatarUrl(avatarPath);
  }

  Future<String?> createSignedAvatarUrl(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    try {
      return await _client.storage
          .from(avatarBucket)
          .createSignedUrl(avatarPath, _avatarSignedUrlExpiresIn);
    } catch (_) {
      return null;
    }
  }

  @override
  String normalizeMalaysiaPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    final withoutCountryCode = digitsOnly.startsWith('60')
        ? digitsOnly.substring(2)
        : digitsOnly;
    final withoutLeadingZero = withoutCountryCode.replaceFirst(
      RegExp(r'^0+'),
      '',
    );

    if (withoutLeadingZero.isEmpty) {
      return '';
    }

    return '+60$withoutLeadingZero';
  }

  @override
  Future<AvatarUploadResult> replaceAvatar({
    required AvatarUploadInput input,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) {
      throw const AppServiceException(
        'You need to log in before updating profile.',
      );
    }

    final storage = _client.storage.from(avatarBucket);
    final normalizedExtension = _normalizeExtension(input.fileExtension);
    final avatarPath = _avatarPathFor(userId, normalizedExtension);

    await _safeUploadAvatar(
      storage: storage,
      avatarPath: avatarPath,
      bytes: input.bytes,
      contentType: input.contentType,
    );

    final signedUrl = await createSignedAvatarUrl(avatarPath);
    _ensureSignedAvatarCreated(signedUrl);

    return AvatarUploadResult(path: avatarPath, url: signedUrl);
  }

  @override
  Future<void> deleteAvatar(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) {
      return;
    }

    await _safeRemoveAvatar(
      storage: _client.storage.from(avatarBucket),
      oldAvatarPath: avatarPath,
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentUser?.email;
    if (email == null) {
      throw const AppServiceException(
        'You need to log in before changing password.',
      );
    }

    try {
      await _authService.signIn(email: email, password: currentPassword);
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.auth(
          error,
          fallback: 'Could not change password. Please try again.',
        ),
      );
    }
  }
}
