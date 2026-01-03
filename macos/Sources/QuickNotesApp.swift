import SwiftUI

@main
struct QuickNotesApp: App {
    @StateObject private var dataManager = DataManager.shared
    
    var body: some Scene {
        MenuBarExtra("QuickNotes", systemImage: "note.text") {
            ContentView()
                .environmentObject(dataManager)
                .frame(width: 300, height: 400)
        }
        .menuBarExtraStyle(.window) // Allows rich content interaction
    }
}
