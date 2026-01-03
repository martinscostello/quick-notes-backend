import SwiftUI

struct TaskItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool
}

struct TasksView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var newTaskTitle: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("New Task", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTask()
                    }
                
                Button(action: addTask) {
                    Image(systemName: "plus")
                }
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            
            List {
                ForEach($dataManager.tasks) { $task in
                    HStack {
                        Toggle(isOn: $task.isCompleted) {
                            Text(task.title)
                                .strikethrough(task.isCompleted)
                                .foregroundColor(task.isCompleted ? .secondary : .primary)
                        }
                        .toggleStyle(.checkbox)
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                dataManager.deleteTask(id: task.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            
            Divider()
            
            HStack {
                Button("Clear Tasks") {
                    dataManager.clearAllTasks()
                }
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(10)
            // Background removed for cleaner look
        }
    }
    
    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        withAnimation {
            dataManager.addTask(title: trimmed)
            newTaskTitle = ""
        }
    }
}
