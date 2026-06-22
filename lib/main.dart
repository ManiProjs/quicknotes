import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const QuickNotesApp());
}

class QuickNotesApp extends StatelessWidget {
  const QuickNotesApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quick Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  List<Map<String, dynamic>> notes = [];
  String searchQuery = '';

  Color selectedColor = const Color(0xFFD0E8FF);

  final List<Color> palette = const [
    Color(0xFFD0E8FF), // soft blue
    Color(0xFFD7F0D1), // soft green
    Color(0xFFFFE0B2), // soft orange
    Color(0xFFE9D5FF), // soft purple
    Color(0xFFFFD6D6), // soft red
    Color(0xFFFFF3BF), // soft yellow
  ];

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notes');

    if (data != null) {
      final decoded = jsonDecode(data);

      if (decoded is List) {
        setState(() {
          notes = decoded.map((item) {
            if (item is String) {
              // old format fallback (String note)
              return {'text': item, 'color': selectedColor.value};
            }
            return Map<String, dynamic>.from(item);
          }).toList();
        });
      }
    }
  }

  Future<void> saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('notes', jsonEncode(notes));
  }

  void addNote() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      notes.insert(0, {'text': text, 'color': selectedColor.value});
      _controller.clear();
    });

    saveNotes();
  }

  void deleteNote(int index) {
    setState(() {
      notes.removeAt(index);
    });

    saveNotes();
  }

  void editNote(int index) {
    final TextEditingController editController = TextEditingController(
      text: notes[index]['text'],
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Note"),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Update your note..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = editController.text.trim();
                if (updated.isNotEmpty) {
                  setState(() {
                    notes[index]['text'] = updated;
                  });
                  saveNotes();
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = notes.where((note) {
      final text = (note['text'] ?? '').toString().toLowerCase();
      return text.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Quick Notes")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: palette.map((c) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedColor = c;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selectedColor == c
                            ? Border.all(color: Colors.black54, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Shortcuts(
                    shortcuts: {
                      SingleActivator(LogicalKeyboardKey.enter, shift: true):
                          const ActivateIntent(),
                    },
                    child: Actions(
                      actions: {
                        ActivateIntent: CallbackAction<ActivateIntent>(
                          onInvoke: (_) {
                            addNote();
                            return null;
                          },
                        ),
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: "Write a note...",
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: addNote, child: const Text("+")),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: filteredNotes.isEmpty
                  ? const Center(child: Text("No notes yet 💤"))
                  : ListView.builder(
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        return Dismissible(
                          key: Key(
                            filteredNotes[index]['text'] + index.toString(),
                          ),
                          onDismissed: (_) =>
                              deleteNote(notes.indexOf(filteredNotes[index])),
                          child: Card(
                            color: Color(filteredNotes[index]['color']),
                            child: ListTile(
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              title: Text(filteredNotes[index]['text']),
                              onTap: () =>
                                  editNote(notes.indexOf(filteredNotes[index])),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => deleteNote(
                                  notes.indexOf(filteredNotes[index]),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
