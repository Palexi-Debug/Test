import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import '../../models/study_groups.dart';
import '../applet_context.dart';
import '../applet_parser.dart';
import '../definition.dart';

class StudyGroupsStudentParser extends AppletParser<StudentStudyGroups> {
  StudyGroupsStudentParser(
    AppletContext ctx, {
    Future<bool> Function()? isConnected,
  }) : super(
         ctx,
         Applets.studyGroups,
         isConnected:
             isConnected ?? () => ctx.session.connectionChecker.connected,
       );

  @override
  Future<StudentStudyGroups> getHome() async {
    Response response = await ctx.session.dio.get(
      'https://start.schulportal.hessen.de/lerngruppen.php',
    );

    Document document = parse(response.data);

    Element? courses = document.getElementById('LGs');
    Element? exams = document.getElementById('klausuren');

    List<StudentStudyGroupExam> studyGroupExams = [];
    if (exams != null) {
      List<String> examTableHead = [];
      exams.querySelectorAll('thead tr th').forEach((element) {
        examTableHead.add(element.text.trim());
      });

      for (final Element examTableRow
          in exams
              .querySelectorAll('tbody tr')
              .where((row) => row.attributes['data-type'] == 'klausur')) {
        final String? courseId = examTableRow.attributes['data-lerngruppe'];
        final String? id = examTableRow.attributes['data-id'];
        if (courseId == null || id == null) continue;

        Element? elementInRow(String key) {
          int index = examTableHead.indexOf(key);
          if (index == -1) return null;
          if (index >= examTableRow.children.length) return null;
          return examTableRow.children[index];
        }

        RegExp dateRegex = RegExp(r'\d{2}\.\d{2}\.\d{4}');
        final String? rawDate =
            dateRegex.stringMatch(elementInRow('Datum')?.text.trim() ?? '');
        if (rawDate == null) continue;
        final String dateString = rawDate.split('.').reversed.join('-');
        elementInRow('Kurs')?.querySelector('small')?.innerHtml = '';
        studyGroupExams.add(
          StudentStudyGroupExam(
            id: id,
            courseId: courseId,
            courseName: elementInRow('Kurs')?.text.trim() ?? "Unbekannt",
            date: DateTime.parse(dateString),
            type: elementInRow('Art')?.text.trim() ?? "Unbekannt",
            durationLabel: elementInRow('Dauer')?.text.trim(),
            hoursOfDay: elementInRow('Stunden')?.text.trim(),
          ),
        );
      }
    }

    List<StudentStudyGroup> studyGroups = [];
    if (courses != null) {
      List<String> courseTableHead = [];
      courses.querySelectorAll('thead tr th').forEach((element) {
        courseTableHead.add(element.text.trim());
      });

      for (final Element courseTableRow in courses.querySelectorAll(
        'tbody tr',
      )) {
        final String? id = courseTableRow.attributes['data-id'];
        if (id == null) continue;

        Element? elementInRow(String key) {
          int index = courseTableHead.indexOf(key);
          if (index == -1) return null;
          if (index >= courseTableRow.children.length) return null;
          return courseTableRow.children[index];
        }

        List<StudentStudyGroupTeacher> teachers = [];
        final teacherElement = elementInRow('Lehrkraft');
        if (teacherElement != null) {
          for (final Element teacherButton in teacherElement.children) {
            final krz = teacherButton
                    .querySelector('button.btn.btn-primary.dropdown-toggle')
                    ?.text
                    .trim() ??
                '';
            // Leere/versteckte Elemente ohne Kürzel ergeben sonst ", ()".
            if (krz.isEmpty) continue;

            String name = '';
            String? mail;
            for (final a in teacherButton.querySelectorAll(
              'ul.dropdown-menu a',
            )) {
              final t = a.text.trim();
              if (t.isEmpty) continue;
              final isMail =
                  t.contains('[AT]') || t.contains('@') || t.contains('[DOT]');
              if (isMail) {
                mail = t
                    .replaceAll(RegExp(r'\s*\[AT\]\s*'), '@')
                    .replaceAll(RegExp(r'\s*\[DOT\]\s*'), '.')
                    .replaceAll(' ', '');
              } else if (name.isEmpty) {
                name = t;
              }
            }
            // Name auch aus Überschrift/title versuchen
            if (name.isEmpty) {
              name = teacherButton
                      .querySelector('ul.dropdown-menu .dropdown-header')
                      ?.text
                      .trim() ??
                  teacherButton.attributes['title']?.trim() ??
                  '';
            }
            final nameSplit = name.split(',');
            teachers.add(
              StudentStudyGroupTeacher(
                firstName: nameSplit.length > 1 ? nameSplit[1].trim() : '',
                lastName: nameSplit.isNotEmpty ? nameSplit[0].trim() : '',
                krz: krz,
                email: mail,
              ),
            );
          }
        }

        final String sysId =
            elementInRow('Kursname')?.querySelector('small')?.text.trim() ??
                "()";
        elementInRow('Kursname')?.querySelector('small')?.innerHtml = '';
        studyGroups.add(
          StudentStudyGroup(
            id: id,
            semester: elementInRow('Halbjahr')?.text.trim() ?? "Fehler",
            courseName: elementInRow('Kursname')?.text.trim() ?? "Fehler",
            courseSysId: sysId.length >= 2
                ? sysId.substring(1, sysId.length - 1)
                : sysId,
            teachers: teachers,
            exams: studyGroupExams
                .where((exam) => exam.courseId == id)
                .toList(),
          ),
        );
      }
    }

    return StudentStudyGroups(groups: studyGroups, exams: studyGroupExams);
  }
}
