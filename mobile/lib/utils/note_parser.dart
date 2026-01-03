import 'package:flutter/material.dart';

enum BlockType { text, image }

class EditorBlock {
  final BlockType type;
  String? imagePath;
  TextEditingController? controller;
  FocusNode? focusNode;

  EditorBlock({required this.type, this.imagePath, String initialText = ""}) {
    if (type == BlockType.text) {
      controller = TextEditingController(text: initialText);
      focusNode = FocusNode();
    }
  }

  void dispose() {
    controller?.dispose();
    focusNode?.dispose();
  }
}

class NoteParser {
  // Regex to find <img src="file://(.*?)"[^>]*>
  // Handles generic attributes too
  static final RegExp _imgRegex = RegExp(r'<img src="file://(.*?)"[^>]*>');

  static List<EditorBlock> parse(String content) {
    if (content.isEmpty) {
      return [EditorBlock(type: BlockType.text)];
    }

    final List<EditorBlock> blocks = [];
    int lastIndex = 0;

    for (final match in _imgRegex.allMatches(content)) {
      // 1. Add preceding text if any
      if (match.start > lastIndex) {
        final text = content.substring(lastIndex, match.start).trim(); 
        // We trim to avoid excessive newlines around images, 
        // but might want to preserve them. Let's keep it simple: 
        // If it's just a newline, maybe keep it? 
        // For now, let's take the raw substring.
        final rawText = content.substring(lastIndex, match.start);
        if (rawText.isNotEmpty) {
           blocks.add(EditorBlock(type: BlockType.text, initialText: rawText));
        }
      }

      // 2. Add Image
      final path = match.group(1); 
      if (path != null) {
        blocks.add(EditorBlock(type: BlockType.image, imagePath: path));
      }

      lastIndex = match.end;
    }

    // 3. Add remaining text
    if (lastIndex < content.length) {
      final text = content.substring(lastIndex);
      if (text.isNotEmpty) {
         blocks.add(EditorBlock(type: BlockType.text, initialText: text));
      }
    }
    
    // Ensure always at least one text block at end for typing
    if (blocks.isEmpty || blocks.last.type != BlockType.text) {
        blocks.add(EditorBlock(type: BlockType.text));
    }

    return blocks;
  }

  static String toHtml(List<EditorBlock> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block.type == BlockType.text) {
        buffer.write(block.controller?.text ?? "");
      } else {
        // Enforce newline logic to ensure separation?
        // Let's just write the tag. 
        // We add newlines to make parsing easier/cleaner visually if viewed as text.
        buffer.write('\n<img src="file://${block.imagePath}" width="100%" />\n');
      }
    }
    return buffer.toString().trim();
  }
}
