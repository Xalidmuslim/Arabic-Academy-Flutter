import 'package:flutter/material.dart';

import '../../services/media_upload_service.dart' show integrationErrorText;

mixin IntegrationActions<T extends StatefulWidget> on State<T> {
  bool working = false;
  String? actionError;

  Future<void> runAction(Future<void> Function() action) async {
    if (working) return;
    setState(() {
      working = true;
      actionError = null;
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        setState(() => actionError = integrationErrorText(exception));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget get actionStatus => Column(
    children: [
      if (working) const LinearProgressIndicator(),
      if (actionError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              actionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
    ],
  );
}

class IntegrationNotice extends StatelessWidget {
  const IntegrationNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}
