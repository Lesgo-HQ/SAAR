import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _endpointController = TextEditingController();
  final _apiKeyController = TextEditingController();

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('Accessibility Service'),
            subtitle: Text(controller.isAccessibilityEnabled ? 'Enabled' : 'Disabled'),
            trailing: Icon(
              Icons.circle,
              color: controller.isAccessibilityEnabled ? Colors.green : Colors.red,
            ),
          ),
          ElevatedButton(
            onPressed: () => controller.openAccessibilitySettings(),
            child: const Text('Open Accessibility Settings'),
          ),
          const Divider(height: 32),
          Text('LLM Configuration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _endpointController,
            decoration: const InputDecoration(
              labelText: 'Endpoint',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              controller.updateLlmConfig(
                endpoint: _endpointController.text.isNotEmpty ? _endpointController.text : null,
                apiKey: _apiKeyController.text.isNotEmpty ? _apiKeyController.text : null,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration updated')),
              );
            },
            child: const Text('Save Configuration'),
          ),
          const Divider(height: 32),
          const Center(
            child: Text('SAAR Version 1.0.0 (Hackathon Edition)', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
