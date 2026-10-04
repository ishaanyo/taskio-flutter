import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class TaskioApi {
  TaskioApi(this.baseUrl);
  String baseUrl;
  String? token;

  static const _tokenKey = 'taskio_token';
  static const _urlKey = 'taskio_base_url';

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    baseUrl = prefs.getString(_urlKey) ?? baseUrl;
  }

  Future<void> _saveToken(String value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value);
    await prefs.setString(_urlKey, baseUrl);
  }

  Future<void> logout() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  String _cacheKey(String path) => 'cache:${baseUrl}:${token ?? ''}:$path';

  Future<List<TaskItem>?> cachedTasks(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(path));
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => TaskItem.fromJson(e)).toList();
  }

  Future<List<Project>?> cachedProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey('/api/projects'));
    if (raw == null) return null;
    return (jsonDecode(raw) as List).map((e) => Project.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    late http.Response res;
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'POST':
        res = await http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        res = await http.delete(uri, headers: headers);
      default:
        res = await http.get(uri, headers: headers);
    }
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Request failed (${res.statusCode})');
    }
    return data;
  }

  Future<User> register(String name, String email, String password) async {
    final data = await _send('POST', '/api/auth/register', body: {'name': name, 'email': email, 'password': password});
    await _saveToken(data['token']);
    return User.fromJson(data['user']);
  }

  Future<User> login(String email, String password) async {
    final data = await _send('POST', '/api/auth/login', body: {'email': email, 'password': password});
    await _saveToken(data['token']);
    return User.fromJson(data['user']);
  }

  Future<List<Project>> projects() async {
    final data = await _send('GET', '/api/projects');
    final list = (data['projects'] as List).map((e) => Project.fromJson(e)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey('/api/projects'), jsonEncode(list.map((e) => e.toJson()).toList()));
    return list;
  }

  Future<Project> createProject(String name, String color) async {
    final data = await _send('POST', '/api/projects', body: {'name': name, 'color': color});
    return Project.fromJson(data['project']);
  }

  Future<void> deleteProject(String id) async {
    await _send('DELETE', '/api/projects/$id');
  }

  String taskPath({String? view, String? projectId, bool includeCompleted = false}) {
    final query = projectId != null ? '?project_id=$projectId' : '?view=${view ?? 'inbox'}';
    return '/api/tasks$query${includeCompleted ? '&completed=1' : ''}';
  }

  Future<List<TaskItem>> tasks({String? view, String? projectId, bool includeCompleted = false}) async {
    final path = taskPath(view: view, projectId: projectId, includeCompleted: includeCompleted);
    final data = await _send('GET', path);
    final list = (data['tasks'] as List).map((e) => TaskItem.fromJson(e)).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(path), jsonEncode(list.map((e) => e.toJson()).toList()));
    return list;
  }

  Future<TaskItem> createTask({
    required String content,
    String? projectId,
    int priority = 1,
    String? dueDate,
    String? dueTime,
    String? reminderAt,
    String description = '',
  }) async {
    final data = await _send('POST', '/api/tasks', body: {
      'content': content,
      'project_id': projectId,
      'priority': priority,
      'due_date': dueDate,
      'due_time': dueTime,
      'reminder_at': reminderAt,
      'description': description,
    });
    return TaskItem.fromJson(data['task']);
  }

  Future<TaskItem> updateTask(String id, Map<String, dynamic> body) async {
    final data = await _send('PATCH', '/api/tasks/$id', body: body);
    return TaskItem.fromJson(data['task']);
  }

  Future<void> deleteTask(String id) async {
    await _send('DELETE', '/api/tasks/$id');
  }
}
