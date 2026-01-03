import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var notePages: [NSAttributedString] = [NSAttributedString(string: "")]
    @Published var selectedPageIndex: Int = 0
    @Published var tasks: [TaskItem] = [] {
        didSet {
            saveTasks()
        }
    }
    
    private let notesKey = "QuickNotes_Notes_V2"
    private let tasksKey = "QuickNotes_Tasks"
    private let pageCountKey = "QuickNotes_PageCount"
    
    private var storageDir: URL
    private var saveWorkItem: DispatchWorkItem?
    
    private init() {
         // Determine storage directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSup.appendingPathComponent("com.antigravity.quicknotes")
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.storageDir = appDir
        } else {
            self.storageDir = docs
        }
        
        loadData()
    }
    
    // MARK: - API
    
    func saveCurrentPage(_ text: NSAttributedString) {
        if selectedPageIndex < notePages.count {
            // 1. Update Memory Immediately (for UI)
            notePages[selectedPageIndex] = text
            
            // 2. Debounce Disk Save
            saveWorkItem?.cancel()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.savePageToDisk(index: self.selectedPageIndex, content: text)
                
                // 3. Mark for Cloud Sync
                Task { @MainActor in
                    SyncManager.shared.markDirty(index: self.selectedPageIndex)
                }
            }
            
            saveWorkItem = item
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0, execute: item)
        }
    }
    
    func updateFromSync(index: Int, content: NSAttributedString) {
        // Called by SyncManager when new data arrives from server
        // We update memory and disk, but DO NOT trigger a new sync (avoid loop)
        DispatchQueue.main.async {
            if index < self.notePages.count {
                self.notePages[index] = content
                self.savePageToDisk(index: index, content: content)
            } else {
                // Determine padding if index > count
                // For QuickNotes, page_0, page_1... if server sends page_5, we might need to fill gaps or ignore
                // For simplicity, we only append if it's the next one, or we expand
                if index == self.notePages.count {
                    self.notePages.append(content)
                    self.savePageCount()
                    self.savePageToDisk(index: index, content: content)
                }
            }
        }
    }
    
    func addPage() {
        let newPage = NSAttributedString(string: "")
        notePages.append(newPage)
        selectedPageIndex = notePages.count - 1
        savePageCount()
        savePageToDisk(index: selectedPageIndex, content: newPage)
    }
    
    func clearCurrentPage() {
        if selectedPageIndex < notePages.count {
            let empty = NSAttributedString(string: "")
            notePages[selectedPageIndex] = empty
            savePageToDisk(index: selectedPageIndex, content: empty)
            Task { @MainActor in SyncManager.shared.markDirty(index: selectedPageIndex) }
        }
    }
    
    func deleteCurrentPage() {
        guard selectedPageIndex > 0 && selectedPageIndex < notePages.count else { return }
        let lastIndex = notePages.count - 1
        let lastFile = getPageUrl(index: lastIndex)
        try? FileManager.default.removeItem(at: lastFile)
        
        notePages.remove(at: selectedPageIndex)
        selectedPageIndex = max(0, selectedPageIndex - 1)
        
        for i in 0..<notePages.count {
             savePageToDisk(index: i, content: notePages[i])
             Task { @MainActor in SyncManager.shared.markDirty(index: i) }
        }
        savePageCount()
    }
    
    // MARK: - Task API
    
    func addTask(title: String) {
        let task = TaskItem(title: title, isCompleted: false)
        tasks.append(task)
    }
    
    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
    }
    
    func deleteTask(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
    
    func clearAllTasks() {
        tasks.removeAll()
    }
    
    // MARK: - Persistence
    
    private func getPageUrl(index: Int) -> URL {
        return storageDir.appendingPathComponent("page_\(index).rtfd")
    }
    
    private func savePageToDisk(index: Int, content: NSAttributedString) {
        let url = getPageUrl(index: index)
        do {
            let range = NSRange(location: 0, length: content.length)
            let data = try content.fileWrapper(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
            try data.write(to: url, options: .atomic, originalContentsURL: nil)
        } catch {
            print("Failed to save page \(index): \(error)")
        }
    }
    
    private func savePageCount() {
        UserDefaults.standard.set(notePages.count, forKey: pageCountKey)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            self.tasks = decoded
        }
        
        let count = UserDefaults.standard.integer(forKey: pageCountKey)
        if count > 0 {
            var loadedPages: [NSAttributedString] = []
            for i in 0..<count {
                let url = getPageUrl(index: i)
                if let content = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
                    loadedPages.append(content)
                } else {
                    loadedPages.append(NSAttributedString(string: ""))
                }
            }
            self.notePages = loadedPages
        } else {
            if let savedPages = UserDefaults.standard.array(forKey: notesKey) as? [String], !savedPages.isEmpty {
                 self.notePages = savedPages.map { NSAttributedString(string: $0) }
                 for (i, page) in self.notePages.enumerated() {
                     savePageToDisk(index: i, content: page)
                 }
                 savePageCount()
            } else {
                self.notePages = [NSAttributedString(string: "")]
            }
        }
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }
}
