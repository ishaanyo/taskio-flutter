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
    final data = await _send('POST', '/api/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
    });
    await _saveToken(data['token']);
    return User.fromJson(data['user']);
  }

  Future<User> login(String email, String password) async {
    final data = await _send('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    await _saveToken(data['token']);
    return User.fromJson(data['user']);
  }

  Future<List<Project>> projects() async {
    final data = await _send('GET', '/api/projects');
    return (data['projects'] as List).map((e) => Project.fromJson(e)).toList();
  }

  Future<Project> createProject(String name, String color) async {
    final data = await _send('POST', '/api/projects', body: {'name': name, 'color': color});
    return Project.fromJson(data['project']);
  }

  Future<List<TaskItem>> tasks({String? view, String? projectId}) async {
    final query = projectId != null ? '?project_id=$projectId' : '?view=${view ?? 'inbox'}';
    final data = await _send('GET', '/api/tasks$query');
    return (data['tasks'] as List).map((e) => TaskItem.fromJson(e)).toList();
  }

  Future<TaskItem> createTask({
    required String content,
    String? projectId,
    int priority = 1,
    String? dueDate,
    String? dueTime,
    String description = '',
  }) async {
    final data = await _send('POST', '/api/tasks', body: {
      'content': content,
      'project_id': projectId,
      'priority': priority,
      'due_date': dueDate,
      'due_time': dueTime,
      'description': description,
    });
    return TaskItem.fromJson(data['task']);
  }

  Future<void> updateTask(String id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/tasks/$id', body: body);
  }

  Future<void> deleteTask(String id) async {
    await _send('DELETE', '/api/tasks/$id');
  }
}
