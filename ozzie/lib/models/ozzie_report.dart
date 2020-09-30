import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:ozzie/models/test_log_entry.dart';

import 'models.dart';

/// Model than encapsulates different metrics for a feature report
class OzzieReport {
  final String reportName;
  final LinkedHashMap<String, List<TestLogEntry>> testLogEntriesMap;
  final List<String> screenshots;
  final List<PerformanceReport> performanceReports;
  final PerformanceScore performanceScore;

  OzzieReport({
    @required this.reportName,
    @required this.testLogEntriesMap,
    @required this.screenshots,
    @required this.performanceReports,
    @required this.performanceScore,
  });
}
