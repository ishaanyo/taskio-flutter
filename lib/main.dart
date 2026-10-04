import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'models.dart';
import 'reminders.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Reminders.init();
  runApp(const TaskioApp());
}

class TaskioApp extends StatelessWidget {
  const TaskioApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Taskio', debugShowCheckedModeBanner: false, theme: taskioTheme(), home: const AuthGate());
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final api = TaskioApi('https://taskio-chillover-s-projects.vercel.app');
  bool loading = true;
  @override
  void initState() {
    super.initState();
    api.loadToken().then((_) => setState(() => loading = false));
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (api.token == null) return LoginScreen(api: api, onReady: () => setState(() {}));
    return HomeScreen(api: api, onLogout: () => setState(() {}));
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onReady});
  final TaskioApi api;
  final VoidCallback onReady;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final baseUrl = TextEditingController(text: 'https://taskio-chillover-s-projects.vercel.app');
  bool register = false;
  String? error;
  bool busy = false;
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      widget.api.baseUrl = baseUrl.text.trim().replaceAll(RegExp(r'/$'), '');
      if (register) {
        await widget.api.register(name.text.trim(), email.text.trim(), password.text);
      } else {
        await widget.api.login(email.text.trim(), password.text);
      }
      widget.onReady();
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      const Row(children: [CircleAvatar(backgroundColor: taskioRed, child: Icon(Icons.check, color: Colors.white)), SizedBox(width: 10), Text('Taskio', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 8),
      const Text('Projects, due date & time, priorities.'),
      const SizedBox(height: 16),
      TextField(controller: baseUrl, decoration: const InputDecoration(labelText: 'API base URL', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      if (register) ...[TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())), const SizedBox(height: 10)],
      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: taskioRed))),
      const SizedBox(height: 12),
      FilledButton(onPressed: busy ? null : submit, child: Text(register ? 'Sign up' : 'Log in')),
      TextButton(onPressed: () => setState(() => register = !register), child: Text(register ? 'Have an account? Log in' : 'Create account')),
    ]))));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onLogout});
  final TaskioApi api;
  final VoidCallback onLogout;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> projects = [];
  List<TaskItem> tasks = [];
  String view = 'inbox';
  String? projectId;
  String title = 'Inbox';
  bool loading = true;
  bool showCompleted = false;
  String? error;
  String get path => widget.api.taskPath(view: projectId == null ? view : null, projectId: projectId, includeCompleted: showCompleted);

  @override
  void initState() {
    super.initState();
    load(fromCache: true);
  }

  Future<void> load({bool fromCache = false}) async {
    if (fromCache) {
      final cachedProjects = await widget.api.cachedProjects();
      final cachedTasks = await widget.api.cachedTasks(path);
      if (cachedProjects != null || cachedTasks != null) {
        setState(() { projects = cachedProjects ?? projects; tasks = cachedTasks ?? tasks; loading = cachedTasks == null; });
      }
    }
    try {
      final nextProjects = await widget.api.projects();
      final nextTasks = await widget.api.tasks(view: projectId == null ? view : null, projectId: projectId, includeCompleted: showCompleted);
      if (!mounted) return;
      setState(() { projects = nextProjects; tasks = nextTasks; loading = false; error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = tasks.isEmpty ? e.toString().replaceFirst('Exception: ', '') : null; loading = false; });
    }
  }

  void openView(String nextView, String nextTitle, {String? id}) {
    setState(() { view = nextView; title = nextTitle; projectId = id; });
    Navigator.pop(context);
    load(fromCache: true);
  }

  Future<void> syncReminder(TaskItem task) async {
    if (task.reminderAt == null || task.isCompleted) {
      await Reminders.cancel(task.id);
      return;
    }
    await Reminders.schedule(task.id, task.content, DateTime.parse(task.reminderAt!).toLocal());
  }

  Future<void> removeTask(TaskItem task) async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete task?'),
      content: Text(task.content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    await widget.api.deleteTask(task.id);
    await Reminders.cancel(task.id);
    load();
  }

  Future<void> editTask({TaskItem? existing}) async {
    final content = TextEditingController(text: existing?.content ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    DateTime? due = existing?.dueDate == null ? null : DateTime.tryParse(existing!.dueDate!);
    TimeOfDay? time;
    if (existing?.dueTime != null && existing!.dueTime!.contains(':')) {
      final parts = existing.dueTime!.split(':');
      time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    DateTime? reminder = existing?.reminderAt == null ? null : DateTime.tryParse(existing!.reminderAt!)?.toLocal();
    var priority = existing?.priority ?? 1;
    var selectedProject = existing?.projectId ?? projectId;
    final action = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: StatefulBuilder(builder: (context, setModal) {
          return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(existing == null ? 'New task' : 'Edit task', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            TextField(controller: content, decoration: const InputDecoration(labelText: 'Task name')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
            Row(children: [4, 3, 2, 1].map((p) => IconButton(
              onPressed: () => setModal(() => priority = p),
              icon: Icon(Icons.flag, color: priority == p ? priorityColor(p) : Colors.grey.shade400),
            )).toList()),
            Wrap(spacing: 8, children: [
              TextButton(onPressed: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: due ?? DateTime.now());
                if (picked != null) setModal(() => due = picked);
              }, child: Text(due == null ? 'Due date' : '${due!.year}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}')),
              TextButton(onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
                if (picked != null) setModal(() => time = picked);
              }, child: Text(time == null ? 'Time' : time!.format(context))),
              TextButton(onPressed: () async {
                final date = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2100), initialDate: reminder ?? DateTime.now());
                if (date == null || !context.mounted) return;
                final clock = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(reminder ?? DateTime.now()));
                if (clock == null) return;
                setModal(() => reminder = DateTime(date.year, date.month, date.day, clock.hour, clock.minute));
              }, child: Text(reminder == null ? 'Reminder' : '${reminder!.day}/${reminder!.month} ${reminder!.hour}:${reminder!.minute.toString().padLeft(2, '0')}')),
            ]),
            DropdownButton<String>(value: selectedProject, hint: const Text('Project'), items: projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => setModal(() => selectedProject = v)),
            Row(children: [
              FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: Text(existing == null ? 'Add task' : 'Save')),
              if (existing != null) TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Delete')),
            ]),
            const SizedBox(height: 12),
          ]));
        }),
      );
    });
    if (action == 'delete' && existing != null) {
      await removeTask(existing);
      return;
    }
    if (action != 'save' || content.text.trim().isEmpty) return;
    final dueDate = due == null ? null : '${due!.year.toString().padLeft(4, '0')}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}';
    final dueTime = time == null ? null : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
    final reminderAt = reminder?.toUtc().toIso8601String();
    final TaskItem saved;
    if (existing == null) {
      saved = await widget.api.createTask(content: content.text.trim(), description: description.text.trim(), projectId: selectedProject, priority: priority, dueDate: dueDate, dueTime: dueTime, reminderAt: reminderAt);
    } else {
      saved = await widget.api.updateTask(existing.id, {'content': content.text.trim(), 'description': description.text.trim(), 'priority': priority, 'project_id': selectedProject, 'due_date': dueDate, 'due_time': dueTime, 'reminder_at': reminderAt});
    }
    await syncReminder(saved);
    load();
  }

  List<Widget> taskTiles(List<TaskItem> items) {
    return items.map((task) => ListTile(
      onTap: () => editTask(existing: task),
      leading: IconButton(
        icon: Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined, color: priorityColor(task.priority)),
        onPressed: () async {
          final saved = await widget.api.updateTask(task.id, {'is_completed': !task.isCompleted});
          await syncReminder(saved);
          load();
        },
      ),
      title: Text(task.content, style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
      subtitle: Text([task.dueLabel, if (task.reminderAt != null) 'Reminder set', task.description].where((s) => s.isNotEmpty).join(' \u00b7 ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flag, color: priorityColor(task.priority)),
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => removeTask(task)),
      ]),
    )).toList();
  }

  Widget body() {
    if (loading && tasks.isEmpty) return const Center(child: CircularProgressIndicator());
    if (error != null && tasks.isEmpty) return Center(child: Text(error!));
    final open = tasks.where((t) => !t.isCompleted).toList();
    final done = tasks.where((t) => t.isCompleted).toList();
    if (view == 'calendar') {
      final grouped = <String, List<TaskItem>>{};
      for (final task in tasks) {
        grouped.putIfAbsent(task.dueDate ?? 'No date', () => []).add(task);
      }
      final keys = grouped.keys.toList()..sort();
      return ListView(children: [
        for (final day in keys) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(day, style: const TextStyle(fontWeight: FontWeight.w700))),
          ...taskTiles(grouped[day]!),
        ],
        if (tasks.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No dated tasks.'))),
      ]);
    }
    return ListView(children: [
      SwitchListTile(title: const Text('Show completed'), value: showCompleted, onChanged: (v) { setState(() => showCompleted = v); load(fromCache: true); }),
      ...taskTiles(open),
      if (showCompleted && done.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Completed', style: TextStyle(fontWeight: FontWeight.w700))),
      if (showCompleted) ...taskTiles(done),
      if (open.isEmpty && done.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No tasks. Tap a task to edit.'))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: Drawer(backgroundColor: sidebar, child: ListView(children: [
        const DrawerHeader(child: Row(children: [CircleAvatar(backgroundColor: taskioRed, child: Icon(Icons.check, color: Colors.white)), SizedBox(width: 10), Text('Taskio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))])),
        ListTile(leading: const Icon(Icons.inbox), title: const Text('Inbox'), subtitle: const Text('All tasks'), selected: view == 'inbox', onTap: () => openView('inbox', 'Inbox')),
        ListTile(leading: const Icon(Icons.today), title: const Text('Today'), selected: view == 'today', onTap: () => openView('today', 'Today')),
        ListTile(leading: const Icon(Icons.upcoming), title: const Text('Upcoming'), selected: view == 'upcoming', onTap: () => openView('upcoming', 'Upcoming')),
        ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Calendar'), selected: view == 'calendar', onTap: () => openView('calendar', 'Calendar')),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('PROJECTS', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ...projects.where((p) => !p.isInbox).map((p) => ListTile(leading: CircleAvatar(radius: 6, backgroundColor: parseHex(p.color)), title: Text(p.name), trailing: Text('${p.openCount}'), selected: projectId == p.id, onTap: () => openView('project', p.name, id: p.id))),
        ListTile(leading: const Icon(Icons.add), title: const Text('Add project'), onTap: () async {
          final name = TextEditingController();
          final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('New project'), content: TextField(controller: name), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))]));
          if (ok == true && name.text.trim().isNotEmpty) { await widget.api.createProject(name.text.trim(), '#246fe0'); load(); }
        }),
        ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () async { await widget.api.logout(); widget.onLogout(); }),
      ])),
      floatingActionButton: FloatingActionButton(onPressed: () => editTask(), backgroundColor: taskioRed, child: const Icon(Icons.add, color: Colors.white)),
      body: body(),
    );
  }
}
