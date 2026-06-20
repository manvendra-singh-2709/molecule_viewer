import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://kypcdyvwffcbubqrybqh.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_9YVS2n7DavQwQYXLklUM5w_lQ8WVgzI';

  static const String structuresBucket = 'Structures';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}