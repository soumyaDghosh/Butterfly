import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_point.g.dart';
part 'path_point.freezed.dart';

@freezed
class PathPoint with _$PathPoint {
  const PathPoint._();
  const factory PathPoint(double x, double y, [@Default(1) double pressure]) =
      _PathPoint;

  factory PathPoint.fromOffset(Offset offset, [double pressure = 1]) =>
      PathPoint(offset.dx, offset.dy, pressure);

  factory PathPoint.fromJson(Map<String, dynamic> json) =>
      _$PathPointFromJson(json);

  Offset toOffset() => Offset(x, y);
}