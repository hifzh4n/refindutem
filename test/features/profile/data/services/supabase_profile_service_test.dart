import 'package:flutter_test/flutter_test.dart';
import 'package:refindutem/features/profile/data/services/supabase_profile_service.dart';

void main() {
  group('SupabaseProfileService', () {
    test('normalizes Malaysia phone numbers to +60 format', () {
      final service = SupabaseProfileService();

      expect(service.normalizeMalaysiaPhone('012-345 6789'), '+60123456789');
      expect(service.normalizeMalaysiaPhone('+60123456789'), '+60123456789');
      expect(service.normalizeMalaysiaPhone('123456789'), '+60123456789');
    });

    test('keeps empty optional phone value empty', () {
      final service = SupabaseProfileService();

      expect(service.normalizeMalaysiaPhone(''), '');
    });
  });
}
