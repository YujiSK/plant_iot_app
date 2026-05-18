import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const MaterialApp(home: MissingConfigPage()));
    return;
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const PlantIoTApp());
}

class MissingConfigPage extends StatelessWidget {
  const MissingConfigPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define.'),
        ),
      );
}

class PlantIoTApp extends StatelessWidget {
  const PlantIoTApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Plant IoT',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7F2),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.zero,
          ),
        ),
        home: const PlantHomePage(),
      );
}

class PlantHomePage extends StatefulWidget {
  const PlantHomePage({super.key});

  @override
  State<PlantHomePage> createState() => _PlantHomePageState();
}

class _PlantHomePageState extends State<PlantHomePage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? latest;
  List<Map<String, dynamic>> careLogs = const [];
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final latestRow = await supabase
          .from('sensor_logs')
          .select(
              'id, temperature, humidity, pressure, vitality_score, message, created_at')
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      final logs = await supabase
          .from('care_logs')
          .select('id, action_type, note, vitality_score, message, created_at')
          .order('created_at', ascending: false)
          .limit(20);
      setState(() {
        latest = Map<String, dynamic>.from(latestRow);
        careLogs = List<Map<String, dynamic>>.from(logs);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> recordAction(String actionType, {String? note}) async {
    final row = latest;
    if (row == null || saving) return;
    setState(() => saving = true);
    try {
      await supabase.from('care_logs').insert({
        'action_type': actionType,
        'note': note,
        'sensor_log_id': row['id'],
        'temperature': row['temperature'],
        'humidity': row['humidity'],
        'pressure': row['pressure'],
        'vitality_score': row['vitality_score'],
        'message': row['message'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${actionLabel(actionType)}を記録しました')),
      );
      await loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('記録に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> showNoteDialog(String actionType) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${actionLabel(actionType)}のメモ'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '対応内容や気づいたこと',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('記録')),
        ],
      ),
    );
    if (note != null) {
      await recordAction(actionType, note: note.isEmpty ? null : note);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('植物管理'),
          actions: [
            IconButton(
                onPressed: loading ? null : loadData,
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: buildBody(),
      );

  Widget buildBody() {
    if (loading && latest == null)
      return const Center(child: CircularProgressIndicator());
    if (error != null && latest == null) {
      return Padding(padding: const EdgeInsets.all(24), child: Text(error!));
    }
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          StateCard(row: latest!),
          const SizedBox(height: 12),
          ActionPanel(
              saving: saving, onQuick: recordAction, onMemo: showNoteDialog),
          const SizedBox(height: 12),
          CareLogList(logs: careLogs),
        ],
      ),
    );
  }
}

class StateCard extends StatelessWidget {
  const StateCard({super.key, required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final score = asInt(row['vitality_score']);
    final color = statusColor(score);
    final status = statusLabel(score);
    final recommendation =
        getRecommendation(score, row['message']?.toString() ?? '');
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.12), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('現在の状態',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('植物の判断支援',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  Chip(
                    label: Text(status),
                    backgroundColor: color.withValues(alpha: 0.14),
                    side: BorderSide(color: color.withValues(alpha: 0.30)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                row['message']?.toString() ?? '状態不明',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score.toString(),
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('vitality_score',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('推奨対応', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                recommendation,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Metric(label: '温度', value: '${fmt(row['temperature'])} ℃'),
                  Metric(label: '湿度', value: '${fmt(row['humidity'])} %'),
                  Metric(label: '気圧', value: '${fmt(row['pressure'])} hPa'),
                ],
              ),
              const SizedBox(height: 8),
              Text('最終更新 ${formatTime(row['created_at'])}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 118,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class ActionPanel extends StatelessWidget {
  const ActionPanel(
      {super.key,
      required this.saving,
      required this.onQuick,
      required this.onMemo});
  final bool saving;
  final Future<void> Function(String actionType, {String? note}) onQuick;
  final Future<void> Function(String actionType) onMemo;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('対応を記録', style: Theme.of(context).textTheme.titleMedium),
                  if (saving)
                    Text(
                      '記録中...',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 700 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                    children: [
                      ActionCard(
                        icon: Icons.water_drop,
                        title: '水やりを記録',
                        subtitle: '乾燥状態への対応',
                        enabled: !saving,
                        onTap: () => onMemo('watered'),
                      ),
                      ActionCard(
                        icon: Icons.location_on_outlined,
                        title: '場所変更を記録',
                        subtitle: '日当たり・環境変更',
                        enabled: !saving,
                        onTap: () => onMemo('moved'),
                      ),
                      ActionCard(
                        icon: Icons.check_circle_outline,
                        title: '確認のみ',
                        subtitle: '状態を見て記録',
                        enabled: !saving,
                        onTap: () => onQuick('checked'),
                      ),
                      ActionCard(
                        icon: Icons.note_alt_outlined,
                        title: 'メモ',
                        subtitle: '自由記述で補足',
                        enabled: !saving,
                        onTap: () => onMemo('memo'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
          color: enabled
              ? colorScheme.surface
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.primary, size: 18),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style:
                  Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class CareLogList extends StatelessWidget {
  const CareLogList({super.key, required this.logs});
  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('対応履歴', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              if (logs.isEmpty) ...[
                Text('まだ記録がありません',
                    style: Theme.of(context).textTheme.bodySmall),
              ] else ...[
                ...logs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatTime(log['created_at']),
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                              ),
                              Chip(
                                label: Text(actionLabel(
                                    log['action_type']?.toString() ?? '')),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'score: ${log['vitality_score'] ?? '--'} / ${log['message']?.toString() ?? '状態不明'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if ((log['note']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(log['note'].toString(),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '温度 ${fmt(log['temperature'])}℃  湿度 ${fmt(log['humidity'])}%  気圧 ${fmt(log['pressure'])} hPa',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

String actionLabel(String actionType) => switch (actionType) {
      'watered' => '水やり',
      'moved' => '場所変更',
      'checked' => '確認のみ',
      'memo' => 'メモ',
      _ => actionType,
    };

String statusLabel(int score) {
  if (score >= 80) return '良好';
  if (score >= 60) return '注意';
  return '要対応';
}

Color statusColor(int score) {
  if (score >= 80) return Colors.green.shade700;
  if (score >= 60) return Colors.orange.shade800;
  return Colors.red.shade700;
}

String getRecommendation(int score, String message) {
  if (score < 60) {
    if (message.contains('乾燥')) {
      return '水やりを検討してください';
    }
    return '植物の状態を確認し、必要な対応を記録してください';
  }

  if (score < 80) {
    return '状態を確認し、経過を観察してください';
  }

  return '現在は良好です。通常の管理を継続してください';
}

int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String fmt(dynamic value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  return number == null ? '--' : number.toStringAsFixed(1);
}

String formatTime(dynamic value) {
  if (value == null) return '--';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  final jst =
      parsed.isUtc ? parsed.add(const Duration(hours: 9)) : parsed.toLocal();
  return '${DateFormat('yyyy/MM/dd HH:mm').format(jst)} JST';
}
