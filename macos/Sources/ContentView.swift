import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @ObservedObject var speechManager = SpeechManager.shared
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Mic + Mode Custom Picker + Settings
            ZStack {
                // Layer 1: Left Aligned Mic
                HStack {
                    Button(action: {
                        speechManager.toggleRecording()
                    }) {
                        Text("🎙️")
                            .font(.system(size: 16))
                            .foregroundColor(speechManager.isRecording ? .red : .primary)
                            .padding(6)
                            .background(speechManager.isRecording ? Color.black.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(speechManager.isRecording ? Color.red : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Dictation")
                    
                    Spacer()
                }
                
                // Layer 2: Centered Picker
                Picker("", selection: $selectedTab) {
                    Text("Notes").tag(0)
                    Text("Tasks").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150) // Fixed width for centered look
                
                // Layer 3: Right Aligned Settings
                HStack {
                    Spacer()
                    Button(action: {
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettings) {
                        SettingsView()
                    }
                }
            }
            .padding()
            
            Divider()
            
            if selectedTab == 0 {
                NotesView()
            } else {
                TasksView()
            }
        }
    }
}
