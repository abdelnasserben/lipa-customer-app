import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/customer_repository.dart';
import 'auth/token_store.dart';
import 'config/app_environment.dart';
import 'network/api_client.dart';

/// Build-time configuration. Overridable in tests.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});

/// Dio-backed API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  return ApiAuthRepository(ref.watch(apiClientProvider), tokenStore);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return ApiCustomerRepository(ref.watch(apiClientProvider));
});
