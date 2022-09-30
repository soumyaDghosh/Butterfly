import 'package:butterfly/helpers/int_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../api/open.dart';
import '../../cubits/settings.dart';
import '../../widgets/exact_slider.dart';

class PenBehaviorSettings extends StatelessWidget {
  const PenBehaviorSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.pen),
      ),
      body: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<SettingsCubit, ButterflySettings>(
            builder: (context, state) {
              final config = state.inputConfiguration;
              return ListView(
                children: [
                  Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExactSlider(
                              min: 0,
                              max: 100,
                              value: state.penSensitivity,
                              header: Row(children: [
                                const Icon(PhosphorIcons.lightningLight),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!.sensitivity),
                              ]),
                              onChangeEnd: (value) {
                                final cubit = context.read<SettingsCubit>();
                                cubit.changePenSensitivity(value);
                              }),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: state.penOnlyInput,
                            title: Text(
                                AppLocalizations.of(context)!.penOnlyInput),
                            onChanged: (value) => context
                                .read<SettingsCubit>()
                                .changepenOnlyInput(value ?? false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.shortcuts,
                                style: Theme.of(context).textTheme.headline5,
                              ),
                              IconButton(
                                icon: const Icon(
                                    PhosphorIcons.circleWavyQuestionLight),
                                onPressed: () =>
                                    openHelp(['shortcuts'], 'configure'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: config.pen?.add(1)?.toString() ?? '',
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.pen,
                              prefixIcon: const Icon(PhosphorIcons.penLight),
                              suffix: IconButton(
                                  onPressed: () {
                                    final cubit = context.read<SettingsCubit>();
                                    cubit.changeInputConfiguration(
                                        config.copyWith(pen: null));
                                  },
                                  icon: const Icon(
                                      PhosphorIcons.clockClockwiseLight)),
                            ),
                            onChanged: (value) {
                              final cubit = context.read<SettingsCubit>();
                              cubit.changeInputConfiguration(config.copyWith(
                                  pen: int.tryParse(value)?.subtract(1)));
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue:
                                config.firstPenButton?.add(1)?.toString() ?? '',
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.first,
                              prefixIcon: const Icon(
                                  PhosphorIcons.numberCircleOneLight),
                              suffix: IconButton(
                                  onPressed: () {
                                    final cubit = context.read<SettingsCubit>();
                                    cubit.changeInputConfiguration(
                                        config.copyWith(firstPenButton: 2));
                                  },
                                  icon: const Icon(
                                      PhosphorIcons.clockClockwiseLight)),
                            ),
                            onChanged: (value) {
                              final cubit = context.read<SettingsCubit>();
                              cubit.changeInputConfiguration(config.copyWith(
                                  firstPenButton:
                                      int.tryParse(value)?.subtract(1)));
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue:
                                config.secondPenButton?.add(1)?.toString() ??
                                    '',
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.second,
                              prefixIcon: const Icon(
                                  PhosphorIcons.numberCircleTwoLight),
                              suffix: IconButton(
                                  onPressed: () {
                                    final cubit = context.read<SettingsCubit>();
                                    cubit.changeInputConfiguration(
                                        config.copyWith(secondPenButton: 1));
                                  },
                                  icon: const Icon(
                                      PhosphorIcons.clockClockwiseLight)),
                            ),
                            onChanged: (value) {
                              final cubit = context.read<SettingsCubit>();
                              cubit.changeInputConfiguration(config.copyWith(
                                  secondPenButton:
                                      int.tryParse(value)?.subtract(1)));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}