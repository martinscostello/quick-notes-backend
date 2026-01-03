import Foundation
import AppKit

@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private var lastSync: String? {
        get { UserDefaults.standard.string(forKey: "lastSyncTimestamp") }
        set { UserDefaults.standard.set(newValue, forKey: "lastSyncTimestamp") }
    }
    
    private var isSyncing = false
    @Published var dirtyPages: Set<Int> = []
    @Published var conflictedPages: Set<Int> = []
    
    func markDirty(index: Int) {
        if !conflictedPages.contains(index) {
             dirtyPages.insert(index)
             triggerSync()
        }
    }
    
    private var syncTask: Task<Void, Never>?
    
    func triggerSync() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await performSync()
        }
    }
    
    func performSync() async {
        guard !isSyncing else { return }
        guard APIService.shared.isAuthenticated else { return }
        
        isSyncing = true
        print("🔄 Starting Sync...")
        
        do {
            // STEP 1: PULL FIRST (Check for conflicts)
            // We ask for changes without sending ours yet
            let (serverChanges, newTime) = try await APIService.shared.sync(changes: [], lastSyncTimestamp: lastSync)
            
            var safeToPush: Set<Int> = dirtyPages
            
            // STEP 2: DETECT CONFLICTS
            for note in serverChanges {
                if let idStr = note.localId.split(separator: "_").last, let index = Int(idStr) {
                    
                    if dirtyPages.contains(index) {
                        // CONFLICT! Server has new data, but we also have unsaved local changes.
                        print("⚠️ Conflict detected on Page \(index)")
                        conflictedPages.insert(index)
                        safeToPush.remove(index) // Do not push this one
                        
                        // For the conflict UI, we might want to store the server content temporarily?
                        // For now we just flag it. The UI acts as the resolver.
                        
                    } else {
                        // Safe to apply server update
                         importHTML(html: note.content, at: index)
                    }
                }
            }
            
            // STEP 3: PUSH ONLY SAFE PAGES
            // Now we push the pages that had NO incoming changes from server
            if !safeToPush.isEmpty {
                var updates: [APIService.NoteUpdate] = []
                for index in safeToPush {
                    if DataManager.shared.notePages.indices.contains(index) {
                        let content = DataManager.shared.notePages[index]
                        if let html = await exportHTML(from: content) {
                            updates.append(APIService.NoteUpdate(
                                localId: "page_\(index)",
                                content: html,
                                version: 1,
                                isDeleted: false
                            ))
                        }
                    }
                }
                
                if !updates.isEmpty {
                    // Send second request to PUSH
                    _ = try await APIService.shared.sync(changes: updates, lastSyncTimestamp: nil) // Timestamp nil? No because we want to push.
                    // Actually lastSyncTimestamp is irrelevant for Push, but we don't want to re-pull the same things we just ignored...
                    // But our API echoes back changes.
                }
                
                // Remove synced pages from dirty
                for index in safeToPush {
                    dirtyPages.remove(index)
                }
            }
            
            // Update Timestamp ONLY if we processed everything successfully?
            // If we have conflicts, we technically "synced" partially.
            // But if we update timestamp, we won't get those conflicting notes again next time...
            // So we should NOT update timestamp if there were conflicts?
            // Or we should update it but keep the conflicting note 'unresolved'.
            if conflictedPages.isEmpty {
                 lastSync = newTime
            }
            
            print("✅ Sync Cycle Complete")
            
        } catch {
            print("❌ Sync Failed: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(index: Int, keepLocal: Bool) {
        conflictedPages.remove(index)
        if keepLocal {
            // Force Push
            dirtyPages.insert(index) // Ensure it's marked dirty
            triggerSync()
            // We need a way to force overwrite server? 
            // Our "Last Write Wins" logic in backend will accept our push and update timestamp, so we win automatically.
        } else {
            // Keep Server
            // We need to re-fetch the server version.
            // Simplest way: Reset lastSyncTimestamp to 0 for this page? 
            // Or just trigger a pull?
            // Since we didn't apply the server update during Step 2 (conflict), we lost the data in memory.
            // We need to re-pull.
            Task {
                 // Hack: Reset sync time to force full pull
                 lastSync = nil 
                 dirtyPages.remove(index) // Discard local dirty state
                 await performSync()
            }
        }
    }
    
    // MARK: - HTML Conversion
    
    private func exportHTML(from attributedString: NSAttributedString) async -> String? {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        
        struct AttachmentInfo {
            let range: NSRange
            let attachment: NSTextAttachment
        }
        var attachments: [AttachmentInfo] = []
        
        mutable.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            if let att = value as? NSTextAttachment {
                attachments.append(AttachmentInfo(range: range, attachment: att))
            }
        }
        
        for info in attachments {
            if let wrapper = info.attachment.fileWrapper {
                if mutable.attribute(NSAttributedString.Key("RemoteURL"), at: info.range.location, effectiveRange: nil) == nil {
                    if let data = wrapper.regularFileContents {
                         do {
                             let url = try await APIService.shared.uploadImage(data: data)
                             mutable.addAttribute(NSAttributedString.Key("RemoteURL"), value: url, range: info.range)
                         } catch {
                             print("Image Upload Error: \(error)")
                         }
                    }
                }
            }
        }
        
        var html = ""
        mutable.enumerateAttributes(in: fullRange) { attrs, range, _ in
            if let _ = attrs[.attachment] as? NSTextAttachment,
               let remoteURL = attrs[NSAttributedString.Key("RemoteURL")] as? String {
                html += "<img src=\"\(remoteURL)\" style=\"max-width:100%; border-radius:12px;\" />"
            } else {
                let text = mutable.attributedSubstring(from: range).string
                let escaped = text.replacingOccurrences(of: "&", with: "&amp;")
                                  .replacingOccurrences(of: "<", with: "&lt;")
                                  .replacingOccurrences(of: ">", with: "&gt;")
                                  .replacingOccurrences(of: "\n", with: "<br>")
                html += escaped
            }
        }
        return html
    }
    
    private func importHTML(html: String, at index: Int) {
        guard let data = html.data(using: .utf8) else { return }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let newString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
             let mutable = NSMutableAttributedString(attributedString: newString)
             mutable.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: mutable.length))
             mutable.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize), range: NSRange(location: 0, length: mutable.length))
            DataManager.shared.updateFromSync(index: index, content: mutable)
        }
    }
}
