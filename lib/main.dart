import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'theme.dart';

void main() {
  runApp(const TaskioApp());
}

class TaskioApp extends StatelessWidget {
  const TaskioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskio',
      debugShowCheckedModeBanner: false,
      theme: taskioTheme(),
      home: const AuthGate(),
    );
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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Row(children: [
                CircleAvatar(backgroundColor: taskioRed, child: Icon(Icons.check, color: Colors.white)),
                SizedBox(width: 10),
                Text('Taskio', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              const Text('Projects, due date & time, priorities.'),
              const SizedBox(height: 16),
              TextField(controller: baseUrl, decoration: const InputDecoration(labelText: 'API base URL', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              if (register) ...[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
              ],
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: taskioRed))),
              const SizedBox(height: 12),
              FilledButton(onPressed: busy ? null : submit, child: Text(register ? 'Sign up' : 'Log in')),
              TextButton(onPressed: () => setState(() => register = !register), child: Text(register ? 'Have an account? Log in' : 'Create account')),
            ],
          ),
        ),
      ),
    );
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
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final nextProjects = await widget.api.projects();
      final nextTasks = await widget.api.tasks(view: projectId == null ? view : null, projectId: projectId);
      setState(() { projects = nextProjects; tasks = nextTasks; });
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openView(String nextView, String nextTitle, {String? id}) {
    setState(() { view = nextView; title = nextTitle; projectId = id; });
    Navigator.pop(context);
    load();
  }

  Future<void> addTask() async {
    final content = TextEditingController();
    final description = TextEditingController();
    DateTime? due;
    TimeOfDay? time;
    int priority = 1;
    String? inbox;
    for (final project in projects) {
      if (project.isInbox) inbox = project.id;
    }
    final selectedProject = projectId ?? inbox;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: StatefulBuilder(builder: (context, setModal) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: content, decoration: const InputDecoration(labelText: 'Task name')),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              Row(children: [
                DropdownButton<int>(
                  value: priority,
                  items: const [
                    DropdownMenuItem(value: 4, child: Text('P1')),
                    DropdownMenuItem(value: 3, child: Text('P2')),
                    DropdownMenuItem(value: 2, child: Text('P3')),
                    DropdownMenuItem(value: 1, child: Text('P4')),
                  ],
                  onChanged: (v) => setModal(() => priority = v ?? 1),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: DateTime.now());
                    if (picked != null) setModal(() => due = picked);
                  },
                  child: Text(due == null ? 'Due date' : '${due!.year}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}'),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (picked != null) setModal(() => time = picked);
                  },
                  child: Text(time == null ? 'Time' : time!.format(context)),
                ),
              ]),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add task')),
              const SizedBox(height: 16),
            ]);
          }),
        );
      },
    );
    if (ok != true || content.text.trim().isEmpty) return;
    String? dueDate;
    String? dueTime;
    if (due != null) {
      dueDate = '${due!.year.toString().padLeft(4, '0')}-${due!.month.toString().padLeft(2, '0')}-${due!.day.toString().padLeft(2, '0')}';
    }
    if (time != null) {
      dueTime = '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
    }
    await widget.api.createTask(content: content.text.trim(), description: description.text.trim(), projectId: selectedProject, priority: priority, dueDate: dueDate, dueTime: dueTime);
    load();
  }

  Future<void> addProject() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New project'),
        content: TextField(controller: name, decoration: const InputDecoration(hintText: 'Project name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await widget.api.createProject(name.text.trim(), '#246fe0');
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: Drawer(
        backgroundColor: sidebar,
        child: ListView(children: [
          const DrawerHeader(child: Row(children: [
            CircleAvatar(backgroundColor: taskioRed, child: Icon(Icons.check, color: Colors.white)),
            SizedBox(width: 10),
            Text('Taskio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ])),
          ListTile(title: const Text('Inbox'), selected: view == 'inbox', onTap: () => openView('inbox', 'Inbox')),
          ListTile(title: const Text('Today'), selected: view == 'today', onTap: () => openView('today', 'Today')),
          ListTile(title: const Text('Upcoming'), selected: view == 'upcoming', onTap: () => openView('upcoming', 'Upcoming')),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('PROJECTS', style: TextStyle(fontSize: 12, color: Colors.grey))),
          ...projects.where((p) => !p.isInbox).map((p) => ListTile(
            leading: CircleAvatar(radius: 6, backgroundColor: parseHex(p.color)),
            title: Text(p.name),
            trailing: Text('${p.openCount}'),
            selected: projectId == p.id,
            onTap: () => openView('project', p.name, id: p.id),
          )),
          ListTile(leading: const Icon(Icons.add), title: const Text('Add project'), onTap: addProject),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () async { await widget.api.logout(); widget.onLogout(); }),
        ]),
      ),
      floatingActionButton: FloatingActionButton(onPressed: addTask, backgroundColor: taskioRed, child: const Icon(Icons.add, color: Colors.white)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : tasks.isEmpty
                  ? const Center(child: Text('No tasks. Add one.'))
                  : ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          leading: IconButton(
                            icon: Icon(task.isCompleted ? Icons.check_circle : Icons.circle_outlined, color: priorityColor(task.priority)),
                            onPressed: () async { await widget.api.updateTask(task.id, {'is_completed': !task.isCompleted}); load(); },
                          ),
                          title: Text(task.content, style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
                          subtitle: Text([task.priorityLabel, task.dueLabel, task.description].where((s) => s.isNotEmpty).join(' · ')),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await widget.api.deleteTask(task.id); load(); }),
                        );
                      },
                    ),
    );
  }
}
