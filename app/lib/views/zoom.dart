import 'package:butterfly/bloc/document_bloc.dart';
import 'package:butterfly/cubits/current_index.dart';
import 'package:butterfly/cubits/settings.dart';
import 'package:butterfly/cubits/transform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ZoomView extends StatefulWidget {
  const ZoomView({super.key});

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> with TickerProviderStateMixin {
  late Animation<double> _animation;
  late AnimationController _controller;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _zoomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutExpo);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, ButterflySettings>(
      buildWhen: (previous, current) =>
          previous.zoomEnabled != current.zoomEnabled,
      builder: (context, settings) =>
          BlocBuilder<DocumentBloc, DocumentState>(builder: (context, state) {
        if (state is! DocumentLoadSuccess || !settings.zoomEnabled) {
          return const SizedBox();
        }
        void zoom(double value) {
          final viewport =
              context.read<CurrentIndexCubit>().state.cameraViewport;
          final center = Offset(
            (viewport.width ?? 0) / 2,
            (viewport.height ?? 0) / 2,
          );
          context.read<TransformCubit>().size(value, center);
          state.currentIndexCubit.bake(state.document);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            return Stack(
              children: [
                Positioned(
                  bottom: isMobile ? 75 : 25,
                  right: 25,
                  width: isMobile ? 100 : 400,
                  height: 60,
                  child: BlocBuilder<TransformCubit, CameraTransform>(
                    buildWhen: (previous, current) =>
                        previous.size != current.size,
                    builder: (context, transform) {
                      var scale = transform.size;
                      if (isMobile) {
                        _controller.reverse(from: 1);
                      } else {
                        if (_controller.status != AnimationStatus.completed) {
                          _controller.forward(from: 0);
                        }
                      }
                      final text = (scale * 100).toStringAsFixed(0);
                      if (text != _zoomController.text) {
                        _zoomController.text = text;
                      }
                      return AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) => Opacity(
                          opacity: _animation.value,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: StatefulBuilder(
                                builder: (context, setState) {
                                  return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 75,
                                          child: TextFormField(
                                            textAlign: TextAlign.center,
                                            controller: _zoomController,
                                            keyboardType: TextInputType.number,
                                            focusNode: _focusNode,
                                            onChanged: (value) {
                                              setState(() => scale =
                                                  (double.tryParse(value) ??
                                                          (scale * 100)) /
                                                      100);
                                            },
                                            onEditingComplete: () =>
                                                zoom(scale),
                                            onTapOutside: (event) {
                                              zoom(scale);
                                              _focusNode.unfocus();
                                            },
                                            onFieldSubmitted: (value) =>
                                                zoom(scale),
                                          ),
                                        ),
                                        if (!isMobile)
                                          Expanded(
                                            child: Slider(
                                              value: scale.clamp(kMinZoom, 10),
                                              min: kMinZoom,
                                              max: 10,
                                              onChanged: (value) =>
                                                  setState(() => scale = value),
                                              onChangeEnd: zoom,
                                            ),
                                          ),
                                      ]);
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}