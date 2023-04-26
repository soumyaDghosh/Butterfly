import 'package:freezed_annotation/freezed_annotation.dart';

import 'animation.dart';
import 'area.dart';
import 'background.dart';
import 'element.dart';
import 'export.dart';
import 'waypoint.dart';

part 'page.g.dart';
part 'page.freezed.dart';

@freezed
class DocumentPage with _$DocumentPage {
  const factory DocumentPage({
    @Default([]) List<AnimationTrack> animations,
    @Default([]) List<PadElement> content,
    @Default(Background.empty()) Background background,
    @Default([]) List<Waypoint> waypoints,
    @Default([]) List<Area> areas,
    @Default([]) List<ExportPreset> exportPresets,
  }) = _DocumentPage;

  factory DocumentPage.fromJson(Map<String, dynamic> json) =>
      _$DocumentPageFromJson(json);
}
