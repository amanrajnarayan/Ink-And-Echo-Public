import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  await Hive.initFlutter();
  await Hive.openBox('journal_box');
  runApp(const InkAndEcho());
}

enum PaperStyle { plain, dotted, squared }
enum AppFont { merriweather, laBelleAurore, cedarvilleCursive }

class InkAndEcho extends StatelessWidget {
  const InkAndEcho({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFDF6E3),
        textTheme: GoogleFonts.merriweatherTextTheme(ThemeData.light().textTheme),
      ),
      home: const JournalHome(),
    );
  }
}

class JournalHome extends StatefulWidget {
  const JournalHome({super.key});

  @override
  State<JournalHome> createState() => _JournalHomeState();
}

class _JournalHomeState extends State<JournalHome> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedMood = "🌿";
  final List<String> _moods = ["🌿", "✨", "☕️", "📖", "🎧", "☁️", "🏔️", "🌙", "🌃", "✈️"];

  // Theme State
  bool _isMidnightMode = false;

  // Search & Filter State
  String? _filterMood;
  bool _isSearching = false;
  String _searchQuery = "";

  // Edit State
  dynamic _editingKey;

  PaperStyle _selectedStyle = PaperStyle.plain;
  AppFont _selectedFont = AppFont.merriweather;

  // Dynamic Theme Helpers
  Color get _bgColor => _isMidnightMode ? const Color(0xFF1E1E1E) : const Color(0xFFFDF6E3);
  Color get _inkColor => _isMidnightMode ? const Color(0xFFE6D5BC) : const Color(0xFF3B2F1E);
  Color get _accentColor => const Color(0xFF6B4F2A);
  Color get _boxColor => _isMidnightMode ? const Color(0xFF2D2D2D) : const Color(0xFFF5E6CA).withOpacity(0.3);
  Color get _borderColor => _isMidnightMode ? const Color(0xFF3D3D3D) : const Color(0xFFD6C9A8).withOpacity(0.4);

  TextStyle _getFont(AppFont font, {double size = 16, Color? color}) {
    final finalColor = color ?? _inkColor;
    switch (font) {
      case AppFont.merriweather:
        return GoogleFonts.merriweather(height: 1.8, fontSize: size, color: finalColor);
      case AppFont.laBelleAurore:
        return GoogleFonts.laBelleAurore(height: 1.6, fontSize: size + 6, color: finalColor);
      case AppFont.cedarvilleCursive:
        return GoogleFonts.cedarvilleCursive(height: 1.8, fontSize: size + 2, color: finalColor);
    }
  }

  // DATA MANAGEMENT

  Future<void> _exportBackup() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hiveFile = File('${appDir.path}/journal_box.hive');

      if (await hiveFile.exists()) {
        Uint8List bytes = await hiveFile.readAsBytes();
        await FilePicker.platform.saveFile(
          dialogTitle: 'Save Echo Backup',
          fileName: 'ink_and_echo_backup.hive',
          bytes: bytes,
        );
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  Future<void> _importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        final selectedFile = File(result.files.single.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final targetPath = '${appDir.path}/journal_box.hive';

        if (Hive.isBoxOpen('journal_box')) {
          await Hive.box('journal_box').close();
        }

        await selectedFile.copy(targetPath);
        await Hive.openBox('journal_box');

        HapticFeedback.vibrate();

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("RESTORATION COMPLETE"), backgroundColor: Color(0xFF6B4F2A)),
          );
        }
      }
    } catch (e) {
      debugPrint("Restore Error: $e");
      if (!Hive.isBoxOpen('journal_box')) await Hive.openBox('journal_box');
      setState(() {});
    }
  }

  // CORE LOGIC

  void _saveEntry() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    final box = Hive.box('journal_box');

    if (_editingKey != null) {
      final currentData = box.get(_editingKey);
      final Map<String, dynamic> updatedMap = currentData is Map
          ? Map<String, dynamic>.from(currentData)
          : {'text': currentData, 'mood': _selectedMood};

      updatedMap['text'] = text;
      updatedMap['mood'] = _selectedMood;

      box.put(_editingKey, updatedMap);
      _editingKey = null;
    } else {
      final timestamp = DateTime.now().toIso8601String();
      box.put(timestamp, {
        'text': text,
        'mood': _selectedMood,
        'font': AppFont.merriweather.name,
        'paperStyle': PaperStyle.plain.name,
      });
    }

    _controller.clear();
    setState(() => _selectedMood = "🌿");
    FocusScope.of(context).unfocus();
  }

  void _loadForEdit(dynamic entryKey, Map data) {
    HapticFeedback.mediumImpact();
    setState(() {
      _editingKey = entryKey;
      _controller.text = data['text'] ?? "";
      _selectedMood = data['mood'] ?? "🌿";
    });
  }

  Future<void> _handleDelete(BuildContext context, dynamic entryKey) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bgColor,
        title: Text("Delete Echo?", style: GoogleFonts.oswald(letterSpacing: 1.5, color: _inkColor)),
        content: Text("Remove this memory forever?", style: TextStyle(color: _inkColor.withOpacity(0.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("NO", style: TextStyle(color: _inkColor))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await Hive.box('journal_box').delete(entryKey);
      if (_editingKey == entryKey) {
        _controller.clear();
        _editingKey = null;
      }
      setState(() {});
    }
  }

  Future<Uint8List?> _captureImage(GlobalKey key) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareToStories(GlobalKey key) async {
    final bytes = await _captureImage(key);
    if (bytes != null) {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/echo_share.png').create();
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'My Echo #InkAndEcho');
    }
  }

  void _showFullEntry(BuildContext context, DateTime date, Map data, dynamic entryKey) {
    final String? savedStyleName = data['paperStyle'];
    final String? savedFontName = data['font'];

    _selectedStyle = PaperStyle.values.firstWhere(
          (e) => e.name == savedStyleName,
      orElse: () => PaperStyle.plain,
    );

    _selectedFont = AppFont.values.firstWhere(
          (e) => e.name == savedFontName,
      orElse: () => AppFont.merriweather,
    );

    final exportKey = GlobalKey();
    final String text = data['text'] ?? "";
    final String mood = data['mood'] ?? "🌿";
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          builder: (_, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text("PAPER & FONT", style: GoogleFonts.oswald(fontSize: 10, letterSpacing: 2, color: Colors.grey)),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PaperStyle.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
                        selected: _selectedStyle == s,
                        onSelected: (v) {
                          HapticFeedback.selectionClick();
                          setSheetState(() => _selectedStyle = s);

                          final box = Hive.box('journal_box');
                          final currentEntry = Map<String, dynamic>.from(box.get(entryKey));
                          currentEntry['paperStyle'] = s.name;
                          box.put(entryKey, currentEntry);
                          setState(() {});
                        },
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AppFont.values.map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
                        selected: _selectedFont == f,
                        onSelected: (v) {
                          HapticFeedback.selectionClick();
                          setSheetState(() => _selectedFont = f);

                          final box = Hive.box('journal_box');
                          final currentEntry = Map<String, dynamic>.from(box.get(entryKey));
                          currentEntry['font'] = f.name;
                          box.put(entryKey, currentEntry);
                          setState(() {});
                        },
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 30),
                RepaintBoundary(
                  key: exportKey,
                  child: Container(
                    color: _bgColor,
                    child: CustomPaint(
                      painter: PaperPainter(_selectedStyle, _isMidnightMode),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        constraints: const BoxConstraints(minHeight: 350),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("INK & ECHO", style: GoogleFonts.oswald(letterSpacing: 3, fontSize: 10, color: _inkColor.withOpacity(0.6))),
                                Text(DateFormat('MMMM dd, yyyy').format(date), style: GoogleFonts.oswald(fontSize: 10, color: _inkColor.withOpacity(0.6))),
                              ],
                            ),
                            Divider(height: 40, color: _borderColor),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mood, style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 15),
                                Expanded(child: Text(text, style: _getFont(_selectedFont))),
                              ],
                            ),
                            const SizedBox(height: 60),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text("Ink & Echo", style: GoogleFonts.merriweather(fontSize: 14, color: _inkColor.withOpacity(0.4))),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : () async {
                    setSheetState(() => isSaving = true);
                    HapticFeedback.mediumImpact();
                    final bytes = await _captureImage(exportKey);
                    if (bytes != null) await Gal.putImageBytes(bytes);
                    await Future.delayed(const Duration(seconds: 2));
                    if (context.mounted) setSheetState(() => isSaving = false);
                  },
                  icon: Icon(isSaving ? Icons.check_circle : Icons.save_alt, color: Colors.white),
                  label: Text(isSaving ? "SAVED" : "SAVE TO GALLERY", style: GoogleFonts.oswald(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSaving ? Colors.green : _accentColor,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _shareToStories(exportKey);
                  },
                  icon: Icon(Icons.share, size: 18, color: _isMidnightMode ? _inkColor : _accentColor),
                  label: Text("SHARE TO STORIES", style: GoogleFonts.oswald(color: _isMidnightMode ? _inkColor : _accentColor)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    side: BorderSide(color: _isMidnightMode ? _inkColor : _accentColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('journal_box');
    final rawEntries = box.values.toList().reversed.toList();
    final rawKeys = box.keys.toList().reversed.toList();

    final List<dynamic> filteredKeys = [];
    final List<dynamic> filteredEntries = [];

    // Compound Optimization Layer: Evaluates both matching search patterns AND active emotion parameters simultaneously
    for (int i = 0; i < rawEntries.length; i++) {
      final Map data = rawEntries[i] is Map ? rawEntries[i] : {'text': rawEntries[i], 'mood': '🌿'};
      final String textContent = (data['text'] ?? "").toString().toLowerCase();

      final bool matchesMood = _filterMood == null || data['mood'] == _filterMood;
      final bool matchesSearch = _searchQuery.isEmpty || textContent.contains(_searchQuery.toLowerCase());

      if (matchesMood && matchesSearch) {
        filteredKeys.add(rawKeys[i]);
        filteredEntries.add(rawEntries[i]);
      }
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: _bgColor,
            elevation: 0,
            actions: [
              // Search Expansion Icon Toggle
              IconButton(
                icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: _isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = "";
                      _searchController.clear();
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _isMidnightMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                  color: _isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isMidnightMode = !_isMidnightMode);
                },
              ),
              IconButton(
                icon: Icon(Icons.settings_backup_restore, color: _isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: _bgColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text("TIME MACHINE", style: GoogleFonts.oswald(letterSpacing: 2, color: _inkColor)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.download_rounded, color: _isMidnightMode ? _inkColor : _accentColor),
                            title: Text("Export Backup", style: TextStyle(color: _inkColor)),
                            onTap: () { Navigator.pop(context); _exportBackup(); },
                          ),
                          Divider(color: _borderColor),
                          ListTile(
                            leading: Icon(Icons.upload_file_rounded, color: _isMidnightMode ? _inkColor : _accentColor),
                            title: Text("Restore Backup", style: TextStyle(color: _inkColor)),
                            onTap: () { Navigator.pop(context); _importBackup(); },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: _isSearching
                  ? Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 140.0, bottom: 4.0),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.merriweather(fontSize: 10, letterSpacing: 1, color: _inkColor.withOpacity(0.7)),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Search echoes...",
                    hintStyle: GoogleFonts.merriweather(fontSize: 10, letterSpacing: 1, color: _inkColor.withOpacity(0.3)),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              )
                  : Text("INK & ECHO", style: GoogleFonts.oswald(letterSpacing: 5, color: _isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _boxColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _editingKey != null ? (_isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor) : _borderColor,
                    width: _editingKey != null ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _moods.map((m) => GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedMood = m);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _selectedMood == m ? (_isMidnightMode ? Colors.white.withOpacity(0.1) : _accentColor.withOpacity(0.1)) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _selectedMood == m ? (_isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor) : Colors.transparent),
                                  ),
                                  child: Text(m, style: const TextStyle(fontSize: 22)),
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                        if (_editingKey != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _editingKey = null;
                                _controller.clear();
                                _selectedMood = "🌿";
                              });
                            },
                            child: const Text("CANCEL", style: TextStyle(fontSize: 10, color: Colors.red)),
                          )
                      ],
                    ),
                    Divider(height: 30, color: _borderColor),
                    TextField(
                      controller: _controller,
                      maxLines: null,
                      style: TextStyle(color: _inkColor),
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: _editingKey != null ? "Updating this echo..." : "Write your echo...",
                        hintStyle: TextStyle(color: _inkColor.withOpacity(0.4)),
                        border: InputBorder.none,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: IconButton(
                          onPressed: _saveEntry,
                          icon: Icon(
                              _editingKey != null ? Icons.check_circle_outline : Icons.send_rounded,
                              color: _isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor
                          )
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          _filterMood != null ? "FILTERED BY $_filterMood" : "ALL ECHOES",
                          style: GoogleFonts.oswald(fontSize: 10, letterSpacing: 2, color: Colors.grey)
                      ),
                      if (_filterMood != null)
                        GestureDetector(
                          onTap: () => setState(() => _filterMood = null),
                          child: const Text("CLEAR FILTER", style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.red, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _moods.map((m) {
                        final isSelected = _filterMood == m;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _filterMood = isSelected ? null : m;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? (_isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor) : _boxColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isSelected ? (_isMidnightMode ? const Color(0xFFE6D5BC) : _accentColor) : _borderColor
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(m, style: const TextStyle(fontSize: 14)),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.close, size: 11, color: _isMidnightMode ? Colors.black : Colors.white),
                                ]
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(height: 25, color: _borderColor),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final date = DateTime.parse(filteredKeys[index] as String);
              final Map data = filteredEntries[index] is Map ? filteredEntries[index] : {'text': filteredEntries[index], 'mood': '🌿'};
              final isBeingEdited = _editingKey == filteredKeys[index];

              final AppFont recordFont = AppFont.values.firstWhere(
                    (f) => f.name == data['font'],
                orElse: () => AppFont.merriweather,
              );

              return ListTile(
                onTap: () => _showFullEntry(context, date, data, filteredKeys[index]),
                onLongPress: () => _handleDelete(context, filteredKeys[index]),
                tileColor: isBeingEdited ? (_isMidnightMode ? Colors.white.withOpacity(0.05) : _accentColor.withOpacity(0.05)) : null,
                leading: Text(data['mood'] ?? "🌿", style: const TextStyle(fontSize: 24)),
                title: Text(DateFormat('MMM dd • h:mm a').format(date), style: GoogleFonts.oswald(fontSize: 10, color: Colors.grey)),
                subtitle: Text(
                  data['text'] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _getFont(recordFont, size: 14).copyWith(color: _inkColor.withOpacity(0.8)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 18, color: _isMidnightMode ? const Color(0xFFE6D5BC).withOpacity(0.6) : const Color(0xFFB0A080)),
                      onPressed: () => _loadForEdit(filteredKeys[index], data),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: _isMidnightMode ? Colors.grey : Colors.black26),
                  ],
                ),
              );
            }, childCount: filteredKeys.length),
          ),
          // Elegant, lower-contrast design signature that appears naturally at the bottom of the feed
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // const SizedBox(height: 10),
                  Text(
                    "© 2026 AMAN RAJ. ALL RIGHTS RESERVED.",
                    style: GoogleFonts.oswald(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: _inkColor.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaperPainter extends CustomPainter {
  final PaperStyle style;
  final bool isMidnightMode;
  PaperPainter(this.style, this.isMidnightMode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isMidnightMode ? const Color(0xFF2D2D2D) : const Color(0xFFD6C9A8).withOpacity(0.4)
      ..strokeWidth = 1.0;

    if (style == PaperStyle.dotted) {
      for (double i = 25; i < size.height; i += 25) {
        for (double j = 25; j < size.width; j += 25) {
          canvas.drawCircle(Offset(j, i), 1.2, paint);
        }
      }
    } else if (style == PaperStyle.squared) {
      for (double i = 0; i < size.height; i += 40) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
      for (double i = 0; i < size.width; i += 40) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(PaperPainter old) => old.style != style || old.isMidnightMode != isMidnightMode;
}