import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().loginMock(_emailCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      setState(() => _error = "Не удалось войти: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Войти")),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? "").trim();
                        if (s.isEmpty) return "Укажи email";
                        final ok = RegExp(r"^[^@]+@[^@]+\.[^@]+$").hasMatch(s);
                        if (!ok) return "Похоже на неверный email";
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? "Входим..." : "Войти"),
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
