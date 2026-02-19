import 'package:flutter/cupertino.dart';

class DetectionTile extends StatelessWidget {
  final String title, conf, time, severity;

  const DetectionTile({
    super.key,
    required this.title,
    required this.conf,
    required this.time,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  (severity == "High"
                          ? CupertinoColors.systemRed
                          : CupertinoColors.systemYellow)
                      .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: severity == "High"
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemYellow,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  "$time • Conf: $conf",
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.systemGrey,
            size: 16,
          ),
        ],
      ),
    );
  }
}
