import 'package:butterfly/models/tools/type.dart';
import 'package:flutter/material.dart';
import 'package:butterfly/pad/bloc/document_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class EditTool extends Tool {
  @override
  IconData get icon => PhosphorIcons.penLight;
  @override
  IconData get activeIcon => PhosphorIcons.penFill;

  @override
  ToolType get type => ToolType.edit;

  @override
  String get name => "Edit";

  @override
  List<Widget> buildOptions({required BuildContext context, required DocumentLoadSuccess state}) {
    return [
      IconButton(icon: Icon(PhosphorIcons.penLight), tooltip: "Pencil", onPressed: () {}),
      IconButton(icon: Icon(PhosphorIcons.markerCircleLight), tooltip: "Marker", onPressed: () {})
    ];
  }
}