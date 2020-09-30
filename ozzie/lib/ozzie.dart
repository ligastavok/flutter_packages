library ozzie;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:meta/meta.dart';
import 'package:ozzie/models/test_log_entry.dart';

import 'models/test_log_entry.dart';
import 'reporter.dart';
import 'zip_generator.dart';

const rootFolderName = "ozzie";

/// [Ozzie] is the class responsible for taking screenshots and generating
/// an HTML report when running your integrationt tests on Flutter.
class Ozzie {
  final FlutterDriver driver;
  final String groupName;
  static const String undefindedSteps = "Не выделенные в тест шаги";
  String currentTestName = undefindedSteps;
  final LinkedHashMap<String, List<TestLogEntry>> testLogEntriesMap;
  final bool shouldTakeScreenshots;
  var _doesGroupFolderNeedToBeDeleted = true;

  Ozzie._internal(
    this.driver, {
    @required this.groupName,
    @required this.testLogEntriesMap,
    @required this.shouldTakeScreenshots,
  }) : assert(driver != null);

  /// Build an [Ozzie] object with the given [FlutterDriver]. If a `groupName`
  /// is given, it will be used to group your screenshots in the HTML report;
  /// otherwise, they will be placed under a "default" group.
  /// This method is intended to be called in your tests `setUp`, immediately
  /// after a [FlutterDriver] object has been built.
  ///
  /// Usage:
  ///
  /// ```
  /// Ozzie.initWith(driver) -> will group the screenshots taken under "default"
  /// Ozzie.initWith(driver, 'my_report') -> will group the screenshots taken under "my_report"
  /// ```
  factory Ozzie.initWith(
    FlutterDriver driver, {
    String groupName = "default",
    bool shouldTakeScreenshots = true,
  }) =>
      Ozzie._internal(
        driver,
        groupName: groupName,
        testLogEntriesMap: LinkedHashMap<String, List<TestLogEntry>>
            .of(<String, List<TestLogEntry>>{ undefindedSteps : List<TestLogEntry>()}),
        shouldTakeScreenshots: shouldTakeScreenshots,
      );

  void saveLogEntry(String status, String message) {
    testLogEntriesMap[currentTestName]
        .add(TestLogEntry(status: status, message: message));
  }

  /// It takes a an PNG screenshot of the given state of the application when
  /// being called. The name of the screenshot will be the given `screenshotName`
  /// prefixed by the timestamp of that moment, and suffixed by `.png`.
  /// It will be stored in a folder whose name will be the given `groupName`
  /// when calling `Ozzie.initWith`.
  Future takeScreenshot(String screenshotName) async {
    if (shouldTakeScreenshots) {
      if (_doesGroupFolderNeedToBeDeleted) {
        await _deleteExistingGroupFolder();
        _doesGroupFolderNeedToBeDeleted = false;
      }
      final filePath = _filePath(screenshotName);
      final file = await File(filePath).create(recursive: true);
      final pixels = await driver.screenshot();
      await file.writeAsBytes(pixels);
      print('Ozzie took screenshot: $filePath');
    }
  }

  /// This is the method that will generate the HTML report with all the
  /// screenshots taken during integration tests.
  /// This is method is intended to be called in your tests `tearDown`,
  /// immediately after closing the given [FlutterDriver].
  Future generateHtmlReport() async {
    if (!await Directory(_groupFolderName).exists()) {
      await Directory(_groupFolderName).create(recursive: true);
    }
    File('ozzie/$groupName/test_group.json')
      ..createSync(recursive: true)
      ..writeAsString(json
          .encode(testLogEntriesMap
                    .keys.toList()));
    testLogEntriesMap.forEach((key, value) {
      _serializeLogs(key, value);
    });
    await _generateZipFiles();
    final reporter = Reporter();
    await reporter.generateHtmlReport(
      rootFolderName: rootFolderName,
      groupName: groupName,
    );
  }

  /// This method will wrap your `body` into the the `traceAction`
  /// method of the `FlutterDriver` instance, and will generate
  /// both the the timeline report and the summary report with the
  /// given `reportName` into your `groupName` folder, under a new
  /// folder named "profiling"
  Future<void> profilePerformance(
      String reportName,
      Future<dynamic> body(),
      ) async {
    final timeline = await driver.traceAction(() async => await body());
    final summary = TimelineSummary.summarize(timeline);
    await summary.writeSummaryToFile(
      reportName,
      destinationDirectory: 'ozzie/$groupName/profiling',
      pretty: true,
    );
    await summary.writeTimelineToFile(
      reportName,
      destinationDirectory: 'ozzie/$groupName/profiling',
      pretty: true,
    );
  }

  Future<void> test(
      String testName,
      Future<dynamic> body(),
      ) async {

    testLogEntriesMap[testName] = List<TestLogEntry>();

    currentTestName = testName;
    await body();
    currentTestName = undefindedSteps;
  }

  void _serializeLogs(String testName, List<TestLogEntry> testLogEntries) {
    File('ozzie/$groupName/logs_$testName.json')
      ..createSync(recursive: true)
      ..writeAsString(json.encode(testLogEntries));
  }

  Future _generateZipFiles() async {
    final zipGenerator = ZipGenerator();
    await zipGenerator.generateZipWithAllGroups();
    await zipGenerator.generateZipInFolder(
      groupFolderName: _groupFolderName,
      groupName: groupName,
    );
  }

  Future _deleteExistingGroupFolder() async {
    final groupFolder = Directory(_groupFolderName);
    if (await groupFolder.exists()) {
      await groupFolder.delete(recursive: true);
      print('Ozzie has deleted the "$groupName" folder');
    }
  }

  String get _groupFolderName => '$rootFolderName/$groupName';

  String get _timestamp => DateTime.now().toIso8601String().replaceAll(':', '-');

  String _fileName(String screenshotName) => '$_timestamp-${screenshotName.replaceAll(':', ' ')}.png';

  String _filePath(String screenshotName) {
    final fileName = _fileName(screenshotName);
    return '$_groupFolderName/$fileName';
  }
}
