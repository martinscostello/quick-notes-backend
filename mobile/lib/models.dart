class DictationEvent {
  final String text;
  final bool isFinal;
  DictationEvent(this.text, this.isFinal);
}

class Note {
  int pageIndex; // Primary Key for local ordering
  String content;
  int version;
  bool isDeleted;
  DateTime updatedAt;
  bool isDirty;

  Note({
    required this.pageIndex,
    this.content = "",
    this.version = 1,
    this.isDeleted = false,
    DateTime? updatedAt,
    this.isDirty = true,
  }) : updatedAt = updatedAt ?? DateTime.now();

  // Helper for "page_X" ID format used in sync
  String get localId => "page_$pageIndex";

  Map<String, dynamic> toMap() {
    return {
      'pageIndex': pageIndex,
      'content': content,
      'version': version,
      'isDeleted': isDeleted ? 1 : 0,
      'updatedAt': updatedAt.toIso8601String(),
      'isDirty': isDirty ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      pageIndex: map['pageIndex'] as int,
      content: map['content'] as String,
      version: map['version'] as int,
      isDeleted: (map['isDeleted'] as int) == 1,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isDirty: (map['isDirty'] as int) == 1,
    );
  }
}

class TaskItem {
  final String id;
  String title;
  bool isCompleted;
  bool isDirty;

  TaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.isDirty = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'isDirty': isDirty ? 1 : 0,
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String,
      isCompleted: (map['isCompleted'] as int) == 1,
      isDirty: (map['isDirty'] as int) == 1,
    );
  }
}
