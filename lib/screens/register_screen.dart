import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart'; 
import 'legal_doc_screen.dart'; // [NEW]

class RegisterScreen extends StatefulWidget {
  static const route = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// ... imports


class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(); 

  Gender _gender = Gender.male;
  UserRole _role = UserRole.buyer;
  
  bool _acceptedTerms = false; // [NEW]
  bool _showTermsError = false; // [NEW]

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose(); 
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _showTermsError = false;
    });

    if (!_acceptedTerms) {
      setState(() => _showTermsError = true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        gender: _gender,
        role: _role,
      );

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
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl, // [NEW]
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: "Пароль", // TODO: localize
                        hintText: "Минимум 6 символов",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? "").trim();
                        if (s.isEmpty) return context.tr('auth_error_required');
                        if (s.length < 6) return "Пароль слишком короткий";
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

                    // Terms & Privacy Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (v) => setState(() => _acceptedTerms = v == true),
                        ),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('${context.tr('auth_agree_to')} ', style: const TextStyle(fontSize: 12)),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalDocScreen(title: 'Terms of Service', content: LegalDocScreen.termsOfService))),
                                child: Text(context.tr('auth_terms'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ),
                              const Text(' & ', style: TextStyle(fontSize: 12)),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalDocScreen(title: 'Privacy Policy', content: LegalDocScreen.privacyPolicy))),
                                child: Text(context.tr('auth_privacy'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    if (_showTermsError)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 12),
                        child: Text(
                          context.tr('auth_error_terms'),
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 12),

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
