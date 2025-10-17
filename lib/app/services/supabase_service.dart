import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  late final SupabaseClient client;

  Future<void> init({required String url, required String apiKey}) async {
    await Supabase.initialize(url: url, anonKey: apiKey);
    client = Supabase.instance.client;
  }

  User? get currentUser => client.auth.currentUser;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return {'data': res, 'error': null};
    } on AuthException catch (e) {
      return {'data': null, 'error': e.message};
    } catch (e) {
      return {'data': null, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse res = await client.auth.signUp(
        email: email,
        password: password,
      );
      return {'data': res, 'error': null};
    } on AuthException catch (e) {
      return {'data': null, 'error': e.message};
    } catch (e) {
      return {'data': null, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      await client.auth.resetPasswordForEmail(email);

      return {'data': true, 'error': null};
    } catch (e) {
      return {'data': null, 'error': e.toString()};
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
