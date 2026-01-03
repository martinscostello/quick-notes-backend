import 'package:flutter/material.dart';
import '../database/local_database.dart';
import '../models.dart';

import '../widgets/glass_container.dart';

class TasksPageUI extends StatefulWidget {
  const TasksPageUI({super.key});

  @override
  State<TasksPageUI> createState() => _TasksPageUIState();
}

class _TasksPageUIState extends State<TasksPageUI> {
  final TextEditingController _taskController = TextEditingController();
  List<TaskItem> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await LocalDatabase.instance.getAllTasks();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addTask() async {
      final text = _taskController.text.trim();
      if (text.isEmpty) return;
      
      final newId = DateTime.now().millisecondsSinceEpoch.toString(); 
      await LocalDatabase.instance.addTask(newId, text);
      _taskController.clear();
      await _loadTasks();
  }
  
  Future<void> _toggleTask(TaskItem task) async {
      await LocalDatabase.instance.toggleTask(task.id, !task.isCompleted);
      await _loadTasks();
  }
  
  Future<void> _deleteTask(String id) async {
      await LocalDatabase.instance.deleteTask(id);
      await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine colors
    final inputBg = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E5EA);
    final hintColor = isDark ? Colors.white54 : Colors.grey;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
         // INPUT FIELD
         Padding(
           padding: const EdgeInsets.all(16),
           child: Row(
             children: [
               Expanded(
                 child: Container(
                   height: 40,
                   decoration: BoxDecoration(
                     color: inputBg, 
                     borderRadius: BorderRadius.circular(10),
                   ),
                   alignment: Alignment.centerLeft,
                   child: TextField(
                       controller: _taskController,
                       onSubmitted: (_) => _addTask(),
                       decoration: InputDecoration(
                           hintText: "New Task",
                           hintStyle: TextStyle(color: hintColor, fontSize: 16),
                           border: InputBorder.none,
                           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8) 
                       ),
                       style: TextStyle(color: textColor, fontSize: 16),
                   ),
                 ),
               ),
               const SizedBox(width: 12),
               GestureDetector(
                   onTap: _addTask,
                   child: const Icon(Icons.add_circle, color: Colors.blue, size: 32)
               ),
             ],
           ),
         ),
         
         // LIST
         Expanded(
           child: ListView.separated(
             itemCount: _tasks.length,
             separatorBuilder: (c, i) => Divider(height: 1, indent: 56, color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3)),
             itemBuilder: (context, index) {
               final task = _tasks[index];
               
               // "text in dark mode should be white both canceled and not"
               final itemTextColor = isDark ? Colors.white : (task.isCompleted ? Colors.grey : Colors.black);

               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                 child: Row(
                   children: [
                     // CUSTOM SQUARE CHECKBOX
                     GestureDetector(
                       onTap: () => _toggleTask(task),
                       child: SizedBox(
                         width: 28, 
                         height: 28,
                         child: Stack(
                           clipBehavior: Clip.none, 
                           alignment: Alignment.center,
                           children: [
                             // The Box
                             Container(
                               width: 22, 
                               height: 22,
                               decoration: BoxDecoration(
                                 color: Colors.transparent,
                                 border: Border.all(
                                   color: task.isCompleted ? Colors.green : (isDark ? Colors.white70 : Colors.grey),
                                   width: 2
                                 ),
                                 borderRadius: BorderRadius.circular(4), 
                               ),
                             ),
                             
                             // The Tick
                             if (task.isCompleted)
                               Positioned(
                                 top: -4, 
                                 right: -4,
                                 child: const Icon(
                                   Icons.check, 
                                   color: Colors.green, 
                                   size: 28, 
                                   weight: 800, 
                                 ),
                               ),
                           ],
                         ),
                       ),
                     ),
                     
                     const SizedBox(width: 12),
                     
                     // TITLE
                     Expanded(
                       child: Text(
                         task.title,
                         style: TextStyle(
                           fontSize: 16,
                           decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                           decorationColor: itemTextColor,
                           color: itemTextColor,
                         ),
                       ),
                     ),
                     
                     // DELETE BUTTON (Glass Card)
                     const SizedBox(width: 8),
                     GestureDetector(
                        onTap: () => _deleteTask(task.id),
                        child: GlassContainer(
                            width: 36,
                            height: 36,
                            borderRadius: 10,
                            padding: EdgeInsets.zero,
                            opacity: isDark ? 0.2 : 0.6,
                            blur: 10,
                            shadows: isDark ? null : [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                            ],
                            child: const Center(
                                child: Icon(Icons.delete_outline, color: Colors.red, size: 20)
                            ),
                        ),
                     ),
                   ],
                 ),
               );
             },
           ),
         )
      ],
    );
  }
}
