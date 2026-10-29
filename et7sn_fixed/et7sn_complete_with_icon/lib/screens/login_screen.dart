import 'package:flutter/material.dart';

import '../main.dart' show LocaleController;
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.localeController,
  });

  final AuthService authService;
  final LocaleController localeController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await widget.authService.signUp(email: _emailCtrl.text, password: _passCtrl.text);
      } else {
        await widget.authService.signIn(email: _emailCtrl.text, password: _passCtrl.text);
      }
      // AuthGate reacts to the auth state change and navigates.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message(isArabic: _isArabic));
    } catch (_) {
      if (mounted) setState(() => _error = _t('حدث خطأ غير متوقع', 'Something went wrong.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = _t('أدخل بريدك الإلكتروني أولاً', 'Enter your email first.'));
      return;
    }
    try {
      await widget.authService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('تم إرسال رابط إعادة تعيين كلمة المرور', 'Password reset email sent.')),
      ));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message(isArabic: _isArabic));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('تطبيق الزيتون', 'Olive Fit')),
        actions: [
          IconButton(
            tooltip: _t('English', 'العربية'),
            icon: const Icon(Icons.translate),
            onPressed: widget.localeController.toggle,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.eco, size: 72, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      _isSignUp ? _t('إنشاء حساب', 'Create account') : _t('تسجيل الدخول', 'Welcome back'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: _t('البريد الإلكتروني', 'Email'),
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        return (s.contains('@') && s.contains('.'))
                            ? null
                            : _t('بريد إلكتروني غير صالح', 'Enter a valid email');
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: [
                        _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: _t('كلمة المرور', 'Password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').length >= 6
                          ? null
                          : _t('6 أحرف على الأقل', 'At least 6 characters'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(_isSignUp ? _t('إنشاء حساب', 'Sign up') : _t('دخول', 'Sign in')),
                    ),
                    if (!_isSignUp)
                      TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: Text(_t('نسيت كلمة المرور؟', 'Forgot password?')),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                      child: Text(_isSignUp
                          ? _t('لديك حساب؟ سجّل الدخول', 'Already have an account? Sign in')
                          : _t('ليس لديك حساب؟ أنشئ حساباً', 'No account? Sign up')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
