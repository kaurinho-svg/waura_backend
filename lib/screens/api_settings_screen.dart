import 'package:flutter/material.dart';
import '../config/api_runtime.dart';
import '../ui/layouts/luxe_scaffold.dart';

class ApiSettingsScreen extends StatefulWidget {
  static const route = '/api-settings';
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ApiRuntime.baseUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _isValidUrl(String s) {
    final u = Uri.tryParse(s.trim());
    return u != null &&
        (u.scheme == 'http' || u.scheme == 'https') &&
        u.host.isNotEmpty;
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (!_isValidUrl(v)) {
      setState(() =>
          _error = 'Введите корректный URL, например: http://192.168.0.100:8000');
      return;
    }

    await ApiRuntime.setBaseUrl(v);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API адрес сохранён')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return LuxeScaffold(
      title: 'Настройки API',
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Адрес бэкенда (пример: http://192.168.0.100:8000)',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Base URL',
              filled: true,
              fillColor: Colors.white.withOpacity(0.35),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: gold.withOpacity(0.22)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    BorderSide(color: gold.withOpacity(0.55), width: 1.4),
              ),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              await ApiRuntime.resetToDefault();
              if (!mounted) return;
              _ctrl.text = ApiRuntime.baseUrl;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Сброшено на адрес по умолчанию')),
              );
            },
            child: const Text('Сбросить по умолчанию'),
          ),
        ],
      ),
    );
  }
}
