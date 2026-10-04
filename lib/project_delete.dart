import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';

Future<bool> confirmDeleteProject(BuildContext context, TaskioApi api, Project project) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete project?'),
      content: Text('${project.name} and its tasks will be deleted. Inbox cannot be deleted.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true) return false;
  await api.deleteProject(project.id);
  return true;
}
