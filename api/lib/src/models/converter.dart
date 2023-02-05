import 'dart:convert';
import 'dart:typed_data';

import 'document.dart';
import 'template.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'pack.dart';
import 'palette.dart';

class DocumentJsonConverter extends JsonConverter<AppDocument, Map> {
  const DocumentJsonConverter();

  @override
  AppDocument fromJson(Map json) {
    final fileVersion = json['fileVersion'] as int?;
    if (fileVersion != null && fileVersion >= 0) {
      if (fileVersion < 4) {
        json['palettes'] = List.from(
            Map<String, dynamic>.from(json['palettes'] ?? [])
                .entries
                .map<ColorPalette>((e) => ColorPalette(
                    colors: List<int>.from(e.value).toList(), name: e.key))
                .map((e) => e.toJson())
                .toList());
      }
      if (fileVersion < 5) {
        json['painters'] = List.from((json['painters'] as List).map((e) {
          var map = Map<String, dynamic>.from(e);
          if (map['type'] == 'path-eraser') {
            map['type'] = 'pathEraser';
          }
          return map;
        })).where((map) => map['type'] != 'image').toList();
        json['content'] = List.from((json['content'] as List).map((e) {
          var map = Map<String, dynamic>.from(e);
          if (map['type'] == 'paint') {
            map['type'] = 'pen';
          }
          return map;
        })).toList();
        json['background'] = Map<String, dynamic>.from(json['background'] ?? {})
          ..['type'] = 'box';
      }
      if (fileVersion < 6) {
        json['painters'] = [
          {'type': 'hand', ...json['handProperty']},
          {'type': 'undo'},
          {'type': 'redo'},
          ...(json['painters'] as List).map((e) {
            var map = Map<String, dynamic>.from(e);
            if (['svg', 'image'].contains(map['type'])) {
              final constraints = map['constraints'];
              if (constraints is Map) {
                final current = Map<String, dynamic>.from(constraints);
                if (current['type'] == 'scaled') {
                  current['scaleX'] = map['scale'];
                  current['scaleY'] = map['scale'];
                }
                map['constraints'] = current;
              }
            }
            return map;
          }),
        ];
        if (json['background']?['type'] == null) {
          json['background'] = {'type': 'empty'};
        }
      }
      if (fileVersion < 7) {
        json['content'] = List.from(json['content'] as List).where((e) {
          return e['type'] != 'eraser';
        }).toList();
      }
    }
    return AppDocument.fromJson(Map<String, dynamic>.from(json));
  }

  @override
  Map<String, dynamic> toJson(AppDocument object) {
    return {
      ...object.toJson(),
      'fileVersion': kFileVersion,
      'type': 'document',
    };
  }
}

class TemplateJsonConverter extends JsonConverter<DocumentTemplate, Map> {
  const TemplateJsonConverter();

  @override
  DocumentTemplate fromJson(Map json) {
    return DocumentTemplate.fromJson(Map<String, dynamic>.from(json));
  }

  @override
  Map<String, dynamic> toJson(DocumentTemplate object) {
    return {
      ...object.toJson(),
      'fileVersion': kFileVersion,
      'type': 'template',
    };
  }
}

class PackJsonConverter extends JsonConverter<ButterflyPack, Map> {
  const PackJsonConverter();
  @override
  ButterflyPack fromJson(Map json) {
    return ButterflyPack.fromJson(Map<String, dynamic>.from(json));
  }

  @override
  Map<String, dynamic> toJson(ButterflyPack object) {
    return {
      ...object.toJson(),
      'fileVersion': kFileVersion,
      'type': 'pack',
    };
  }
}

class OffsetJsonConverter extends JsonConverter<Offset, Map> {
  const OffsetJsonConverter();

  @override
  Offset fromJson(Map json) {
    double x = 0, y = 0;
    final xJson = json['x'];
    final yJson = json['y'];
    if (xJson is num) {
      x = xJson.toDouble();
    } else if (xJson is String) {
      x = double.parse(xJson);
    }
    if (yJson is num) {
      y = yJson.toDouble();
    } else if (yJson is String) {
      y = double.parse(yJson);
    }

    return Offset(x, y);
  }

  @override
  Map toJson(Offset object) => {'x': object.dx, 'y': object.dy};
}

class Uint8ListJsonConverter extends JsonConverter<Uint8List, String> {
  const Uint8ListJsonConverter();

  @override
  Uint8List fromJson(String json) => Uint8List.fromList(base64.decode(json));
  @override
  String toJson(Uint8List object) => base64.encode(object.toList());
}

class DateTimeJsonConverter extends JsonConverter<DateTime, int> {
  const DateTimeJsonConverter();
  @override
  DateTime fromJson(int json) => DateTime.fromMillisecondsSinceEpoch(json);
  @override
  int toJson(DateTime object) => object.millisecondsSinceEpoch;
}