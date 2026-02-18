import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class RegisterScreen extends StatefulWidget {
  static const route = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  Gender _gender = Gender.male;
  UserRole _role = UserRole.buyer;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = AppUser(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        gender: _gender,
        role: _role,
      );

      await context.read<AuthProvider>().register(user);

      if (!mounted) return;
      
      // После регистрации идем на StartGate (/), который сам направит на нужный экран (Vogue Home и т.д.)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      setState(() => _error = "Не удалось зарегистрироваться: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auth_register_title'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.tr('auth_name_label'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? "").trim();
                        if (s.isEmpty) return context.tr('auth_error_required');
                        if (s.length < 2) return context.tr('auth_error_short');
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: context.tr('auth_email_label'),
                        hintText: context.tr('auth_email_hint'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? "").trim();
                        if (s.isEmpty) return context.tr('auth_error_required');
                        final ok = RegExp(r"^[^@]+@[^@]+\.[^@]+$").hasMatch(s);
                        if (!ok) return context.tr('auth_error_email');
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    Text(context.tr('auth_gender_label'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<Gender>(
                      segments: [
                        ButtonSegment(value: Gender.male, label: Text(context.tr('auth_gender_male'))),
                        ButtonSegment(value: Gender.female, label: Text(context.tr('auth_gender_female'))),
                      ],
                      selected: {_gender},
                      onSelectionChanged: (s) => setState(() => _gender = s.first),
                    ),

                    const SizedBox(height: 20),

                    Text(context.tr('auth_role_label'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<UserRole>(
                      segments: [
                        ButtonSegment(value: UserRole.buyer, label: Text(context.tr('auth_role_buyer'))),
                        ButtonSegment(value: UserRole.seller, label: Text(context.tr('auth_role_seller'))),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),

                    const SizedBox(height: 20),

                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],

                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? context.tr('auth_register_loading') : context.tr('auth_register_action')),
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
