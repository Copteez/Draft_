// This is a utility script to find all references to generateRandomAQIData
// Run it in the terminal with: dart run_search.dart

import 'dart:io';

void main() async {
  print('Searching for references to generateRandomAQIData...');

  // First, we'll create a temporary file to store the search results
  final resultsFile =
      File('d:\\Senior\\Code\\Flutter\\Draft_\\search_results.txt');
  if (await resultsFile.exists()) {
    await resultsFile.delete();
  }

  await searchInDirectory(Directory('d:\\Senior\\Code\\Flutter\\Draft_\\lib'),
      'generateRandomAQIData', resultsFile);

  print('Search complete. Results saved to ${resultsFile.path}');
  print(
      'Please check this file to see all places where generateRandomAQIData is referenced.');
}

Future<void> searchInDirectory(
    Directory dir, String searchTerm, File resultsFile) async {
  try {
    List<FileSystemEntity> entities = await dir.list().toList();

    for (var entity in entities) {
      if (entity is Directory) {
        await searchInDirectory(entity, searchTerm, resultsFile);
      } else if (entity is File &&
          (entity.path.endsWith('.dart') || entity.path.endsWith('.yaml'))) {
        await searchInFile(entity, searchTerm, resultsFile);
      }
    }
  } catch (e) {
    await resultsFile.writeAsString(
        'Error searching directory ${dir.path}: $e\n',
        mode: FileMode.append);
  }
}

Future<void> searchInFile(
    File file, String searchTerm, File resultsFile) async {
  try {
    String contents = await file.readAsString();
    if (contents.contains(searchTerm)) {
      await resultsFile.writeAsString('Found "$searchTerm" in: ${file.path}\n',
          mode: FileMode.append);

      // Print line numbers and lines containing the term
      List<String> lines = contents.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains(searchTerm)) {
          await resultsFile.writeAsString(
              '  Line ${i + 1}: ${lines[i].trim()}\n',
              mode: FileMode.append);
        }
      }
      await resultsFile.writeAsString('\n', mode: FileMode.append);
    }
  } catch (e) {
    await resultsFile.writeAsString('Error reading ${file.path}: $e\n',
        mode: FileMode.append);
  }
}
