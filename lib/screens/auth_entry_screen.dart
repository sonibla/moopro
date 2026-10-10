import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../crypto/local_unlock_gate.dart';
import '../providers/auth_controller.dart';

enum _AuthMode { login, register }

const privacyPolicyUrl = 'https://moopro.sonibla.com/#privacy';

class AuthEntryScreen extends ConsumerStatefulWidget {
  const AuthEntryScreen({super.key, this.openUrl});

  final Future<void> Function(Uri url)? openUrl;

  @override
  ConsumerState<AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends ConsumerState<AuthEntryScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _totpController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _stayLoggedIn = false;
  bool _registrationEnabled = true;
  bool _requestSent = false;
  bool _registerSubmitting = false;
  bool _privacyAccepted = false;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () =>
        (widget.openUrl ?? _defaultOpenUrl)(Uri.parse(privacyPolicyUrl));
  String? _registerError;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authControllerProvider);
    if (authState is AuthLoggedOut && authState.prefillEmail != null) {
      _emailController.text = authState.prefillEmail!;
    }
    _refreshRegistrationStatus();
  }

  Future<void> _refreshRegistrationStatus() async {
    try {
      final enabled = await ref
          .read(authControllerProvider.notifier)
          .checkRegistrationStatus();
      if (mounted) setState(() => _registrationEnabled = enabled);
    } catch (_) {}
  }

  static Future<void> _defaultOpenUrl(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _privacyTap.dispose();
    _emailController.dispose();
    _loginPasswordController.dispose();
    _totpController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthFlowState>(authControllerProvider, (_, next) {
      if (next is AuthLoggedOut &&
          next.prefillEmail != null &&
          _emailController.text.isEmpty) {
        _emailController.text = next.prefillEmail!;
      }
    });
    final authState = ref.watch(authControllerProvider);
    final isLoggingIn = authState is AuthLoggingIn;
    final loginError = authState is AuthLoggedOut ? authState.error : null;
    final totpRequired = authState is AuthLoggedOut && authState.totpRequired;
    final canGoBack =
        !isLoggingIn && (ref.watch(hasKnownVaultsProvider).value ?? false);
    void goBack() =>
        ref.read(authControllerProvider.notifier).backToVaultList();
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('moopro'),
          automaticallyImplyLeading: false,
          leading: canGoBack ? BackButton(onPressed: goBack) : null,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _mode == _AuthMode.login
                      ? _buildLoginForm(
                          context,
                          isLoggingIn,
                          loginError,
                          totpRequired,
                        )
                      : _buildRegisterOrRequestForm(context),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(
                      () => _mode = _mode == _AuthMode.login
                          ? _AuthMode.register
                          : _AuthMode.login,
                    ),
                    child: Text(
                      _mode == _AuthMode.login
                          ? (_registrationEnabled
                                ? 'Create an account'
                                : 'Request access')
                          : 'Log in instead',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .continueOffline(),
                    child: const Text('Continue offline'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    bool isLoggingIn,
    String? error,
    bool totpRequired,
  ) {
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Email is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: (value) => (value == null || value.isEmpty)
                ? 'Password is required'
                : null,
          ),
          if (totpRequired) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _totpController,
              decoration: const InputDecoration(
                labelText: 'Authenticator code',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Code is required'
                  : null,
            ),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _stayLoggedIn,
            onChanged: isLoggingIn
                ? null
                : (value) => setState(() => _stayLoggedIn = value ?? false),
            title: const Text('Stay signed in on this device'),
            subtitle: Text(
              localUnlockHasRealGate
                  ? 'Keeps your session on this device, gated by your OS '
                        'biometric/PIN prompt when the app starts. Removed '
                        'when you log out.'
                  : 'Keeps your session on this device. Not protected by a '
                        'biometric or PIN prompt on this platform. Removed '
                        'when you log out.',
            ),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: isLoggingIn ? null : _submitLogin,
            child: isLoggingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Log in'),
          ),
        ],
      ),
    );
  }

  void _submitLogin() {
    if (!_loginFormKey.currentState!.validate()) return;
    final authState = ref.read(authControllerProvider);
    final totpRequired = authState is AuthLoggedOut && authState.totpRequired;
    ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _loginPasswordController.text,
          totpCode: totpRequired ? _totpController.text.trim() : null,
          stayLoggedIn: _stayLoggedIn,
        );
  }

  Widget _buildRegisterOrRequestForm(BuildContext context) {
    if (_requestSent) {
      return const Text(
        'Thanks! We\'ve got your request and will be in touch soon.',
        textAlign: TextAlign.center,
      );
    }
    return Form(
      key: _registerFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_registrationEnabled) ...[
            const Text(
              'Account creation is currently waitlist-based. Fill out the form below to request an account, and we\'ll contact you soon! In the meantime you can still use all features offline for free.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Email is required' : null,
          ),
          if (_registrationEnabled) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _registerPasswordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Password is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _registerConfirmController,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              obscureText: true,
              validator: (value) => value != _registerPasswordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
          ],
          const SizedBox(height: 8),
          FormField<bool>(
            initialValue: _privacyAccepted,
            validator: (accepted) =>
                accepted == true ? null : 'You must accept the privacy policy',
            builder: (field) {
              final theme = Theme.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _privacyAccepted,
                    onChanged: _registerSubmitting
                        ? null
                        : (value) {
                            setState(() => _privacyAccepted = value ?? false);
                            field.didChange(_privacyAccepted);
                          },
                    title: Text.rich(
                      TextSpan(
                        text: 'I accept the ',
                        children: [
                          TextSpan(
                            text: 'privacy policy',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _privacyTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        field.errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (_registerError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _registerError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: _registerSubmitting ? null : _submitRegisterOrRequest,
            child: _registerSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _registrationEnabled
                        ? 'Create account'
                        : 'Request an account',
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRegisterOrRequest() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() {
      _registerSubmitting = true;
      _registerError = null;
    });
    try {
      if (!_registrationEnabled) {
        await ref
            .read(authControllerProvider.notifier)
            .requestAccount(email: _emailController.text.trim());
        if (mounted) setState(() => _requestSent = true);
        return;
      }

      await ref
          .read(authControllerProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            password: _registerPasswordController.text,
          );
      final authState = ref.read(authControllerProvider);
      if (authState is AuthLoggedOut) {
        if (mounted) {
          setState(
            () => _registerError = authState.error ?? 'Registration failed.',
          );
        }
      }
    } on RegistrationClosedException {
      if (mounted) setState(() => _registrationEnabled = false);
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => _registerError = 'Could not send the request: ${e.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _registerSubmitting = false);
    }
  }
}
