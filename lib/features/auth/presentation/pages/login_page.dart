import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../application/auth_validators.dart';
import '../widgets/auth_page_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.of(context).signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = AppErrorMapper.auth(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthPageShell(
      title: l10n.welcomeBack,
      subtitle: l10n.loginSubtitle,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthHeader(
              title: l10n.loginHeader,
              subtitle: l10n.loginHeaderSubtitle,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l10n.studentEmail,
                hintText: 'name@student.utem.edu.my',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _isPasswordHidden,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _isPasswordHidden
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: () =>
                      setState(() => _isPasswordHidden = !_isPasswordHidden),
                  icon: Icon(
                    _isPasswordHidden
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
              validator: AuthValidators.password,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _AuthErrorMessage(message: _errorMessage!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? l10n.loggingIn : l10n.login),
            ),
            const SizedBox(height: 14),
            AuthSwitchPrompt(
              label: l10n.newToApp,
              action: l10n.createAccount,
              route: AppRoutes.register,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthErrorMessage extends StatelessWidget {
  const _AuthErrorMessage({required this.message});

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
