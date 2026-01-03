import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import '../widgets/glass_container.dart';
import '../database/local_database.dart';
import '../models.dart';
import 'dart:async'; 
import '../utils/image_helper.dart';
import '../utils/note_parser.dart';
import 'dart:io';

class NotesPageUI extends StatefulWidget {
  final Stream<DictationEvent>? dictationStream;
  const NotesPageUI({super.key, this.dictationStream});

  @override
  State<NotesPageUI> createState() => _NotesPageUIState();
}

class _NotesPageUIState extends State<NotesPageUI> {
  List<Note> _notes = [];
  int _currentIndex = 0;
  
  // BLOCK STATE
  List<EditorBlock> _blocks = [];
  bool _isLoading = true;
  Timer? _debounce;
  StreamSubscription? _dictationSub;
  
  // DICTATION STATE
  int? _activeDictationBlockIndex;
  int _lastPartialLength = 0;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    
    // Listen to Dictation
    if (widget.dictationStream != null) {
        _dictationSub = widget.dictationStream!.listen((event) {
             _handleDictationEvent(event);
        });
    }
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    _dictationSub?.cancel();
    for (var b in _blocks) b.dispose();
    super.dispose();
  }

  Future<void> _loadNotes({bool keepIndex = true}) async {
    setState(() => _isLoading = true);
    final notes = await LocalDatabase.instance.getAllNotes();
    
    if (mounted) {
      setState(() {
        _notes = notes;
        
        // Ensure index is valid
        if (keepIndex) {
            if (_currentIndex >= _notes.length) _currentIndex = _notes.length - 1;
            if (_currentIndex < 0) _currentIndex = 0;
        } else {
            _currentIndex = _notes.length - 1;
        }

        // PARSE CONTENT INTO BLOCKS
        _rebuildBlocks();
        
        _isLoading = false;
      });
    }
  }

  void _rebuildBlocks() {
      for (var b in _blocks) b.dispose();

      String content = "";
      if (_notes.isNotEmpty && _currentIndex < _notes.length) {
          content = _notes[_currentIndex].content;
      }
      _blocks = NoteParser.parse(content);
  }

  Future<void> _saveCurrent() async {
     if (_notes.isNotEmpty && _currentIndex < _notes.length) {
         final content = NoteParser.toHtml(_blocks);
         
         // Memory Update
         _notes[_currentIndex].content = content;
         
         // DB Update
         await LocalDatabase.instance.saveNoteContent(_notes[_currentIndex].pageIndex, content);
     }
  }
  
  void _onContentChanged() {
      // Debounce Save
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
          _saveCurrent();
      });
  }
  
  // Track the last event text to detect segment resets
  String _lastEventText = "";

  void _handleDictationEvent(DictationEvent event) {
      if (event.text.isEmpty) return;
      
      // 1. Find or Create Block
      if (_activeDictationBlockIndex == null) {
           // Find focused text block
           int? focusedIndex;
           for (int i=0; i<_blocks.length; i++) {
               if (_blocks[i].type == BlockType.text && (_blocks[i].focusNode?.hasFocus ?? false)) {
                   focusedIndex = i;
                   break;
               }
           }
           
           if (focusedIndex == null) {
               if (_blocks.isEmpty || _blocks.last.type != BlockType.text) {
                   _blocks.add(EditorBlock(type: BlockType.text));
                   setState(() {});
               }
               focusedIndex = _blocks.length - 1;
           }
           _activeDictationBlockIndex = focusedIndex;
           _lastPartialLength = 0;
           _lastEventText = "";
           
           // Append Space if needed
           final controller = _blocks[focusedIndex!].controller!;
           if (controller.text.isNotEmpty && !controller.text.endsWith(' ')) {
               controller.text = "${controller.text} "; 
           }
      }
      
      final blockIndex = _activeDictationBlockIndex!;
      if (blockIndex >= _blocks.length) return; 
      
      // 2. Detect Implicit Segment Break (Reset)
      // If the dictionary stream resets (e.g. "Hello world" -> "New") without firing isFinal,
      // we need to commit the previous text and treat this as new.
      bool inferredBreak = false;
      if (_lastEventText.isNotEmpty && event.text.length < _lastEventText.length) {
           // If the new text is significantly shorter and NOT a prefix of the old text,
           // it is likely a new sentence.
           // Heuristic: If they don't share a common start of at least 3 chars?
           if (!event.text.startsWith(_lastEventText.substring(0, 3 > _lastEventText.length ? _lastEventText.length : 3))) {
                inferredBreak = true;
           }
      }
      
      if (inferredBreak) {
           // We treat the *previous* state as committed.
           // We do NOT remove _lastPartialLength.
           _lastPartialLength = 0;
           _lastEventText = "";
           
           // Append a space if not present (implies new sentence)
           final c = _blocks[blockIndex].controller!;
           if (c.text.isNotEmpty && !c.text.endsWith(' ')) {
               c.text = "${c.text} ";
           }
      }

      final controller = _blocks[blockIndex].controller!;
      String currentText = controller.text;
      
      // 3. Remove previous partial text
      if (_lastPartialLength > 0) {
          if (currentText.length >= _lastPartialLength) {
             currentText = currentText.substring(0, currentText.length - _lastPartialLength);
          } else {
             // weird sync issue, reset
             currentText = ""; 
          }
      }
      
      // 4. Append new partial text
      String newText = currentText + event.text;
      
      controller.text = newText;
      controller.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
      
      // 5. Update State
      _lastPartialLength = event.text.length;
      _lastEventText = event.text;
      
      if (event.isFinal) {
          _activeDictationBlockIndex = null;
          _lastPartialLength = 0;
          _lastEventText = "";
          _onContentChanged(); 
      } else {
          _onContentChanged();
      }
  }

  Future<void> _insertImageByPath(String path) async {
       // 1. Insert Local (Immediate UI)
       // We keep a reference to the block so we can update it
       final imageBlock = EditorBlock(type: BlockType.image, imagePath: path);
       
       setState(() {
           _blocks.add(imageBlock);
           _blocks.add(EditorBlock(type: BlockType.text));
       });
       await _saveCurrent();
       
       // 2. Background Upload
       // Note: This is simple fire-and-forget for now. 
       // Ideally we show a spinner on the image.
       ImageHelper.instance.uploadImage(path).then((url) async {
           if (url != null && mounted) {
               setState(() {
                   imageBlock.imagePath = url; // Swap Local Path -> Remote URL
               });
               await _saveCurrent(); // Save URL to DB
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image synced to cloud"), duration: Duration(seconds: 1)));
           } else {
               // Upload failed, keep local path
               print("Image upload failed, keeping local path.");
           }
       });
  }

  Future<void> _handlePaste() async {
      // 1. Try paste Binary Image (Native Pasteboard)
      String? imagePath = await ImageHelper.instance.pasteImageFromClipboard();
      
      if (imagePath != null) {
          await _insertImageByPath(imagePath);
          return;
      }

      // 2. Try paste Text (URL)
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
          final text = clipboardData!.text!.trim();
          
          if (text.startsWith('http') && _isImageExtension(text)) {
              final confirm = await showDialog<bool>(
                  context: context, 
                  builder: (context) => AlertDialog(
                      title: const Text("Download Image?"),
                      content: Text("Do you want to insert the image from:\n$text"),
                      actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Insert")),
                      ],
                  )
              );
              
              if (confirm == true) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading image..."), duration: Duration(seconds: 1)));
                  final dlPath = await ImageHelper.instance.downloadImage(text);
                  if (dlPath != null) {
                      await _insertImageByPath(dlPath);
                  } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to download image")));
                  }
              }
          } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clipboard does not contain an image or image URL.")));
          }
      }
  }

  bool _isImageExtension(String url) {
      final lower = url.toLowerCase();
      return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  void _openImagePreview(String path) {
      bool isNet = path.startsWith('http');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
            body: Center(
              child: InteractiveViewer(
                child: isNet ? Image.network(path) : Image.file(File(path)),
              ),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool hasContent = _notes.isNotEmpty && _notes[_currentIndex].content.isNotEmpty;

    return Stack(
      children: [
        Column(
          children: [
            // TOP PAGINATION BAR (Glass)
            GlassContainer(
              height: 60,
              opacity: 0, // Transparent container, items have their own buttons
              borderRadius: 0, 
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentIndex;
                        // Pagination Item
                        return GestureDetector(
                          onTap: () async {
                             if (_debounce?.isActive ?? false) {
                                _debounce!.cancel();
                                await _saveCurrent();
                             }
                             setState(() {
                               _currentIndex = index;
                               _rebuildBlocks(); 
                             });
                          },
                          child: Container(
                            width: 36, 
                            height: 36, // Explicit height for square
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Colors.deepPurpleAccent.withValues(alpha: 0.8) 
                                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6)),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isDark ? null : [ 
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                // User: "darkmode: notes tab numbers = white"
                                color: isDark ? Colors.white : (isSelected ? Colors.white : Colors.black87),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add Button
                  GestureDetector(
                    onTap: () async {
                      if (_debounce?.isActive ?? false) {
                         _debounce!.cancel();
                         await _saveCurrent();
                      }
                      await LocalDatabase.instance.addPage();
                      await _loadNotes(keepIndex: false); 
                    },
                    child: Container(
                       width: 36,
                       height: 36,
                       alignment: Alignment.center,
                       decoration: BoxDecoration(
                         color: isDark ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.6),
                         borderRadius: BorderRadius.circular(10),
                         boxShadow: isDark ? null : [
                             BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))
                         ]
                       ),
                       child: Icon(Icons.add, color: isDark ? Colors.white : Colors.black87, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            
            // EDITOR AREA (Transparent to let MainScreen glass show)
            Expanded(
              child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 // "Notes card transparent glass". 
                 // Currently MainScreen has opacity 0.6. This child can be mostly transparent.
                 color: Colors.transparent, 
                 child: GestureDetector(
                   onTap: () {
                     if (_blocks.isNotEmpty && _blocks.last.type == BlockType.text) {
                        _blocks.last.focusNode?.requestFocus();
                     } else {
                         if (_blocks.isEmpty || _blocks.last.type != BlockType.text) {
                             setState(() {
                                 _blocks.add(EditorBlock(type: BlockType.text));
                             });
                             Future.delayed(const Duration(milliseconds: 50), () {
                                 _blocks.last.focusNode?.requestFocus();
                             });
                         }
                     }
                   },
                   child: ListView.builder(
                       itemCount: _blocks.length,
                       itemBuilder: (context, index) {
                           final block = _blocks[index];
                           
                           if (block.type == BlockType.image) {
                               // RENDER IMAGE THUMBNAIL (POLISHED)
                               bool isNet = block.imagePath!.startsWith('http');
                               
                               return Align(
                                 alignment: Alignment.centerLeft, 
                                 child: Padding(
                                     padding: const EdgeInsets.symmetric(vertical: 8),
                                     child: Stack(
                                         children: [
                                             GestureDetector(
                                                 onTap: () => _openImagePreview(block.imagePath!),
                                                 child: Container(
                                                     constraints: const BoxConstraints(
                                                       maxWidth: 130, 
                                                       maxHeight: 150, 
                                                     ),
                                                     padding: const EdgeInsets.all(4), 
                                                     decoration: BoxDecoration(
                                                       color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
                                                       borderRadius: BorderRadius.circular(12),
                                                     ),
                                                     child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: isNet 
                                                            ? Image.network(
                                                                block.imagePath!,
                                                                fit: BoxFit.contain,
                                                                errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.grey),
                                                              )
                                                            : Image.file(
                                                                File(block.imagePath!),
                                                                fit: BoxFit.contain, 
                                                                errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.grey),
                                                            ),
                                                     ),
                                                 ),
                                             ),
                                             
                                             // DELETE IMAGE BUTTON
                                             Positioned(
                                               top: -5,
                                               right: -5,
                                               child: IconButton(
                                                    iconSize: 18,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: Container(
                                                      decoration: const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding: const EdgeInsets.all(2),
                                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                                    ),
                                                    onPressed: () async {
                                                        setState(() {
                                                            _blocks.removeAt(index);
                                                        });
                                                        await _saveCurrent();
                                                    },
                                                ),
                                             ),
                                         ],
                                     ),
                                 ),
                               );
                           } else {
                               // RENDER TEXT
                               return TextField(
                                   controller: block.controller,
                                   focusNode: block.focusNode,
                                   maxLines: null,
                                   onChanged: (_) => _onContentChanged(),
                                   decoration: const InputDecoration(
                                       border: InputBorder.none,
                                       hintText: "",
                                       isDense: true,
                                   ),
                                   style: TextStyle(
                                       fontSize: 18, 
                                       height: 1.5, 
                                       color: isDark ? Colors.white : Colors.black87,
                                   ),
                                   cursorColor: isDark ? Colors.white : Colors.blue,
                               );
                           }
                       },
                   ),
                 ),
              ),
            ),
            
            // BOTTOM TOOLBAR (DELETE/CLEAR BUTTON)
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 0,
              opacity: 0.3,
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.start,
                 children: [
                    // DELETE/CLEAR BUTTON
                    GestureDetector(
                      onTap: () async {
                        if (hasContent) {
                          setState(() {
                              _blocks.clear();
                              _blocks.add(EditorBlock(type: BlockType.text));
                              _notes[_currentIndex].content = "";
                          });
                          await _saveCurrent();
                        } else {
                          if (_currentIndex == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Page 1 cannot be deleted.")));
                              return;
                          } 
                          await LocalDatabase.instance.deletePage(_currentIndex);
                          if (_currentIndex > 0) _currentIndex--;
                          await _loadNotes(keepIndex: true);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: hasContent ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasContent ? "Clear Page" : "Delete Page",
                          style: TextStyle(
                            color: hasContent ? Colors.blue : Colors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                 ],
              ),
            )
          ],
        ),

        // FLOATING ACTION BUTTONS (Bottom Right)
        Positioned(
          bottom: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               // PASTE BUTTON
               _buildActionButton(
                 asset: 'assets/images/paste_icon.png', 
                 fallbackIcon: Icons.content_paste,
                 fallbackColor: Colors.orangeAccent,
                 onTap: _handlePaste,
                 isDark: isDark
               ),
               const SizedBox(width: 12),
               // IMAGE BUTTON
               _buildActionButton(
                 asset: 'assets/images/gallery_icon.png', 
                 fallbackIcon: Icons.image_outlined,
                 fallbackColor: Colors.blueAccent,
                 onTap: () async {
                      final path = await ImageHelper.instance.pickAndSaveImage();
                      if (path != null) {
                          await _insertImageByPath(path);
                      }
                  },
                 isDark: isDark
               ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
      required String asset, 
      required IconData fallbackIcon,
      required Color fallbackColor,
      required VoidCallback onTap, 
      required bool isDark
  }) {
    return GestureDetector(
       onTap: onTap,
       child: GlassContainer(
          width: 42,
          height: 42,
          borderRadius: 14,
          blur: 15,
          opacity: isDark ? 0.2 : 0.6,
          padding: const EdgeInsets.all(10),
          shadows: isDark ? null : [
             BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))
          ],
          child: Image.asset(
              asset, 
              fit: BoxFit.contain, 
              errorBuilder: (c,e,s) => Icon(fallbackIcon, size: 20, color: isDark ? Colors.white : fallbackColor)
          ), 
       ),
    );
  }
}
