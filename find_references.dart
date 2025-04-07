// This is a utility script to find all references to generateRandomAQIData
// Run with: dart find_references.dart

import 'dart:io';

void main() {
  searchInDirectory(Directory('lib'), 'generateRandomAQIData');
}

void searchInDirectory(Directory dir, String searchTerm) {
  try {
    List<FileSystemEntity> entities = dir.listSync();

    for (var entity in entities) {
      if (entity is Directory) {
        searchInDirectory(entity, searchTerm);
      } else if (entity is File &&
          (entity.path.endsWith('.dart') || entity.path.endsWith('.yaml'))) {
        searchInFile(entity, searchTerm);
      }
    }
  } catch (e) {
    print('Error searching directory ${dir.path}: $e');
  }
}

void searchInFile(File file, String searchTerm) {
  try {
    String contents = file.readAsStringSync();
    if (contents.contains(searchTerm)) {
      print('Found "${searchTerm}" in: ${file.path}');

      // Print line numbers and lines containing the term
      List<String> lines = contents.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains(searchTerm)) {
          print('  Line ${i + 1}: ${lines[i].trim()}');
        }
      }
      print('');
    }
  } catch (e) {
    print('Error reading ${file.path}: $e');
  }
}
