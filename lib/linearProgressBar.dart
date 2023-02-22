import 'package:flutter/material.dart';

const double _kMyLinearProgressIndicatorHeight = 8.0;

class MyLinearProgressIndicator extends LinearProgressIndicator
    implements PreferredSizeWidget {
  MyLinearProgressIndicator({
    Key? key,
    double? value,
    required Color backgroundColor,
    Animation<Color>? valueColor,
  }) : super(
          key: key,
          value: value,
          backgroundColor: backgroundColor,
          valueColor: valueColor,
        ) {
    preferredSize =
        const Size(double.infinity, _kMyLinearProgressIndicatorHeight);
  }

  @override
  Size preferredSize = Size.zero;
}
