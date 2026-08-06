import 'package:flutter/material.dart';

class PolicySection {
  final String title;
  final String body;
  const PolicySection({required this.title, required this.body});
}

class PolicyScreen extends StatefulWidget {
  final String title;
  final String version;
  final String revisedDate;
  final String intro;
  final List<PolicySection> sections;

  const PolicyScreen({
    super.key,
    required this.title,
    required this.version,
    required this.revisedDate,
    required this.intro,
    required this.sections,
  });

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  bool _expanded = false;
  late final List<GlobalKey> _sectionKeys;

  @override
  void initState() {
    super.initState();
    _sectionKeys = List.generate(widget.sections.length, (_) => GlobalKey());
  }

  void _jumpTo(int index) {
    if (!_expanded) setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.title} ${widget.version}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? '내용 접기' : '내용보기'),
              ),
            ),
            const SizedBox(height: 20),
            if (_expanded) ...[
              Text(
                  '${widget.title} (${widget.version}) ${widget.revisedDate} 개정',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(widget.intro, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 20),
              Text('아래 항목을 선택 시 해당 내용으로 이동합니다.',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              ...List.generate(
                widget.sections.length,
                (i) => InkWell(
                  onTap: () => _jumpTo(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('${i + 1}. ${widget.sections[i].title}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
              ),
              const Divider(height: 32),
              ...List.generate(
                widget.sections.length,
                (i) => Padding(
                  key: _sectionKeys[i],
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ${widget.sections[i].title}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(widget.sections[i].body,
                          style: const TextStyle(height: 1.6)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
