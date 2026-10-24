import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/models.dart';
import '../api/session_broadcast.dart';
import '../auth/vault_session.dart';
import '../crypto/local_unlock_gate.dart';
import '../crypto/local_unlock_store.dart';
import '../db/vault_storage.dart';
import '../vault/vault_registry.dart';
import 'app_providers.dart';

sealed class AuthFlowState {
  const AuthFlowState();
}

class AuthLoggedOut extends AuthFlowState {
  final String? error;

  final String? prefillEmail;

  final bool totpRequired;

  const AuthLoggedOut({
    this.error,
    this.prefillEmail,
    this.totpRequired = false,
  });
}

class AuthLoggingIn extends AuthFlowState {
  const AuthLoggingIn();
}

class AuthResumingSession extends AuthFlowState {
  const AuthResumingSession();
}

class AuthNeedsVaultSetup extends AuthFlowState {
  final UserApiResponse user;
  const AuthNeedsVaultSetup(this.user);
}

class AuthNeedsUnlock extends AuthFlowState {
  final UserApiResponse user;
  const AuthNeedsUnlock(this.user);
}

class AuthUnlocking extends AuthFlowState {
  final UserApiResponse user;
  const AuthUnlocking(this.user);
}

class AuthReady extends AuthFlowState {
  final UserApiResponse user;
  const AuthReady(this.user);
}

class AuthOfflineNeedsSetup extends AuthFlowState {
  const AuthOfflineNeedsSetup();
}

class AuthOfflineNeedsUnlock extends AuthFlowState {
  const AuthOfflineNeedsUnlock();
}

class AuthOfflineUnlocking extends AuthFlowState {
  const AuthOfflineUnlocking();
}

class AuthOfflineReady extends AuthFlowState {
  const AuthOfflineReady();
}

class AuthNeedsVaultSelection extends AuthFlowState {
  final List<VaultRegistryEntry> vaults;

  final Set<String> connectedEmails;

  const AuthNeedsVaultSelection(this.vaults, {this.connectedEmails = const {}});
}

class AccountAlreadyHasVaultException implements Exception {
  const AccountAlreadyHasVaultException();
}

class RegistrationClosedException implements Exception {
  const RegistrationClosedException();
}

class ActiveVaultCannotBeDeletedException implements Exception {
  const ActiveVaultCannotBeDeletedException();
}

class AuthController extends StateNotifier<AuthFlowState> {
  final Ref ref;
  final Future<bool> Function()? _hasStoredSessionOverride;
  final Future<List<VaultRegistryEntry>> Function()? _knownVaultsOverride;
  final Future<bool> Function({required String reason}) _authenticate;
  StreamSubscription<void>? _crossTabSub;

  AuthController(
    this.ref, {
    Stream<void>? crossTabSessionChanges,
    Future<bool> Function()? hasStoredSessionOverride,
    Future<List<VaultRegistryEntry>> Function()? knownVaultsOverride,
    Future<bool> Function({required String reason})? authenticate,
  }) : _hasStoredSessionOverride = hasStoredSessionOverride,
       _knownVaultsOverride = knownVaultsOverride,
       _authenticate = authenticate ?? authenticateForLocalUnlock,
       super(const AuthLoggedOut()) {
    _crossTabSub = (crossTabSessionChanges ?? watchTokenStoreChangedElsewhere())
        .listen((_) => _handleCrossTabSessionChange());
    _checkKnownVaults();
  }

  Future<void> _checkKnownVaults() async {
    try {
      final vaults = _knownVaultsOverride != null
          ? await _knownVaultsOverride()
          : await _vaultRegistry.list();
      if (state is! AuthLoggedOut) return;
      if (vaults.isEmpty) return;
      final selection = await _selectionFor(vaults);
      if (state is! AuthLoggedOut) return;
      state = selection;
    } catch (_) {}
  }

  Future<AuthNeedsVaultSelection> _selectionFor(
    List<VaultRegistryEntry> vaults,
  ) async => AuthNeedsVaultSelection(
    vaults,
    connectedEmails: await ref
        .read(apiClientProvider)
        .tokenStore
        .connectedAccounts(),
  );

  Future<({bool ok, String? error})> _restoreSession(String email) async {
    try {
      final client = ref.read(apiClientProvider);
      final needsChallenge = !client.tokenStore.hasInMemory(email);
      if (needsChallenge && !await _authenticate(reason: 'Sign in to moopro')) {
        return (ok: false, error: null);
      }
      state = const AuthResumingSession();
      if (!await client.activateSession(email)) return (ok: false, error: null);
      final user = await ref.read(authApiProvider).getCurrentUser();
      await _afterLogin(user, password: '', authenticated: needsChallenge);
      return (ok: true, error: null);
    } catch (e) {
      return (ok: false, error: 'Could not resume your session: $e');
    }
  }

  Future<void> _selectOfflineVault(VaultRegistryEntry vault) async {
    ref.read(activeVaultProvider.notifier).state = vault;
    if (await _vaultSession.tryUnlockFromLocalCache()) {
      await _touchActiveVault();
      state = const AuthOfflineReady();
      return;
    }
    state = const AuthOfflineNeedsUnlock();
  }

  VaultSessionManager get _vaultSession =>
      ref.read(vaultSessionManagerProvider);
  VaultRegistry get _vaultRegistry => ref.read(vaultRegistryProvider);

  Future<void> _touchActiveVault() async {
    final active = ref.read(activeVaultProvider);
    if (active != null) await _vaultRegistry.touch(active.id);
  }

  Future<bool> _hasStoredSession() async {
    if (_hasStoredSessionOverride != null) return _hasStoredSessionOverride();
    return ref.read(apiClientProvider).tokenStore.hasSession();
  }

  Future<void> _handleCrossTabSessionChange() async {
    if (!await _hasStoredSession() && state is! AuthLoggedOut) {
      _vaultSession.lock();
      ref.invalidate(domainCacheDatabaseProvider);
      state = const AuthLoggedOut();
    }
  }

  @override
  void dispose() {
    _crossTabSub?.cancel();
    super.dispose();
  }

  Future<void> login({
    required String email,
    required String password,
    String? totpCode,
    bool stayLoggedIn = false,
  }) async {
    state = const AuthLoggingIn();
    final tokenStore = ref.read(apiClientProvider).tokenStore;
    tokenStore.useAccount(email);
    tokenStore.persist = stayLoggedIn;
    try {
      final loggedIn = await ref
          .read(authApiProvider)
          .login(email: email, password: password, totpCode: totpCode);
      await _afterLogin(loggedIn.userData, password: password);
    } on DioException catch (e) {
      if (_dioErrorCode(e) == 'TOTP_REQUIRED') {
        state = const AuthLoggedOut(totpRequired: true);
        return;
      }
      final message = e.response?.statusCode == 401
          ? (totpCode != null
                ? 'Incorrect email, password or code'
                : 'Incorrect email or password')
          : 'Login failed: ${e.message}';
      state = AuthLoggedOut(error: message, totpRequired: totpCode != null);
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = const AuthLoggingIn();
    final tokenStore = ref.read(apiClientProvider).tokenStore;
    tokenStore.useAccount(email);
    tokenStore.persist = false;
    try {
      final registered = await ref
          .read(authApiProvider)
          .register(email: email, password: password);
      await _afterLogin(registered.userData, password: password);
    } on DioException catch (e) {
      state = const AuthLoggedOut();
      if (_dioErrorCode(e) == 'ACCOUNT_CREATION_DISABLED') {
        throw const RegistrationClosedException();
      }
      state = AuthLoggedOut(error: _registerErrorMessage(e));
    }
  }

  Future<void> requestAccount({required String email}) async {
    await ref.read(authApiProvider).requestAccount(email: email);
  }

  Future<bool> checkRegistrationStatus() async {
    final status = await ref.read(authApiProvider).checkRegistrationStatus();
    return status.enabled;
  }

  String? _dioErrorCode(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is Map) {
      return (data['detail'] as Map)['code'] as String?;
    }
    return null;
  }

  String _registerErrorMessage(DioException e) {
    switch (_dioErrorCode(e)) {
      case 'EMAIL_UNAVAILABLE':
        return 'An account with that email already exists.';
      case 'EMAIL_INVALID':
        return 'That email address doesn\'t look valid.';
      case 'WEAK_PASSWORD':
        return 'Choose a stronger password.';
      default:
        return 'Registration failed: ${e.message}';
    }
  }

  Future<void> _afterLogin(
    UserApiResponse user, {
    required String password,
    bool authenticated = false,
  }) async {
    final vault = await _vaultRegistry.resolveOnlineVault(
      email: user.email,
      label: user.email,
    );
    ref.read(activeVaultProvider.notifier).state = vault;

    if (!user.hasVaultKeyMaterial) {
      state = AuthNeedsVaultSetup(user);
      return;
    }
    if (await _vaultSession.tryUnlockFromLocalCache(
      challenge: !authenticated,
    )) {
      await _touchActiveVault();
      state = AuthReady(user);
      return;
    }
    state = AuthNeedsUnlock(user);
  }

  Future<void> _saveKeyIfRequested(bool saveKey) async {
    if (!saveKey) return;
    try {
      await _vaultSession.enableLocalUnlock();
    } catch (_) {}
  }

  Future<void> completeVaultSetup({
    required UserApiResponse user,
    required String password,
    bool saveKey = false,
  }) async {
    state = AuthUnlocking(user);
    try {
      await _vaultSession.completeInitialVaultSetup(password: password);
      await _saveKeyIfRequested(saveKey);
      await _touchActiveVault();
      state = AuthReady(user);
    } catch (e) {
      state = AuthNeedsVaultSetup(user);
      rethrow;
    }
  }

  Future<void> unlock({
    required UserApiResponse user,
    required String password,
    bool saveKey = false,
  }) async {
    state = AuthUnlocking(user);
    try {
      await _vaultSession.unlock(password: password);
      await _saveKeyIfRequested(saveKey);
      await _touchActiveVault();
      state = AuthReady(user);
    } on InvalidMasterPasswordException {
      state = AuthNeedsUnlock(user);
      rethrow;
    }
  }

  Future<void> logout() async {
    final wasOffline = state is AuthOfflineReady;
    if (ref.read(activeVaultProvider) != null) {
      await ref.read(domainRepositoryProvider).awaitIdle();
    }
    _vaultSession.lock();
    ref.invalidate(domainCacheDatabaseProvider);
    if (wasOffline) {
      state = const AuthOfflineNeedsUnlock();
      return;
    }
    await ref.read(authApiProvider).logout();
    state = const AuthLoggedOut();
  }

  void startOfflineSetup() {
    state = const AuthOfflineNeedsSetup();
  }

  Future<void> continueOffline() async {
    final vaults = await _vaultRegistry.list();
    if (vaults.isNotEmpty) {
      state = await _selectionFor(vaults);
      return;
    }
    startOfflineSetup();
  }

  Future<void> completeOfflineVaultSetup({
    required String password,
    required String label,
    bool saveKey = false,
  }) async {
    state = const AuthOfflineUnlocking();
    try {
      final vault = await _vaultRegistry.createOfflineVault(label: label);
      ref.read(activeVaultProvider.notifier).state = vault;
      await _vaultSession.completeOfflineVaultSetup(password: password);
      await _saveKeyIfRequested(saveKey);
      await _touchActiveVault();
      state = const AuthOfflineReady();
    } catch (e) {
      state = const AuthOfflineNeedsSetup();
      rethrow;
    }
  }

  Future<void> unlockOffline({
    required String password,
    bool saveKey = false,
  }) async {
    state = const AuthOfflineUnlocking();
    try {
      await _vaultSession.unlockOffline(password: password);
      await _saveKeyIfRequested(saveKey);
      await _touchActiveVault();
      state = const AuthOfflineReady();
    } on InvalidMasterPasswordException {
      state = const AuthOfflineNeedsUnlock();
      rethrow;
    }
  }

  Future<void> attachOfflineVaultToAccount({
    required String email,
    required String password,
  }) async {
    ref.read(apiClientProvider).tokenStore.useAccount(email);
    final loggedIn = await ref
        .read(authApiProvider)
        .login(email: email, password: password);
    final user = loggedIn.userData;
    if (user.hasVaultKeyMaterial) {
      throw const AccountAlreadyHasVaultException();
    }
    await _vaultSession.rewrapDekAfterPasswordChange(newPassword: password);
    await ref.read(domainRepositoryProvider).syncNow(force: true);
    await _vaultSession.clearLocalOfflineVault();
    final active = ref.read(activeVaultProvider);
    if (active != null) {
      final converted = await _vaultRegistry.convertOfflineVaultToOnline(
        id: active.id,
        email: email,
      );
      ref.read(activeVaultProvider.notifier).state = converted;
    }
    state = AuthReady(user);
  }

  Future<void> selectVault(VaultRegistryEntry vault) async {
    if (vault.kind == VaultKind.offline) {
      await _selectOfflineVault(vault);
      return;
    }
    final email = vault.email;
    String? error;
    if (email != null &&
        (await ref.read(apiClientProvider).tokenStore.connectedAccounts())
            .contains(email)) {
      final result = await _restoreSession(email);
      if (result.ok) return;
      error = result.error;
    }
    state = AuthLoggedOut(prefillEmail: email, error: error);
  }

  void returnToLoginScreen() {
    state = const AuthLoggedOut();
  }

  Future<void> showVaultPicker() async {
    final vaults = await _vaultRegistry.list();
    final selection = await _selectionFor(vaults);
    final hadActiveVault = ref.read(activeVaultProvider) != null;
    state = selection;
    if (hadActiveVault) {
      await ref.read(domainRepositoryProvider).awaitIdle();
      _vaultSession.lock();
      ref.invalidate(domainCacheDatabaseProvider);
      await ref.read(appDatabaseProvider).close();
      ref.read(activeVaultProvider.notifier).state = null;
    }
  }

  Future<void> lockAndShowVaultPicker() => showVaultPicker();

  Future<bool> hasKnownVaults() async {
    final vaults = _knownVaultsOverride != null
        ? await _knownVaultsOverride()
        : await _vaultRegistry.list();
    return vaults.isNotEmpty;
  }

  Future<void> backToVaultList() async {
    final current = state;
    if (current is AuthLoggingIn ||
        current is AuthResumingSession ||
        current is AuthUnlocking ||
        current is AuthOfflineUnlocking) {
      return;
    }
    if (await hasKnownVaults()) {
      await showVaultPicker();
    } else if (current is! AuthLoggedOut) {
      state = const AuthLoggedOut();
    }
  }

  Future<void> deleteVault(VaultRegistryEntry entry) async {
    final active = ref.read(activeVaultProvider);
    if (active?.id == entry.id) {
      throw const ActiveVaultCannotBeDeletedException();
    }
    await deleteVaultDatabase(entry.dbName);
    await LocalUnlockStore(vaultId: entry.id).clear();
    await _vaultRegistry.delete(entry.id);
    if (state is AuthNeedsVaultSelection) {
      await showVaultPicker();
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthFlowState>(
      (ref) => AuthController(ref),
    );

final hasKnownVaultsProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(authControllerProvider.notifier).hasKnownVaults(),
);
