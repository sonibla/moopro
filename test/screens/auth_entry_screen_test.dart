import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/db/vault_registry_database.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/screens/auth_entry_screen.dart';
import 'package:moopro/vault/vault_registry.dart';

const _newUser = UserApiResponse(
  id: 'user-9',
  email: 'new@example.com',
  emailValidated: false,
  hasVaultKeyMaterial: false,
);

DioException _errorWithCode(String path, String code) => DioException(
  requestOptions: RequestOptions(path: path),
  response: Response(
    requestOptions: RequestOptions(path: path),
    statusCode: 400,
    data: {
      'detail': {'code': code},
    },
  ),
);

class _FakeAuthApi extends AuthApi {
  bool registrationStatusEnabled = true;
  bool registrationStatusThrows = false;
  String? rejectRegisterWithCode;
  bool requestAccountCalled = false;
  String? requestedEmail;
  bool loginCalled = false;

  String? requiredTotpCode;
  final List<String?> loginTotpCodes = [];

  _FakeAuthApi() : super(ApiClient());

  @override
  Future<RegistrationStatusResponse> checkRegistrationStatus() async {
    if (registrationStatusThrows) {
      throw DioException(
        requestOptions: RequestOptions(path: '/registration-status'),
      );
    }
    return RegistrationStatusResponse(enabled: registrationStatusEnabled);
  }

  @override
  Future<LoggedInApiResponse> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    loginCalled = true;
    loginTotpCodes.add(totpCode);
    if (requiredTotpCode != null) {
      if (totpCode == null) throw _errorWithCode('/login', 'TOTP_REQUIRED');
      if (totpCode != requiredTotpCode) {
        throw DioException(
          requestOptions: RequestOptions(path: '/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/login'),
            statusCode: 401,
          ),
        );
      }
    }
    return LoggedInApiResponse(
      userData: _newUser,
      accessToken: const AccessTokenResponse(
        accessToken: 'fake-access',
        expiresIn: 3600,
        refreshToken: 'fake-refresh',
      ),
    );
  }

  @override
  Future<LoggedInApiResponse> register({
    required String email,
    required String password,
  }) async {
    if (rejectRegisterWithCode != null) {
      throw _errorWithCode('/register', rejectRegisterWithCode!);
    }
    return LoggedInApiResponse(
      userData: _newUser,
      accessToken: const AccessTokenResponse(
        accessToken: 'fake-access',
        expiresIn: 3600,
        refreshToken: 'fake-refresh',
      ),
    );
  }

  @override
  Future<void> requestAccount({required String email}) async {
    requestAccountCalled = true;
    requestedEmail = email;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required _FakeAuthApi authApi,
    bool withKnownVault = false,
    Future<void> Function(Uri url)? openUrl,
  }) async {
    final registry = VaultRegistry(
      VaultRegistryDatabase(NativeDatabase.memory()),
    );
    if (withKnownVault) {
      await tester.runAsync(
        () => registry.resolveOnlineVault(email: 'a@b.c', label: 'a@b.c'),
      );
    }
    final container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(authApi),
        vaultRegistryProvider.overrideWithValue(registry),
        authControllerProvider.overrideWith((ref) => AuthController(ref)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: AuthEntryScreen(openUrl: openUrl)),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'a pre-filled email that arrives after the screen is mounted (resuming a '
    'session from the vault list goes through AuthLoggingIn first) still '
    'fills the email field',
    (tester) async {
      final container = await pump(tester, authApi: _FakeAuthApi());
      final controller = container.read(authControllerProvider.notifier);

      controller.state = const AuthLoggingIn();
      await tester.pump();
      controller.state = const AuthLoggedOut(
        prefillEmail: 'a@b.c',
        error: 'Could not resume your session: boom',
      );
      await tester.pump();

      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Email'))
            .controller!
            .text,
        'a@b.c',
      );
      expect(find.text('Could not resume your session: boom'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a login form immediately, with no server address to type',
    (tester) async {
      await pump(tester, authApi: _FakeAuthApi());

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
      expect(find.text('Server address'), findsNothing);
    },
  );

  testWidgets(
    'the secondary link reads "Create an account" once the background check '
    'finds registration open',
    (tester) async {
      await pump(
        tester,
        authApi: _FakeAuthApi()..registrationStatusEnabled = true,
      );

      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Request access'), findsNothing);
    },
  );

  testWidgets(
    'the secondary link reads "Request access" once the background check '
    'finds registration closed',
    (tester) async {
      await pump(
        tester,
        authApi: _FakeAuthApi()..registrationStatusEnabled = false,
      );

      expect(find.text('Request access'), findsOneWidget);
      expect(find.text('Create an account'), findsNothing);
    },
  );

  testWidgets(
    'defaults to "Create an account" (optimistic) when the background check fails',
    (tester) async {
      await pump(
        tester,
        authApi: _FakeAuthApi()..registrationStatusThrows = true,
      );

      expect(find.text('Create an account'), findsOneWidget);
    },
  );

  testWidgets('tapping the secondary link switches to the sign-up form', (
    tester,
  ) async {
    await pump(
      tester,
      authApi: _FakeAuthApi()..registrationStatusEnabled = true,
    );

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'First name'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Last name'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(find.text('Log in instead'), findsOneWidget);

    await tester.tap(find.text('Log in instead'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'First name'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });

  testWidgets('logging in submits through AuthController.login', (
    tester,
  ) async {
    final authApi = _FakeAuthApi();
    await pump(tester, authApi: authApi);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'hunter22',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(authApi.loginCalled, isTrue);
  });

  group('stay signed in checkbox', () {
    Future<void> logIn(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'hunter22',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
    }

    testWidgets('is off by default, so tokens stay in memory', (tester) async {
      final container = await pump(tester, authApi: _FakeAuthApi());
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );

      await logIn(tester);

      expect(container.read(apiClientProvider).tokenStore.persist, isFalse);
    });

    testWidgets('ticking it makes the login persist tokens', (tester) async {
      final container = await pump(tester, authApi: _FakeAuthApi());

      await tester.tap(find.text('Stay signed in on this device'));
      await tester.pump();
      await logIn(tester);

      expect(container.read(apiClientProvider).tokenStore.persist, isTrue);
    });
  });

  group('TOTP', () {
    Future<void> submitPassword(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'hunter22',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
    }

    testWidgets('no code field until the server asks for one', (tester) async {
      final authApi = _FakeAuthApi()..requiredTotpCode = '123456';
      await pump(tester, authApi: authApi);

      expect(
        find.widgetWithText(TextFormField, 'Authenticator code'),
        findsNothing,
      );
      await submitPassword(tester);

      expect(
        find.widgetWithText(TextFormField, 'Authenticator code'),
        findsOneWidget,
      );
      expect(authApi.loginTotpCodes, [null]);
    });

    testWidgets('resubmitting with the right code logs in', (tester) async {
      final authApi = _FakeAuthApi()..requiredTotpCode = '123456';
      final container = await pump(tester, authApi: authApi);
      await submitPassword(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Authenticator code'),
        '123456',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(authApi.loginTotpCodes, [null, '123456']);
      expect(
        container.read(authControllerProvider),
        isA<AuthNeedsVaultSetup>(),
      );
    });

    testWidgets('a wrong code shows an error and keeps the code field', (
      tester,
    ) async {
      final authApi = _FakeAuthApi()..requiredTotpCode = '123456';
      final container = await pump(tester, authApi: authApi);
      await submitPassword(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Authenticator code'),
        '000000',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email, password or code'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Authenticator code'),
        findsOneWidget,
      );
      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
    });

    testWidgets('an empty code is rejected client-side', (tester) async {
      final authApi = _FakeAuthApi()..requiredTotpCode = '123456';
      await pump(tester, authApi: authApi);
      await submitPassword(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Code is required'), findsOneWidget);
      expect(authApi.loginTotpCodes, [null]);
    });
  });

  testWidgets('signing up submits through AuthController.register', (
    tester,
  ) async {
    final authApi = _FakeAuthApi()..registrationStatusEnabled = true;
    final container = await pump(tester, authApi: authApi);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'hunter22',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'hunter22',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider), isA<AuthNeedsVaultSetup>());
  });

  testWidgets(
    'requesting access submits through AuthController.requestAccount',
    (tester) async {
      final authApi = _FakeAuthApi()..registrationStatusEnabled = false;
      await pump(tester, authApi: authApi);

      await tester.tap(find.text('Request access'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'wants-in@example.com',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Request an account'));
      await tester.pumpAndSettle();

      expect(authApi.requestAccountCalled, isTrue);
      expect(authApi.requestedEmail, 'wants-in@example.com');
      expect(find.textContaining('Thanks'), findsOneWidget);
    },
  );

  testWidgets('sign-up is blocked client-side when the passwords differ', (
    tester,
  ) async {
    final authApi = _FakeAuthApi()..registrationStatusEnabled = true;
    final container = await pump(tester, authApi: authApi);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'hunter22',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'hunter23',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(
      container.read(authControllerProvider),
      isNot(isA<AuthNeedsVaultSetup>()),
    );
  });

  testWidgets(
    'a defensive ACCOUNT_CREATION_DISABLED on submit (the upfront hint was '
    'stale) falls back to the request-access form',
    (tester) async {
      final authApi = _FakeAuthApi()
        ..registrationStatusEnabled = true
        ..rejectRegisterWithCode = 'ACCOUNT_CREATION_DISABLED';
      await pump(tester, authApi: authApi);
      expect(find.text('Create an account'), findsOneWidget);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'hunter22',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'hunter22',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('waitlist-based'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Request an account'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a non-closed rejection shows an inline error and stays on the sign-up form',
    (tester) async {
      final authApi = _FakeAuthApi()
        ..registrationStatusEnabled = true
        ..rejectRegisterWithCode = 'EMAIL_UNAVAILABLE';
      await pump(tester, authApi: authApi);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'hunter22',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'hunter22',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(
        find.text('An account with that email already exists.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    },
  );

  testWidgets('no back button when the device has no vaults (root screen)', (
    tester,
  ) async {
    await pump(tester, authApi: _FakeAuthApi());

    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('back button returns to the vault picker when vaults exist', (
    tester,
  ) async {
    final container = await pump(
      tester,
      authApi: _FakeAuthApi(),
      withKnownVault: true,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(
      container.read(authControllerProvider),
      isA<AuthNeedsVaultSelection>(),
    );
  });

  testWidgets('system back also returns to the vault picker', (tester) async {
    final container = await pump(
      tester,
      authApi: _FakeAuthApi(),
      withKnownVault: true,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      container.read(authControllerProvider),
      isA<AuthNeedsVaultSelection>(),
    );
  });
  group('privacy policy consent', () {
    Future<void> openRequestForm(
      WidgetTester tester,
      _FakeAuthApi authApi,
    ) async {
      await pump(tester, authApi: authApi);
      await tester.tap(find.text('Request access'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'wants-in@example.com',
      );
    }

    testWidgets('requesting access is blocked until the box is ticked', (
      tester,
    ) async {
      final authApi = _FakeAuthApi()..registrationStatusEnabled = false;
      await openRequestForm(tester, authApi);

      await tester.tap(find.widgetWithText(FilledButton, 'Request an account'));
      await tester.pumpAndSettle();

      expect(authApi.requestAccountCalled, isFalse);
      expect(find.text('You must accept the privacy policy'), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Request an account'));
      await tester.pumpAndSettle();

      expect(authApi.requestAccountCalled, isTrue);
      expect(find.text('You must accept the privacy policy'), findsNothing);
    });

    testWidgets('creating an account is blocked until the box is ticked', (
      tester,
    ) async {
      final authApi = _FakeAuthApi()..registrationStatusEnabled = true;
      final container = await pump(tester, authApi: authApi);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'hunter22',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'hunter22',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('You must accept the privacy policy'), findsOneWidget);
      expect(
        container.read(authControllerProvider),
        isNot(isA<AuthNeedsVaultSetup>()),
      );
    });

    testWidgets('the login form has no privacy checkbox', (tester) async {
      await pump(tester, authApi: _FakeAuthApi());

      expect(find.textContaining('privacy policy'), findsNothing);
    });

    testWidgets('tapping "privacy policy" opens the policy URL', (
      tester,
    ) async {
      final opened = <Uri>[];
      final authApi = _FakeAuthApi()..registrationStatusEnabled = false;
      await pump(tester, authApi: authApi, openUrl: (u) async => opened.add(u));
      await tester.tap(find.text('Request access'));
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(CheckboxListTile),
              matching: find.byType(RichText),
            )
            .first,
      );
      var found = false;
      richText.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'privacy policy') {
          (span.recognizer as TapGestureRecognizer).onTap!();
          found = true;
        }
        return true;
      });

      expect(found, isTrue);
      expect(opened, [Uri.parse('https://moopro.sonibla.com/#privacy')]);
    });
  });
}
