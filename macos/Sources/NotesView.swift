import SwiftUI

struct NotesView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var text: NSAttributedString = NSAttributedString(string: "")
    
    // Note: SpeechManager is now handled in ContentView for global button access
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Pagination Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<dataManager.notePages.count, id: \.self) { index in
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 24, height: 24)
                                .background(dataManager.selectedPageIndex == index ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundColor(dataManager.selectedPageIndex == index ? .white : .primary)
                                .cornerRadius(6)
                                .onTapGesture {
                                    dataManager.selectedPageIndex = index
                                    text = dataManager.notePages[index]
                                }
                        }
                        
                        Button {
                            dataManager.addPage()
                            text = dataManager.notePages[dataManager.selectedPageIndex]
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
                
                Divider()
                
                MacEditor(text: $text) { newValue in
                    dataManager.saveCurrentPage(newValue)
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    if dataManager.selectedPageIndex < dataManager.notePages.count {
                        text = dataManager.notePages[dataManager.selectedPageIndex]
                    }
                }
                .onChange(of: dataManager.selectedPageIndex) { newIndex in
                    if newIndex < dataManager.notePages.count {
                        text = dataManager.notePages[newIndex]
                    }
                }
                
                Divider()
                
                HStack {
                    if dataManager.selectedPageIndex > 0 && text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Delete Page") {
                            dataManager.deleteCurrentPage()
                            if dataManager.selectedPageIndex < dataManager.notePages.count {
                                text = dataManager.notePages[dataManager.selectedPageIndex]
                            }
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Clear Notes") {
                            dataManager.clearCurrentPage()
                            text = NSAttributedString(string: "")
                        }
                    }
                    
                    // Spacer pushes Quit to the right
                    Spacer()
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding(10)
            }
            

        }
    }
}
