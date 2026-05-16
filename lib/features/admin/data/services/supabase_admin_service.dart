import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';

class SupabaseAdminService {
  SupabaseAdminService();

  static const _imageSignedUrlExpiresIn = 3600;

  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> isAdmin() async {
    try {
      final result = await _client.rpc('is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<AdminDashboardStats> fetchStats() async {
    try {
      final result = await _client.rpc('admin_dashboard_stats');
      return AdminDashboardStats.fromJson(Map<String, dynamic>.from(result));
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not load admin dashboard stats.',
        ),
      );
    }
  }

  Future<List<AdminUserRow>> fetchUsers() async {
    try {
      final rows = await _client.rpc('admin_list_users');
      final users = (rows as List)
          .map((row) => AdminUserRow.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return Future.wait(users.map(_withSignedAvatarUrl));
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(error, fallback: 'Could not load users.'),
      );
    }
  }

  Future<void> updateUser(AdminUserInput input) async {
    try {
      await _client.rpc(
        'admin_update_user',
        params: {
          'target_user_id': input.id,
          'first_name': input.firstName,
          'last_name': input.lastName,
          'make_admin': input.isAdmin,
        },
      );
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(error, fallback: 'Could not update user.'),
      );
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _client.rpc(
        'admin_delete_user',
        params: {'target_user_id': userId},
      );
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(error, fallback: 'Could not delete user.'),
      );
    }
  }

  Future<List<AdminLostReportRow>> fetchLostReports() async {
    try {
      final rows = await _client
          .from('lost_item_reports')
          .select()
          .order('created_at', ascending: false);
      final reports = rows.map(AdminLostReportRow.fromJson).toList();
      return Future.wait(
        reports.map(
          (report) => _withSignedReportImageUrl(report, 'lost-item-images'),
        ),
      );
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not load lost item reports.',
        ),
      );
    }
  }

  Future<List<AdminFoundReportRow>> fetchFoundReports() async {
    try {
      final rows = await _client
          .from('found_item_reports')
          .select()
          .order('created_at', ascending: false);
      final reports = rows.map(AdminFoundReportRow.fromJson).toList();
      return Future.wait(
        reports.map(
          (report) => _withSignedReportImageUrl(report, 'found-item-images'),
        ),
      );
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not load found item reports.',
        ),
      );
    }
  }

  Future<void> upsertLostReport(AdminLostReportInput input) async {
    try {
      final payload = input.toJson();
      if (input.id == null) {
        await _client.from('lost_item_reports').insert(payload);
      } else {
        await _client
            .from('lost_item_reports')
            .update(payload)
            .eq('id', input.id!);
      }
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not save lost item report.',
        ),
      );
    }
  }

  Future<void> upsertFoundReport(AdminFoundReportInput input) async {
    try {
      final payload = input.toJson();
      if (input.id == null) {
        await _client.from('found_item_reports').insert(payload);
      } else {
        await _client
            .from('found_item_reports')
            .update(payload)
            .eq('id', input.id!);
      }
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not save found item report.',
        ),
      );
    }
  }

  Future<void> deleteLostReport(String reportId) async {
    try {
      await _client.from('lost_item_reports').delete().eq('id', reportId);
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not delete lost item report.',
        ),
      );
    }
  }

  Future<void> deleteFoundReport(String reportId) async {
    try {
      await _client.from('found_item_reports').delete().eq('id', reportId);
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.friendly(
          error,
          fallback: 'Could not delete found item report.',
        ),
      );
    }
  }

  Future<AdminUserRow> _withSignedAvatarUrl(AdminUserRow user) async {
    if (user.avatarPath.isEmpty) {
      return user;
    }

    try {
      final url = await _client.storage
          .from('profiles')
          .createSignedUrl(user.avatarPath, _imageSignedUrlExpiresIn);
      return user.copyWith(avatarUrl: url);
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('not found') || message.contains('does not exist')) {
        return user;
      }

      throw AppServiceException(
        AppErrorMapper.storage(
          error,
          fallback:
              'Could not load user profile pictures. Apply the admin storage policy migration and try again.',
        ),
      );
    }
  }

  Future<T> _withSignedReportImageUrl<T extends AdminReportImageRow>(
    T report,
    String bucket,
  ) async {
    if (report.imagePath.isEmpty) {
      return report;
    }

    try {
      final url = await _client.storage
          .from(bucket)
          .createSignedUrl(report.imagePath, _imageSignedUrlExpiresIn);
      return report.copyWithImageUrl(url) as T;
    } catch (_) {
      return report;
    }
  }
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.users,
    required this.admins,
    required this.lostOpen,
    required this.lostTotal,
    required this.foundOpen,
    required this.foundTotal,
  });

  final int users;
  final int admins;
  final int lostOpen;
  final int lostTotal;
  final int foundOpen;
  final int foundTotal;

  factory AdminDashboardStats.empty() {
    return const AdminDashboardStats(
      users: 0,
      admins: 0,
      lostOpen: 0,
      lostTotal: 0,
      foundOpen: 0,
      foundTotal: 0,
    );
  }

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => int.tryParse(json[key]?.toString() ?? '') ?? 0;

    return AdminDashboardStats(
      users: readInt('users'),
      admins: readInt('admins'),
      lostOpen: readInt('lost_open'),
      lostTotal: readInt('lost_total'),
      foundOpen: readInt('found_open'),
      foundTotal: readInt('found_total'),
    );
  }
}

class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.email,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.avatarPath,
    required this.avatarUrl,
    required this.isAdmin,
    required this.createdAt,
    required this.lastSignInAt,
  });

  final String id;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final String avatarPath;
  final String? avatarUrl;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime? lastSignInAt;

  String get name {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? 'Unnamed user' : fullName;
  }

  factory AdminUserRow.fromJson(Map<String, dynamic> json) {
    return AdminUserRow(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      avatarPath: json['avatar_path']?.toString() ?? '',
      avatarUrl: null,
      isAdmin: json['is_admin'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      lastSignInAt: DateTime.tryParse(
        json['last_sign_in_at']?.toString() ?? '',
      ),
    );
  }

  AdminUserRow copyWith({String? avatarUrl}) {
    return AdminUserRow(
      id: id,
      email: email,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      avatarPath: avatarPath,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAdmin: isAdmin,
      createdAt: createdAt,
      lastSignInAt: lastSignInAt,
    );
  }
}

class AdminUserInput {
  const AdminUserInput({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.isAdmin,
  });

  final String id;
  final String firstName;
  final String lastName;
  final bool isAdmin;
}

abstract class AdminReportImageRow {
  String get imagePath;
  AdminReportImageRow copyWithImageUrl(String imageUrl);
}

class AdminLostReportRow implements AdminReportImageRow {
  const AdminLostReportRow({
    required this.id,
    required this.userId,
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
  final String userId;
  final String itemName;
  final String category;
  final DateTime lostDate;
  final String location;
  final String description;
  final String contactMethod;
  final String contactDetail;
  final String status;
  @override
  final String imagePath;
  final String? imageUrl;
  final DateTime createdAt;

  factory AdminLostReportRow.fromJson(Map<String, dynamic> json) {
    return AdminLostReportRow(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      lostDate:
          DateTime.tryParse(json['lost_date']?.toString() ?? '') ??
          DateTime.now(),
      location: json['location']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      contactMethod: json['contact_method']?.toString() ?? 'Phone',
      contactDetail: json['contact_detail']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      imagePath: json['image_path']?.toString() ?? '',
      imageUrl: null,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  AdminLostReportRow copyWithImageUrl(String imageUrl) {
    return AdminLostReportRow(
      id: id,
      userId: userId,
      itemName: itemName,
      category: category,
      lostDate: lostDate,
      location: location,
      description: description,
      contactMethod: contactMethod,
      contactDetail: contactDetail,
      status: status,
      imagePath: imagePath,
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }
}

class AdminFoundReportRow implements AdminReportImageRow {
  const AdminFoundReportRow({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.category,
    required this.foundDate,
    required this.location,
    required this.description,
    required this.handoverStatus,
    required this.contactMethod,
    required this.contactDetail,
    required this.status,
    required this.imagePath,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String itemName;
  final String category;
  final DateTime foundDate;
  final String location;
  final String description;
  final String handoverStatus;
  final String contactMethod;
  final String contactDetail;
  final String status;
  @override
  final String imagePath;
  final String? imageUrl;
  final DateTime createdAt;

  factory AdminFoundReportRow.fromJson(Map<String, dynamic> json) {
    return AdminFoundReportRow(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      foundDate:
          DateTime.tryParse(json['found_date']?.toString() ?? '') ??
          DateTime.now(),
      location: json['location']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      handoverStatus: json['handover_status']?.toString() ?? 'Keeping safely',
      contactMethod: json['contact_method']?.toString() ?? 'Phone',
      contactDetail: json['contact_detail']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      imagePath: json['image_path']?.toString() ?? '',
      imageUrl: null,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  AdminFoundReportRow copyWithImageUrl(String imageUrl) {
    return AdminFoundReportRow(
      id: id,
      userId: userId,
      itemName: itemName,
      category: category,
      foundDate: foundDate,
      location: location,
      description: description,
      handoverStatus: handoverStatus,
      contactMethod: contactMethod,
      contactDetail: contactDetail,
      status: status,
      imagePath: imagePath,
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }
}

class AdminLostReportInput {
  const AdminLostReportInput({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.category,
    required this.lostDate,
    required this.location,
    required this.description,
    required this.contactMethod,
    required this.contactDetail,
    required this.status,
  });

  final String? id;
  final String userId;
  final String itemName;
  final String category;
  final DateTime lostDate;
  final String location;
  final String description;
  final String contactMethod;
  final String contactDetail;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'item_name': itemName.trim(),
      'category': category,
      'lost_date': _date(lostDate),
      'location': location.trim(),
      'description': description.trim(),
      'contact_method': contactMethod,
      'contact_detail': contactDetail.trim(),
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class AdminFoundReportInput {
  const AdminFoundReportInput({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.category,
    required this.foundDate,
    required this.location,
    required this.description,
    required this.handoverStatus,
    required this.contactMethod,
    required this.contactDetail,
    required this.status,
  });

  final String? id;
  final String userId;
  final String itemName;
  final String category;
  final DateTime foundDate;
  final String location;
  final String description;
  final String handoverStatus;
  final String contactMethod;
  final String contactDetail;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'item_name': itemName.trim(),
      'category': category,
      'found_date': _date(foundDate),
      'location': location.trim(),
      'description': description.trim(),
      'handover_status': handoverStatus,
      'contact_method': contactMethod,
      'contact_detail': contactDetail.trim(),
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

String _date(DateTime date) => date.toIso8601String().split('T').first;
