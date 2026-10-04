class User {
  final String id;
  final String email;
  final String name;
  User({required this.id, required this.email, required this.name});
  factory User.fromJson(Map<String, dynamic> json) =>
      User(id: json['id'], email: json['email'], name: json['name']);
}

class Project {
  final String id;
  final String name;
  final String color;
  final bool isInbox;
  final int openCount;
  Project({
    required this.id,
    required this.name,
    required this.color,
    required this.isInbox,
    required this.openCount,
  });
  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'],
        name: json['name'],
        color: json['color'] ?? '#db4c3f',
        isInbox: json['is_inbox'] == true,
        openCount: json['open_count'] ?? 0,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'is_inbox': isInbox,
        'open_count': openCount,
      };
}

class TaskItem {
  final String id;
  final String projectId;
  final String content;
  final String description;
  final int priority;
  final String? dueDate;
  final String? dueTime;
  final String? reminderAt;
  final bool isCompleted;

  TaskItem({
    required this.id,
    required this.projectId,
    required this.content,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.dueTime,
    required this.reminderAt,
    required this.isCompleted,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'],
        projectId: json['project_id'] ?? '',
        content: json['content'] ?? '',
        description: json['description'] ?? '',
        priority: json['priority'] ?? 1,
        dueDate: json['due_date'],
        dueTime: json['due_time'],
        reminderAt: json['reminder_at'],
        isCompleted: json['is_completed'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'content': content,
        'description': description,
        'priority': priority,
        'due_date': dueDate,
        'due_time': dueTime,
        'reminder_at': reminderAt,
        'is_completed': isCompleted,
      };

  String get priorityLabel => {4: 'P1', 3: 'P2', 2: 'P3', 1: 'P4'}[priority] ?? 'P4';

  String get dueLabel {
    if (dueDate == null) return '';
    return dueTime == null || dueTime!.isEmpty ? dueDate! : '$dueDate $dueTime';
  }
}
