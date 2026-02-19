import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      // List files ending with .csv
      final files = directory.listSync().where((entity) {
        return entity.path.endsWith('.csv');
      }).toList();

      // Sort by modification time (newest first)
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading files: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareFile(String path) async {
    final result = await Share.shareXFiles([
      XFile(path),
    ], text: 'Sensor Data CSV');
    if (result.status == ShareResultStatus.success) {
      print('Shared successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text("History Logs"),
            backgroundColor: Color(0xFF0A0A0B),
            border: null,
          ),
          CupertinoSliverRefreshControl(onRefresh: _loadFiles),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_files.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  "No recordings found",
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final file = _files[index];
                  final stat = file.statSync();
                  final filename = file.path.split('/').last.split('\\').last;
                  final sizeKb = (stat.size / 1024).toStringAsFixed(1);

                  return GestureDetector(
                    onTap: () => _shareFile(file.path),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.doc_text_fill,
                            color: CupertinoColors.activeGreen,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filename,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: CupertinoColors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${stat.modified.toString().substring(0, 16)} • ${sizeKb} KB",
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.share,
                            color: CupertinoColors.activeBlue,
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: _files.length),
              ),
            ),
        ],
      ),
    );
  }
}
