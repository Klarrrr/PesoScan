/// The image slots. To change a picture, just replace the file in
/// assets/images/ with the same name. No code changes needed.
class AppImages {
  AppImages._();

  static const folder = 'assets/images/';
  static const ext = 'png';

  static const logo = 'image_1'; // splash logo, shown at 112x112
  static const cameraAccess = 'image_2'; // permission icon, 44x44
  static const onboardingFlat = 'image_3'; // 56x56
  static const onboardingSpacing = 'image_4'; // 56x56
  static const onboardingInstant = 'image_5'; // 56x56

  /// Reserved for the Currency Reference (Part 18):
  /// class id 1 -> image_6, ... class id 19 -> image_24.
  static String forClass(int classId) => 'image_${classId + 5}';
}
