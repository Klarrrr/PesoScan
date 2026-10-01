import 'package:flutter/material.dart';

import '../../core/app_routes.dart';

/// Every "start scanning" button calls this one function.
/// Part 9 upgrades it to check the camera permission first.
void openScanner(BuildContext context) {
  Navigator.pushNamed(context, AppRoutes.scanner);
}
