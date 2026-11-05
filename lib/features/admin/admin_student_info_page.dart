import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_name_utils.dart';
import '../../core/utils/arabic_numbers.dart';
import '../../models/student.dart';

/// بيانات السجل الوسطي لكل طالب: رقم القيد، المواليد، سنوات الرسوب.
class AdminStudentInfoPage extends StatefulWidget {
  const AdminStudentInfoPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AdminStudentInfoPage> createState() => _AdminStudentInfoPageState();
}

class _AdminStudentInfoPageState extends State<AdminStudentInfoPage> {
  AppStore get store => widget.store;
  late String? sectionId = store.currentSectionId;
  Timer? _saveTimer;

  /// حفظ تلقائي بعد التوقف عن الكتابة.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () => store.saveAll());
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      store.saveAll();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = sectionId == null ? <Student>[] : store.studentsOf(sectionId!);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('بيانات السجل')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: DropdownButtonFormField<String>(
              initialValue: sectionId,
              decoration: const InputDecoration(labelText: 'الشعبة'),
              items: [
                for (final s in store.sections)
                  DropdownMenuItem(value: s.id, child: Text('${s.gradeName} - ${s.name}')),
              ],
              onChanged: (v) {
                setState(() => sectionId = v);
                store.setCurrentSection(v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              'يُحفظ تلقائياً. الاسم يُقسَّم في السجل إلى: الطالب | الأب | الجد | أب الجد واللقب.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('لا يوجد طلاب في هذه الشعبة. أضفهم من «الطلاب».'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _row(i + 1, students[i]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _row(int n, Student s) {
    final parts = ArabicNameUtils.recordNameColumns(s.name);
    Widget field(String label, String value, void Function(String) onChanged, {double width = 120, bool number = false}) =>
        SizedBox(
          width: width,
          child: TextFormField(
            initialValue: value,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            inputFormatters: number ? const [EnglishDigitsFormatter()] : null,
            decoration: InputDecoration(isDense: true, labelText: label),
            onChanged: (v) {
              onChanged(v.trim());
              _scheduleSave();
            },
          ),
        );
    return Card(
      key: ObjectKey(s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(width: 28, child: Text('$n', style: TextStyle(color: Colors.grey.shade600))),
            Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 28, top: 2, bottom: 8),
            child: Text(
              parts.map((p) => p.isEmpty ? '—' : p).join('  |  '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Wrap(spacing: 10, runSpacing: 10, children: [
            field('رقم القيد', s.regNo, (v) => s.regNo = ArabicNumbers.toEnglish(v), number: true),
            field('المواليد', s.birthDate, (v) => s.birthDate = ArabicNumbers.toEnglish(v), width: 140),
            field('سنوات الرسوب', s.failedYears, (v) => s.failedYears = ArabicNumbers.toEnglish(v), width: 120),
          ]),
        ]),
      ),
    );
  }
}
