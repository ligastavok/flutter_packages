import 'package:meta/meta.dart';

class TestLogEntry {
  final String status;
  final String message;

  TestLogEntry({@required this.status, @required this.message});

  factory TestLogEntry.fromJson(parsedJson){
    return TestLogEntry(
      status: parsedJson['status'],
      message : parsedJson['message'],
    );
  }

  Map toJson() => {
    'status': status,
    'message': message,
  };
}
