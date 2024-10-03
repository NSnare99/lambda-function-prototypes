import 'dart:math';
import 'package:flutter/material.dart';

class CustomStepper extends StatefulWidget {
  final List<StepContent> steps;

  const CustomStepper({super.key, required this.steps});

  @override
  State<CustomStepper> createState() => _CustomStepperState();
}

class _CustomStepperState extends State<CustomStepper> {
  int currentStep = 0;
  late List<bool> completedSteps;

  late PageController _pageController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    completedSteps = List<bool>.filled(widget.steps.length, false);
    _pageController = PageController(initialPage: currentStep);
    _scrollController = ScrollController();
  }

  void completeStep(
    int stepIndex,
  ) {
    setState(() {
      completedSteps[stepIndex] = true;
      nextStep();
    });
  }

  void completeStepReport(int stepIndex) {
    setState(() {
      completedSteps[stepIndex] = true;
      nextStep();
    });
  }

  void nextStep() {
    if (currentStep < widget.steps.length - 1) {
      currentStep++;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  void previousStep() {
    completedSteps[currentStep] = false;
    if (currentStep > 0) {
      currentStep--;
      completedSteps[currentStep] = false;
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final numStepsOnScreen = ((constraints.maxWidth - 140) / 136).floor();
              final startingStep = max(
                0,
                min(
                  currentStep - (numStepsOnScreen / 2).floor(),
                  widget.steps.length - numStepsOnScreen,
                ),
              );
              final endingStep = min(widget.steps.length, startingStep + numStepsOnScreen);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left),
                    onPressed: currentStep != 0 ? previousStep : null, // update this line
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      shrinkWrap: true,
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: endingStep - startingStep,
                      itemBuilder: (BuildContext context, int index) {
                        final stepIndex = startingStep + index;
                        return StepChip(
                          stepNumber: stepIndex + 1,
                          title: widget.steps[stepIndex].title,
                          isActive: stepIndex == currentStep,
                          isCompleted: completedSteps[stepIndex],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.arrow_right),
                    onPressed: currentStep != widget.steps.length - 1 && completedSteps[currentStep]
                        ? nextStep
                        : null, // update this line
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.steps.length,
            onPageChanged: (value) {
              setState(() {
                currentStep = value;
              });
              _scrollController.animateTo(
                120.0 * currentStep,
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            },
            itemBuilder: (context, index) {
              final allPreviousStepsCompleted =
                  completedSteps.sublist(0, index).every((completed) => completed);
              return Container(
                padding: const EdgeInsets.only(
                  left: 10.0,
                  right: 10.0,
                  bottom: 10.0,
                ),
                child: widget.steps[index].child(
                  completeStep: () {
                    completeStep(index);
                  },
                  isDisabled: !allPreviousStepsCompleted,
                  stepNumber: index,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StepChip extends StatelessWidget {
  final int stepNumber;
  final String? title;
  final bool isActive;
  final bool isCompleted;

  const StepChip({
    super.key,
    required this.stepNumber,
    this.title,
    required this.isActive,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.zero,
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).appBarTheme.backgroundColor
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check)
                : Text(
                    '$stepNumber',
                  ),
          ),
        ),
        if (title != null)
          Flexible(
            child: Tooltip(
              message: title, // The tooltip message
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                constraints: const BoxConstraints(maxWidth: 150, minWidth: 30),
                child: Text(
                  title!,
                  style: const TextStyle(
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class StepContent {
  final String title;
  final Widget Function({
    required Function() completeStep,
    required bool isDisabled,
    required int stepNumber,
  }) child;

  StepContent({
    required this.title,
    required this.child,
  });
}
