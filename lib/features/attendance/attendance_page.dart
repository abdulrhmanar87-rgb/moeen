import 'package:flutter/material.dart';
import '../../core/storage/app_store.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.store, this.initialSectionId});
  final String? initialSectionId;
  final AppStore store;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String? sectionId;
  String date = '';

  @override
  void initState() {
    super.initState();
    date = _today();
    final initial = widget.initialSectionId;
    sectionId = (initial != null && widget.store.sections.any((s) => s.id == initial))
        ? initial
        : widget.store.currentSectionId;
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final students = sectionId == null ? [] : store.studentsOf(sectionId!);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الحضور والغياب')),
        body: Column(
          children: [
            if (store.sections.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: DropdownButtonFormField<String>(
                  initialValue: sectionId,
                  decoration: const InputDecoration(labelText: 'الشعبة'),
                  items: store.sections.map((s) => DropdownMenuItem(
                    value: s.id, child: Text('${s.gradeName} - ${s.name}'),
                  )).toList(),
                  onChanged: (v) {
                    setState(() => sectionId = v);
                    widget.store.setCurrentSection(v);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(child: Text('التاريخ: $date')),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: DateTime.tryParse(date) ?? DateTime.now(),
                      );
                      if (d != null) {
                        setState(() => date = d.toIso8601String().substring(0, 10));
                      }
                    },
                    child: const Text('اختيار'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('أضف شعبة وطلابًا أولًا.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: students.length,
                      itemBuilder: (_, i) {
                        final s = students[i];
                        final current = store.attendance.where((a) =>
                            a.sectionId == sectionId && a.date == date && a.studentId == s.id).toList();
                        final status = current.isEmpty ? 'حاضر' : current.first.status;
                        return Card(
                          child: ListTile(
                            title: Text(s.name),
                            subtitle: Text('الحالة: $status'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                await store.setAttendance(
                                  sectionId: sectionId!,
                                  date: date,
                                  studentId: s.id,
                                  status: v,
                                );
                                setState(() {});
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'حاضر', child: Text('حاضر')),
                                PopupMenuItem(value: 'غائب', child: Text('غائب')),
                                PopupMenuItem(value: 'مجاز', child: Text('مجاز')),
                              ],
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
