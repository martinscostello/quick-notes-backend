import SwiftUI
import AppKit

struct MacEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    var onTextChange: (NSAttributedString) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let textView = SmartTextView()
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        
        // Critical: Set Storage Delegate to intercept ALL insertion events
        textView.textStorage?.delegate = context.coordinator
        
        textView.isRichText = true
        textView.importsGraphics = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .white
        textView.insertionPointColor = .white
        
        textView.typingAttributes = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]
        
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        // Connect Coordinator to View for Dictation
        context.coordinator.activeTextView = textView
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Connect Coordinator (Just in case)
        if context.coordinator.activeTextView !== textView {
            context.coordinator.activeTextView = textView
        }
        
        // PRE-PROCESS: Upgrade visuals (Round Corners + Size) Synchronously to prevent Flash
        let mutableText = NSMutableAttributedString(attributedString: text)
        context.coordinator.upgradeAttachments(in: mutableText)
        
        // Only update if visually different (optimistic check) to prevent infinite loops if possible
        if textView.attributedString() != mutableText {
             textView.textStorage?.setAttributedString(mutableText)
             
             // Re-apply delegate
             textView.textStorage?.delegate = context.coordinator
             
             textView.textColor = .white 
             textView.typingAttributes = [
                 .foregroundColor: NSColor.white,
                 .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
             ]
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MacEditor
        weak var activeTextView: NSTextView?
        var dictationRange: NSRange?
        
        init(_ parent: MacEditor) {
            self.parent = parent
            super.init()
            setupDictationObservers()
        }
        
        private func setupDictationObservers() {
            NotificationCenter.default.addObserver(self, selector: #selector(handleDictationStart), name: .dictationDidStart, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleDictationUpdate(_:)), name: .dictationDidUpdate, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleDictationEnd), name: .dictationDidEnd, object: nil)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func handleDictationStart() {
            // Optional: Prepare UI
        }
        
        @objc private func handleDictationUpdate(_ notification: Notification) {
            guard let textView = activeTextView, let storage = textView.textStorage else { return }
            guard let text = notification.userInfo?["text"] as? String else { return }
            
            let attributedText = NSAttributedString(string: text, attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ])
            
            if let range = dictationRange {
                // Check bounds to avoid crash
                if range.location + range.length <= storage.length {
                    storage.replaceCharacters(in: range, with: attributedText)
                    dictationRange = NSRange(location: range.location, length: attributedText.length)
                } else {
                     // Recovery
                     let end = storage.length
                     storage.replaceCharacters(in: NSRange(location: end, length: 0), with: attributedText)
                     dictationRange = NSRange(location: end, length: attributedText.length)
                }
            } else {
                // First insertion
                let selected = textView.selectedRange()
                let location = selected.location != NSNotFound ? selected.location : storage.length
                
                storage.replaceCharacters(in: NSRange(location: location, length: 0), with: attributedText)
                dictationRange = NSRange(location: location, length: attributedText.length)
            }
            
            // Sync Binding System
            textView.didChangeText()
            textView.scrollRangeToVisible(NSRange(location: (dictationRange?.location ?? 0) + (dictationRange?.length ?? 0), length: 0))
        }
        
        @objc private func handleDictationEnd() {
            dictationRange = nil
        }
        
        // Synchronous Upgrade: Fixes Flash & Applies Rounded Corners
        func upgradeAttachments(in string: NSMutableAttributedString) {
             var replacements: [(NSRange, ThumbnailAttachment, NSImage)] = []
             
             string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length), options: []) { (value, range, stop) in
                 if let attachment = value as? NSTextAttachment {
                     
                     // 1. Recover Image
                     var imageToUse: NSImage? = attachment.image
                     
                     if imageToUse == nil {
                          if let wrapper = attachment.fileWrapper, 
                             let data = wrapper.regularFileContents, 
                             let img = NSImage(data: data) {
                             imageToUse = img
                          } else if let data = attachment.contents, let img = NSImage(data: data) {
                              imageToUse = img
                          }
                     }
                     
                     // 2. Process Image (Round Corners + Thumbnail)
                     if let img = imageToUse {
                         // Always regenerate thumbnail to ensure Rounded Corners
                         if let (rounded, pngData) = img.createRoundedThumbnail() {
                              let wrapper = FileWrapper(regularFileWithContents: pngData)
                              wrapper.preferredFilename = "image.png"
                              
                              let newAttachment = ThumbnailAttachment(fileWrapper: wrapper)
                              newAttachment.image = rounded
                              
                              replacements.append((range, newAttachment, img)) // Store ORIGINAL image for Zoom
                         }
                     }
                 }
             }
             
             if !replacements.isEmpty {
                 string.beginEditing()
                 for (range, newAttachment, originalImg) in replacements {
                     string.removeAttribute(.attachment, range: range)
                     string.addAttribute(.attachment, value: newAttachment, range: range)
                     
                     // Attributes
                     string.addAttribute(NSAttributedString.Key("OriginalImage"), value: originalImg, range: range)
                     string.addAttribute(.cursor, value: NSCursor.pointingHand, range: range)
                 }
                 string.endEditing()
             }
        }
        
        // MARK: - NSTextStorageDelegate
        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            if editedMask.contains(.editedAttributes) || editedMask.contains(.editedCharacters) {
                // 1. Enforce Colors
                if editedMask.contains(.editedCharacters) {
                     textStorage.addAttribute(.foregroundColor, value: NSColor.white, range: editedRange)
                }
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            textView.textColor = .white
            textView.typingAttributes = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
            
            let newText = NSAttributedString(attributedString: textView.attributedString())
            self.parent.text = newText
            self.parent.onTextChange(newText)
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            textView.typingAttributes = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
        }
    }
}

// MARK: - Image Helper
extension NSImage {
    func createRoundedThumbnail() -> (NSImage, Data)? {

        let resolutionWidth: CGFloat = 400
        let imgSize = self.size.width > 0 && self.size.height > 0 ? self.size : CGSize(width: 100, height: 100)
        let renderSize = CGSize(width: resolutionWidth, height: resolutionWidth * (imgSize.height / imgSize.width))
        
        let thumbnail = NSImage(size: renderSize)
        thumbnail.lockFocus()
        
        // Rounded Clip
        let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: renderSize), xRadius: 24, yRadius: 24)
        path.addClip()
        
        self.draw(in: NSRect(origin: .zero, size: renderSize), from: NSRect(origin: .zero, size: imgSize), operation: .sourceOver, fraction: 1.0)
        thumbnail.unlockFocus()
        
        guard let tiffRepresentation = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return (thumbnail, pngData)
    }
}

// MARK: - Custom Attachment Subclass
class ThumbnailAttachment: NSTextAttachment {
    let targetWidth: CGFloat = 80
    
    // This is the native way to request size in TextKit 1
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: NSRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> NSRect {
        guard let image = self.image else { return .zero }
        let size = image.size
        guard size.width > 0 else { return .zero }
        
        let ratio = size.height / size.width
        return NSRect(x: 0, y: 0, width: targetWidth, height: targetWidth * ratio)
    }
}

class SmartTextView: NSTextView {
    
    override func mouseDown(with event: NSEvent) {
        // Zoom Logic
        let point = self.convert(event.locationInWindow, from: nil)
        let charIndex = self.layoutManager?.characterIndex(for: point, in: self.textContainer!, fractionOfDistanceBetweenInsertionPoints: nil)
        
        if let idx = charIndex, idx < self.textStorage?.length ?? 0 {
             let attributes = self.textStorage?.attributes(at: idx, effectiveRange: nil)
            if let originalImage = attributes?[NSAttributedString.Key("OriginalImage")] as? NSImage {
                 // Open in Default Preview App
                 if let tiff = originalImage.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiff),
                    let data = bitmap.representation(using: .png, properties: [:]) {
                     
                     let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
                     
                     do {
                         try data.write(to: tempURL)
                         NSWorkspace.shared.open(tempURL)
                     } catch {
                         print("Failed to save temp image: \(error)")
                     }
                 }
                 return 
            }
        }
        super.mouseDown(with: event)
    }

    // 1. Killer Block Strategy WITH Priority URL Loading
    override func readSelection(from pboard: NSPasteboard) -> Bool {
        // A. Try to handle images (PRIORITY)
        if handleImages(from: pboard) {
            return true
        }
        
        // B. KILL FILES.
        if let types = pboard.types {
            let forbidden = [
                NSPasteboard.PasteboardType.fileURL,
                NSPasteboard.PasteboardType("com.apple.finder.node"),
                NSPasteboard.PasteboardType("public.file-url"),
                NSPasteboard.PasteboardType("NSFilenamesPboardType")
            ]
            for type in forbidden {
                if types.contains(type) { 
                    return false // BLOCKED
                }
            }
        }
        
        // C. Allow whatever is left (Pure text, etc)
        return super.readSelection(from: pboard)
    }

    override func paste(_ sender: Any?) {
        _ = readSelection(from: NSPasteboard.general)
    }
    
    // 2. Killer Block Drag
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // A. Try to handle images
        if handleImages(from: sender.draggingPasteboard) {
            return true
        }
        
        // B. KILL FILES
        if let types = sender.draggingPasteboard.types {
             let forbidden = [
                NSPasteboard.PasteboardType.fileURL,
                NSPasteboard.PasteboardType("com.apple.finder.node"),
                NSPasteboard.PasteboardType("public.file-url"),
                NSPasteboard.PasteboardType("NSFilenamesPboardType")
            ]
            for type in forbidden {
                if types.contains(type) { return false }
            }
        }
        
        // C. Allow Text
        return super.performDragOperation(sender)
    }
    
    @discardableResult
    private func handleImages(from pasteboard: NSPasteboard) -> Bool {
        var images: [NSImage] = []
        
        // Priority 1: Check for explicit FILE URLs first (e.g. Finder Copy)
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
            for url in urls {
                guard url.isFileURL else { continue }
                if isImageExtension(url.pathExtension) {
                    let didStart = url.startAccessingSecurityScopedResource()
                    defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                    
                    if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                        images.append(image)
                    } else if let image = NSImage(contentsOf: url) {
                         images.append(image)
                    }
                }
            }
        }
        
        // Priority 2: Direct NSImage objects
        if images.isEmpty {
            if let directImages = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !directImages.isEmpty {
                images.append(contentsOf: directImages)
            }
        }
        
        // Priority 3: Fallback manual Pasteboard init
        if images.isEmpty {
            if let image = NSImage(pasteboard: pasteboard) {
                images.append(image)
            }
        }
        
        // Priority 4: Legacy Filename lists
        if images.isEmpty {
             if let propertyList = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
                for path in propertyList {
                    let url = URL(fileURLWithPath: path)
                    if isImageExtension(url.pathExtension) {
                         if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                             images.append(image)
                         } else if let image = NSImage(contentsOf: url) {
                             images.append(image)
                         }
                    }
                }
            }
        }

        if !images.isEmpty {
            for image in images {
                insertImage(image: image)
            }
            return true
        }
        
        return false
    }
    
    private func isImageExtension(_ ext: String) -> Bool {
        let valid = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic", "icns"]
        return valid.contains(ext.lowercased())
    }
    
    private func insertImage(image: NSImage) {
        // Use shared Helper
        guard let (thumbnail, pngData) = image.createRoundedThumbnail() else { return }
        
        // 3. Create FileWrapper (Solves CGImageDestinationFinalize logs)
        let wrapper = FileWrapper(regularFileWithContents: pngData)
        wrapper.preferredFilename = "image.png"
        
        // 4. Create Attachment with Subclass
        let attachment = ThumbnailAttachment(fileWrapper: wrapper)
        attachment.image = thumbnail // Cache for display
        
        let attString = NSMutableAttributedString(attachment: attachment)
        attString.addAttribute(NSAttributedString.Key("OriginalImage"), value: image, range: NSRange(location: 0, length: attString.length))
        attString.addAttribute(.cursor, value: NSCursor.pointingHand, range: NSRange(location: 0, length: attString.length))
        
        if let mutableStorage = self.textStorage {
            let selectedRange = self.selectedRange()
            if selectedRange.location != NSNotFound {
                let newline = NSAttributedString(string: "\n", attributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
                let wrapper = NSMutableAttributedString()
                wrapper.append(newline)
                wrapper.append(attString)
                wrapper.append(newline)
                
                mutableStorage.replaceCharacters(in: selectedRange, with: wrapper)
                self.didChangeText()
            }
        }
    }
}
