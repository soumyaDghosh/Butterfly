part of '../selection.dart';

class PathPropertySelection<T extends PathProperty> with PropertySelection<T> {
  PathPropertySelection();

  @override
  List<Widget> build(
    BuildContext context,
    T property,
    ValueChanged<T> onChanged,
  ) =>
      [
        ExactSlider(
            header: Text(AppLocalizations.of(context)!.strokeWidth),
            value: property.strokeWidth,
            min: 0,
            max: 70,
            defaultValue: 25,
            onChangeEnd: (value) => onChanged(
                (property as dynamic).copyWith(strokeWidth: value) as T)),
        ExactSlider(
            header: Text(AppLocalizations.of(context)!.strokeMultiplier),
            value: property.strokeMultiplier,
            min: 0,
            max: 1,
            defaultValue: .5,
            onChangeEnd: (value) => onChanged(
                (property as dynamic).copyWith(strokeMultiplier: value) as T)),
      ];
}