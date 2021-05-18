import 'dart:ui';
import 'video_player_platform_interface.dart';

///
class AnalyticVideoEvent extends VideoEvent {
  ///
  AnalyticVideoEvent({
    required eventType,
    Duration? duration,
    Size? size,
    List<DurationRange>? buffered,
    this.analyticsDescription,
  }) : super(
            eventType: eventType,
            duration: duration,
            size: size,
            buffered: buffered);

  ///
  final String? analyticsDescription;
}
