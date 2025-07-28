import 'package:flutter/material.dart';

class ZenModeScreen extends StatefulWidget {
  const ZenModeScreen({super.key});

  @override
  State<ZenModeScreen> createState() => _ZenModeScreenState();
}

class _ZenModeScreenState extends State<ZenModeScreen> {
  final Map<String, bool> _blockedApps = {
    'Facebook': false,
    'Instagram': false,
    'TikTok': false,
    'Twitter': false,
    'YouTube': false,
    'Snapchat': false,
    'Reddit': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zen Mode'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Block distracting apps to help you stay focused. (This is a demo UI; actual app blocking is not implemented.)',
              style: TextStyle(fontSize: 16),
            ),
          ),
          ..._blockedApps.keys.map((app) => SwitchListTile(
                title: Text(app),
                value: _blockedApps[app]!,
                onChanged: (val) {
                  setState(() {
                    _blockedApps[app] = val;
                  });
                },
                secondary: Icon(Icons.block),
              )),
        ],
      ),
    );
  }
} 