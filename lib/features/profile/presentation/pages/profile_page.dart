import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../features/auth/application/auth_validators.dart';
import '../../../../shared/widgets/app_page_shell.dart';
import '../../domain/entities/profile_details.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _maxAvatarSizeBytes = 5 * 1024 * 1024;

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ProfileRepository? _profileRepositoryValue;
  TextEditingController? _firstNameControllerValue;
  TextEditingController? _lastNameControllerValue;
  Uint8List? _selectedAvatarBytes;
  String? _selectedAvatarExtension;
  String? _selectedAvatarContentType;
  String? _avatarUrl;
  String? _avatarPath;
  String? _email;
  String _savedFirstName = '';
  String _savedLastName = '';
  String _savedPhone = '';
  bool _isProfileSaving = false;
  bool _isPasswordSaving = false;
  bool _isAvatarPreparing = false;
  bool _isApplyingProfile = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
  String? _profileErrorMessage;
  String? _passwordErrorMessage;

  ProfileRepository get _profileRepository => _profileRepositoryValue!;

  TextEditingController get _firstNameController =>
      _firstNameControllerValue ??= _profileTextController();

  TextEditingController get _lastNameController =>
      _lastNameControllerValue ??= _profileTextController();

  bool get _hasProfileChanges {
    final normalizedFirstName = _firstNameController.text.trim();
    final normalizedLastName = _lastNameController.text.trim();
    final normalizedPhone = _profileRepository.normalizeMalaysiaPhone(
      _phoneController.text,
    );

    return normalizedFirstName != _savedFirstName ||
        normalizedLastName != _savedLastName ||
        normalizedPhone != _savedPhone ||
        _selectedAvatarBytes != null;
  }

  bool get _canSaveProfile => _hasProfileChanges && !_isProfileSaving;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_handleProfileInputChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final profileService = AppDependencies.of(context).profileRepository;
    if (!identical(_profileRepositoryValue, profileService)) {
      _profileRepositoryValue = profileService;
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_handleProfileInputChanged);
    _firstNameControllerValue?.dispose();
    _lastNameControllerValue?.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  TextEditingController _profileTextController() {
    return TextEditingController()..addListener(_handleProfileInputChanged);
  }

  Future<void> _loadProfile() async {
    final profile = await _profileRepository.getProfile();

    if (!mounted) {
      return;
    }

    _isApplyingProfile = true;
    setState(() {
      _email = profile.email;
      _emailController.text = _email ?? '';
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phone
          .replaceFirst(RegExp(r'^\+?60'), '')
          .replaceFirst(RegExp(r'^0+'), '');
      _avatarPath = profile.avatarPath;
      _avatarUrl = profile.avatarUrl;
      _savedFirstName = _firstNameController.text.trim();
      _savedLastName = _lastNameController.text.trim();
      _savedPhone = _profileRepository.normalizeMalaysiaPhone(
        _phoneController.text,
      );
    });
    _isApplyingProfile = false;
  }

  void _handleProfileInputChanged() {
    if (_isApplyingProfile) {
      return;
    }

    setState(() {});
  }

  Future<void> _pickAvatar() async {
    if (_isAvatarPreparing || _isProfileSaving) {
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    final file = result?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }

    if (file.bytes!.lengthInBytes > _maxAvatarSizeBytes) {
      if (mounted) {
        _showMessage(
          'Profile picture must be 5 MB or smaller. Please choose a smaller image.',
          isError: true,
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _isAvatarPreparing = true);

    Uint8List? croppedBytes;
    try {
      await _letAvatarLoadingPaint();
      if (!mounted) {
        return;
      }

      await precacheImage(MemoryImage(file.bytes!), context);
      await _letAvatarLoadingPaint();
      if (!mounted) {
        return;
      }

      croppedBytes = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AvatarCropDialog(imageBytes: file.bytes!),
      );
    } finally {
      if (mounted) {
        setState(() => _isAvatarPreparing = false);
      }
    }

    if (croppedBytes == null) {
      return;
    }

    setState(() {
      _selectedAvatarBytes = croppedBytes;
      _selectedAvatarExtension = file.extension ?? 'jpg';
      _selectedAvatarContentType = _contentTypeFor(file.extension);
    });
  }

  Future<void> _letAvatarLoadingPaint() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await SchedulerBinding.instance.endOfFrame;
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isProfileSaving = true;
      _profileErrorMessage = null;
    });

    AvatarUploadResult? uploadedAvatar;
    final oldAvatarPath = _avatarPath;
    try {
      var avatarPath = _avatarPath;

      if (_selectedAvatarBytes != null) {
        uploadedAvatar = await _profileRepository.replaceAvatar(
          input: AvatarUploadInput(
            bytes: _selectedAvatarBytes!,
            fileExtension: _selectedAvatarExtension ?? 'jpg',
            contentType: _selectedAvatarContentType ?? 'image/jpeg',
          ),
        );

        avatarPath = uploadedAvatar.path;
      }

      await _profileRepository.updateProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        avatarPath: avatarPath,
      );

      if (uploadedAvatar != null && oldAvatarPath != avatarPath) {
        try {
          await _profileRepository.deleteAvatar(oldAvatarPath);
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _avatarPath = avatarPath;
        _avatarUrl = uploadedAvatar?.url ?? _avatarUrl;
        _selectedAvatarBytes = null;
        _selectedAvatarExtension = null;
        _selectedAvatarContentType = null;
        _savedFirstName = _firstNameController.text.trim();
        _savedLastName = _lastNameController.text.trim();
        _savedPhone = _profileRepository.normalizeMalaysiaPhone(
          _phoneController.text,
        );
      });
      _showMessage('Profile updated.');
    } catch (error) {
      if (uploadedAvatar != null) {
        try {
          await _profileRepository.deleteAvatar(uploadedAvatar.path);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _profileErrorMessage = _cleanError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isProfileSaving = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isPasswordSaving = true;
      _passwordErrorMessage = null;
    });

    try {
      await _profileRepository.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        _showMessage('Password updated.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _passwordErrorMessage = _cleanError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isPasswordSaving = false);
      }
    }
  }

  String _contentTypeFor(String? extension) {
    return switch (extension?.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  String _cleanError(Object error) {
    return AppErrorMapper.friendly(error);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primaryDark : AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      currentRoute: AppRoutes.profile,
      title: 'Profile',
      subtitle: 'Manage your UTeM identity and security',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = ResponsiveBreakpoints.isDesktop(
            constraints.maxWidth,
          );

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _profileCard(context)),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: _passwordCard(context)),
              ],
            );
          }

          return Column(
            children: [
              _profileCard(context),
              const SizedBox(height: 20),
              _passwordCard(context),
            ],
          );
        },
      ),
    );
  }

  Widget _profileCard(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Profile information',
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _AvatarPicker(
                avatarUrl: _avatarUrl,
                selectedBytes: _selectedAvatarBytes,
                isLoading: _isAvatarPreparing,
                onPick: _pickAvatar,
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackNameFields = constraints.maxWidth < 520;
                final firstNameField = TextFormField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) =>
                      AuthValidators.name(value, 'First name'),
                );
                final lastNameField = TextFormField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => AuthValidators.name(value, 'Last name'),
                );

                if (stackNameFields) {
                  return Column(
                    children: [
                      firstNameField,
                      const SizedBox(height: 16),
                      lastNameField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: firstNameField),
                    const SizedBox(width: 12),
                    Expanded(child: lastNameField),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: _PhonePrefix(),
                hintText: '123456789',
              ),
              validator: AuthValidators.malaysiaPhone,
            ),
            if (_profileErrorMessage != null) ...[
              const SizedBox(height: 16),
              _InlineErrorMessage(message: _profileErrorMessage!),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _canSaveProfile ? _saveProfile : null,
              icon: _isProfileSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isProfileSaving ? 'Saving...' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordCard(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Change password',
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your current password first, then choose a new password.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedInk,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _PasswordField(
              controller: _currentPasswordController,
              label: 'Current password',
              isHidden: _hideCurrentPassword,
              onToggleVisibility: () =>
                  setState(() => _hideCurrentPassword = !_hideCurrentPassword),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Current password is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _newPasswordController,
              label: 'New password',
              isHidden: _hideNewPassword,
              onToggleVisibility: () =>
                  setState(() => _hideNewPassword = !_hideNewPassword),
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm new password',
              isHidden: _hideConfirmPassword,
              onToggleVisibility: () =>
                  setState(() => _hideConfirmPassword = !_hideConfirmPassword),
              validator: (value) => AuthValidators.confirmPassword(
                value,
                _newPasswordController.text,
              ),
            ),
            if (_passwordErrorMessage != null) ...[
              const SizedBox(height: 16),
              _InlineErrorMessage(message: _passwordErrorMessage!),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isPasswordSaving ? null : _changePassword,
              icon: _isPasswordSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_rounded),
              label: Text(
                _isPasswordSaving ? 'Updating...' : 'Update password',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.avatarUrl,
    required this.selectedBytes,
    required this.isLoading,
    required this.onPick,
  });

  final String? avatarUrl;
  final Uint8List? selectedBytes;
  final bool isLoading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final image = selectedBytes != null
        ? MemoryImage(selectedBytes!)
        : avatarUrl != null && avatarUrl!.isNotEmpty
        ? NetworkImage(avatarUrl!)
        : null;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundImage: image as ImageProvider?,
              child: image == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 58,
                    )
                  : null,
            ),
            if (isLoading)
              const SizedBox.square(
                dimension: 116,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xB3FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onPick,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera_rounded),
          label: Text(isLoading ? 'Preparing...' : 'Change picture'),
        ),
      ],
    );
  }
}

class _PhonePrefix extends StatelessWidget {
  const _PhonePrefix();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14, right: 8, top: 15),
      child: Text(
        '+60',
        style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.isHidden,
    required this.onToggleVisibility,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool isHidden;
  final VoidCallback onToggleVisibility;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isHidden,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: isHidden ? 'Show password' : 'Hide password',
          onPressed: onToggleVisibility,
          icon: Icon(
            isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
        ),
      ),
      validator: validator,
    );
  }
}

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CropBusyOverlay extends StatelessWidget {
  const _CropBusyOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.ink.withValues(alpha: 0.74),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  static const _cropCornerHandleGutter = 16.0;
  static const _dialogInset = 16.0;
  static const _dialogPadding = 20.0;
  static const _cropFooterReserve = 170.0;
  static const _minCropSize = 240.0;

  final _controller = CropController();
  bool _isCropping = false;
  bool _isReady = false;

  Future<void> _crop() async {
    if (!_isReady || _isCropping) {
      return;
    }

    setState(() => _isCropping = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));

    if (!mounted) {
      return;
    }

    _controller.crop();
  }

  void _handleCropResult(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure(:final cause):
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cause.toString()),
            backgroundColor: AppColors.primaryDark,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final dialogWidth = size.width >= ResponsiveBreakpoints.desktop
        ? 680.0
        : math.max(0.0, size.width - (_dialogInset * 2));
    final dialogHeight = math.max(
      0.0,
      size.height - (_dialogInset * 2) - viewInsets.vertical,
    );
    final stackActions = size.width < 420;
    final contentWidth = math.max(0.0, dialogWidth - (_dialogPadding * 2));
    final maxCropSize = math.min(
      contentWidth,
      dialogHeight - (_dialogPadding * 2) - _cropFooterReserve,
    );
    final cropSize = maxCropSize
        .clamp(math.min(_minCropSize, contentWidth), contentWidth)
        .toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(_dialogInset),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(_dialogPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Crop profile picture',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isCropping
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Move and resize the square area before saving.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox.square(
                  dimension: cropSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(
                              _cropCornerHandleGutter,
                            ),
                            child: IgnorePointer(
                              ignoring: _isCropping,
                              child: Crop(
                                image: widget.imageBytes,
                                controller: _controller,
                                aspectRatio: 1,
                                initialRectBuilder:
                                    InitialRectBuilder.withSizeAndRatio(
                                      size: 1,
                                      aspectRatio: 1,
                                    ),
                                interactive: true,
                                baseColor: AppColors.ink,
                                clipBehavior: Clip.none,
                                maskColor: AppColors.ink.withValues(
                                  alpha: 0.62,
                                ),
                                radius: 8,
                                progressIndicator: const _CropBusyOverlay(
                                  message: 'Preparing image...',
                                ),
                                onStatusChanged: (status) {
                                  if (status == CropStatus.ready && !_isReady) {
                                    setState(() => _isReady = true);
                                  }
                                },
                                onCropped: _handleCropResult,
                              ),
                            ),
                          ),
                          if (!_isReady)
                            const _CropBusyOverlay(
                              message: 'Preparing image...',
                            ),
                          if (_isCropping)
                            const _CropBusyOverlay(
                              message:
                                  'Applying crop... The screen may look frozen for a moment, but it is still working.',
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (stackActions) ...[
                OutlinedButton(
                  onPressed: _isCropping
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isReady && !_isCropping ? _crop : null,
                  icon: _isCropping
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    !_isReady
                        ? 'Preparing...'
                        : _isCropping
                        ? 'Cropping...'
                        : 'Use picture',
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isCropping
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isReady && !_isCropping ? _crop : null,
                        icon: _isCropping
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          !_isReady
                              ? 'Preparing...'
                              : _isCropping
                              ? 'Cropping...'
                              : 'Use picture',
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
