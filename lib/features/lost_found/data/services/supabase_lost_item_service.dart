import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';

class SupabaseLostItemService {
  SupabaseLostItemService();

  static const imageBucket = 'lost-item-images';
  static const _imageSignedUrlExpiresIn = 3600;
  static const defaultPageSize = 20;
  static const _maxImageSizeBytes = 5 * 1024 * 1024;
  static const _uploadTimeout = Duration(seconds: 30);
  static const _allowedImageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<LostItemReport>> fetchMyReports() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppServiceException(
        'You need to log in before viewing reports.',
      );
    }

    try {
      final rows = await _client
          .from('lost_item_reports')
          .select(
            'id, item_name, category, lost_date, location, description, contact_method, contact_detail, status, image_path, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return _withSignedImageUrls(rows.map(LostItemReport.fromJson).toList());
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not load your lost item reports.',
        ),
      );
    }
  }

  Future<List<LostItemReport>> fetchOpenReports({
    int page = 0,
    int pageSize = defaultPageSize,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppServiceException(
        'You need to log in before viewing reports.',
      );
    }

    try {
      final rows = await _client
          .from('lost_item_reports')
          .select(
            'id, user_id, item_name, category, lost_date, location, description, contact_method, contact_detail, status, image_path, created_at',
          )
          .eq('status', 'open')
          .neq('user_id', userId)
          .order('created_at', ascending: false)
          .range(page * pageSize, ((page + 1) * pageSize) - 1);

      return _withSignedImageUrls(rows.map(LostItemReport.fromJson).toList());
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not load lost item reports.',
        ),
      );
    }
  }

  Future<void> reportLostItem({
    required String itemName,
    required String category,
    required DateTime lostDate,
    required String location,
    required String description,
    required String contactMethod,
    Uint8List? imageBytes,
    String? imageExtension,
    String? imageContentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppServiceException(
        'You need to log in before reporting an item.',
      );
    }

    String? imagePath;

    try {
      final contactDetail = await _contactDetailFor(contactMethod);
      imagePath = imageBytes == null
          ? null
          : await _uploadReportImage(
              userId: userId,
              bytes: imageBytes,
              extension: imageExtension ?? 'jpg',
              contentType: imageContentType ?? 'image/jpeg',
            );

      final report = {
        'user_id': userId,
        'item_name': itemName.trim(),
        'category': category,
        'lost_date': lostDate.toIso8601String().split('T').first,
        'location': location.trim(),
        'description': description.trim(),
        'contact_method': contactMethod,
        'contact_detail': contactDetail.trim(),
      };

      if (imagePath != null) {
        report['image_path'] = imagePath;
      }

      await _client.from('lost_item_reports').insert(report);
    } catch (error) {
      if (imagePath != null) {
        await _removeReportImage(imagePath);
      }

      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not submit lost item report.',
        ),
      );
    }
  }

  Future<void> markReportSolved(String reportId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppServiceException(
        'You need to log in before updating a report.',
      );
    }

    try {
      await _client
          .from('lost_item_reports')
          .update({
            'status': 'closed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId)
          .eq('user_id', userId);
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not mark this lost report as solved.',
        ),
      );
    }
  }

  Future<String> _contactDetailFor(String contactMethod) async {
    final user =
        (await _client.auth.getUser()).user ?? _client.auth.currentUser;
    final normalizedMethod = contactMethod.toLowerCase();

    if (normalizedMethod == 'email') {
      final email = user?.email?.trim() ?? '';
      if (email.isEmpty) {
        throw const AppServiceException(
          'Add your email to your profile before choosing email contact.',
        );
      }

      return email;
    }

    if (normalizedMethod == 'phone') {
      final metadataPhone = user?.userMetadata?['phone']?.toString().trim();
      final authPhone = user?.phone?.trim();
      final phone = (metadataPhone != null && metadataPhone.isNotEmpty)
          ? metadataPhone
          : authPhone ?? '';

      if (phone.isEmpty) {
        throw const AppServiceException(
          'Add your phone number in Profile before choosing phone contact.',
        );
      }

      return phone;
    }

    throw const AppServiceException('Choose a valid contact preference.');
  }

  Future<String> _uploadReportImage({
    required String userId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    _validateReportImage(bytes: bytes, contentType: contentType);
    final normalizedExtension = extension.replaceAll('.', '').toLowerCase();
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$normalizedExtension';

    await _client.storage
        .from(imageBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        )
        .timeout(_uploadTimeout);

    return path;
  }

  void _validateReportImage({
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.lengthInBytes > _maxImageSizeBytes) {
      throw const AppServiceException(
        'Item image must be 5 MB or smaller. Please choose a smaller image.',
      );
    }

    if (!_allowedImageTypes.contains(contentType)) {
      throw const AppServiceException(
        'Use a JPG, PNG, WebP, or GIF image for the item photo.',
      );
    }
  }

  Future<void> _removeReportImage(String path) async {
    try {
      await _client.storage.from(imageBucket).remove([path]);
    } catch (_) {}
  }

  Future<List<LostItemReport>> _withSignedImageUrls(
    List<LostItemReport> reports,
  ) async {
    return Future.wait(
      reports.map((report) async {
        if (report.imagePath == null || report.imagePath!.isEmpty) {
          return report;
        }

        try {
          final signedUrl = await _client.storage
              .from(imageBucket)
              .createSignedUrl(report.imagePath!, _imageSignedUrlExpiresIn);
          return report.copyWith(imageUrl: signedUrl);
        } catch (_) {
          return report;
        }
      }),
    );
  }
}

class LostItemReport {
  const LostItemReport({
    required this.id,
    required this.itemName,
    required this.category,
    required this.lostDate,
    required this.location,
    required this.description,
    required this.contactMethod,
    required this.contactDetail,
    required this.status,
    required this.imagePath,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String itemName;
  final String category;
  final DateTime lostDate;
  final String location;
  final String description;
  final String contactMethod;
  final String contactDetail;
  final String status;
  final String? imagePath;
  final String? imageUrl;
  final DateTime createdAt;

  factory LostItemReport.fromJson(Map<String, dynamic> json) {
    return LostItemReport(
      id: json['id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      lostDate:
          DateTime.tryParse(json['lost_date']?.toString() ?? '') ??
          DateTime.now(),
      location: json['location']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      contactMethod: json['contact_method']?.toString() ?? '',
      contactDetail: json['contact_detail']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      imagePath: json['image_path']?.toString(),
      imageUrl: null,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  LostItemReport copyWith({String? imageUrl}) {
    return LostItemReport(
      id: id,
      itemName: itemName,
      category: category,
      lostDate: lostDate,
      location: location,
      description: description,
      contactMethod: contactMethod,
      contactDetail: contactDetail,
      status: status,
      imagePath: imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
    );
  }
}
