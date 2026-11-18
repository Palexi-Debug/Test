import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/substitutions/teacher_lookup.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentCourseView extends StatefulWidget {
  final List<StudentStudyGroup> studyGroup;

  const StudentCourseView({super.key, required this.studyGroup});

  @override
  State<StudentCourseView> createState() => _StudentCourseViewState();
}

class _StudentCourseViewState extends State<StudentCourseView> {
  String _query = '';
  bool _onlyWithExams = false;

  List<StudentStudyGroupBySemester> _groupBySemester() {
    final q = _query.trim().toLowerCase();
    final Map<String, List<StudentStudyGroup>> grouped = {};
    for (final group in widget.studyGroup) {
      if (_onlyWithExams && group.exams.isEmpty) continue;
      if (q.isNotEmpty) {
        final hay = [
          group.courseName,
          group.courseSysId,
          for (final t in group.teachers) '${t.krz} ${t.firstName} ${t.lastName}',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) continue;
      }
      grouped.putIfAbsent(group.semester, () => []).add(group);
    }
    return grouped.entries
        .map(
          (e) => StudentStudyGroupBySemester(studyGroup: e.value, semester: e.key),
        )
        .toList();
  }

  /// "Arbeitslehre 09R2" -> ("Arbeitslehre", "09R2")
  (String, String?) _splitName(String full) {
    final m = RegExp(r'^(.*?)\s+(\d{1,2}[A-Za-z0-9]*)$').firstMatch(full.trim());
    if (m == null) return (full.trim(), null);
    return (m.group(1)!.trim(), m.group(2));
  }

  String _cleanId(String id) =>
      id.trim().replaceAll(RegExp(r'\s*[-–]\s*$'), '').trim();

  int _daysUntil(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).difference(today).inDays;
  }

  String _daysLabel(int days) {
    if (days < 0) return 'vorbei';
    if (days == 0) return 'heute';
    if (days == 1) return 'morgen';
    return 'in $days Tagen';
  }

  Widget _examRow(
    BuildContext context,
    StudentStudyGroupExam e, {
    required bool isNext,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final days = _daysUntil(e.date);
    final past = days < 0;
    final bg = isNext
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    final fg = isNext ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;
    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              past ? Icons.check_circle_outline : Icons.event_rounded,
              size: 18,
              color: fg,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.type,
                style: TextStyle(
                  color: fg,
                  fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('EEE, dd.MM.yyyy').format(e.date),
                  style: TextStyle(color: fg, fontSize: 13),
                ),
                Text(
                  _daysLabel(days),
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseCard(BuildContext context, StudentStudyGroup g) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (name, cls) = _splitName(g.courseName);
    final id = _cleanId(g.courseSysId);
    final exams = [...g.exams]..sort((a, b) => a.date.compareTo(b.date));
    StudentStudyGroupExam? next;
    for (final e in exams) {
      if (_daysUntil(e.date) >= 0) {
        next = e;
        break;
      }
    }
    final initials = name.isEmpty
        ? '?'
        : name.substring(0, name.length >= 2 ? 2 : 1);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(
                    initials,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: text.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cls != null || id.isNotEmpty)
                        Text(
                          [if (cls != null) cls, if (id.isNotEmpty) id].join(' · '),
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (g.teachers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  for (final t in g.teachers) TeacherChip(teacher: t),
                ],
              ),
            ],
            for (final e in exams)
              _examRow(context, e, isNext: identical(e, next)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grouped = _groupBySemester();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: SearchBar(
                hintText: 'Fach oder Lehrer suchen',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Wrap(
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.event_rounded, size: 18),
                    label: const Text('Nur mit Terminen'),
                    selected: _onlyWithExams,
                    onSelected: (v) => setState(() => _onlyWithExams = v),
                  ),
                ],
              ),
            ),
            if (grouped.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Keine Lerngruppen gefunden.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            for (final sem in grouped) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(
                  sem.semester,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              for (final g in sem.studyGroup) _courseCard(context, g),
            ],
          ],
        ),
      ),
    );
  }
}

class TeacherChip extends StatefulWidget {
  final StudentStudyGroupTeacher teacher;

  const TeacherChip({super.key, required this.teacher});

  @override
  State<TeacherChip> createState() => _TeacherChipState();
}

class _TeacherChipState extends State<TeacherChip> {
  String? _resolvedName;

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;
    if (t.lastName.isEmpty && t.krz.isNotEmpty) {
      teacherFullName(context, t.krz).then((n) {
        if (mounted && n != null) setState(() => _resolvedName = n);
      });
    }
  }

  String get _label {
    final t = widget.teacher;
    final name = t.lastName.isNotEmpty
        ? (t.firstName.isEmpty ? t.lastName : '${t.lastName}, ${t.firstName}')
        : (_resolvedName ?? '');
    return name.isEmpty ? t.krz : '$name (${t.krz})';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.teacher.email == null) return;

        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          path: widget.teacher.email,
        );
        safeLaunchUrl(
          emailLaunchUri,
          context: context,
          mode: LaunchMode.externalApplication,
        );
      },
      behavior: HitTestBehavior.deferToChild,
      child: Chip(
        visualDensity: VisualDensity.compact,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4.0,
          children: [
            Icon(Icons.person, size: 16),
            Flexible(child: Text(_label, overflow: TextOverflow.ellipsis)),
            if (widget.teacher.email != null)
              Icon(
                Icons.email,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class StudentStudyGroupBySemester {
  List<StudentStudyGroup> studyGroup;
  String semester;

  StudentStudyGroupBySemester({
    required this.studyGroup,
    required this.semester,
  });
}
