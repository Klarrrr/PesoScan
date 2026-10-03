import '../models/money_class.dart';
import 'info_section.dart';

/// The five short tips at the top of the Help page.
const List<String> quickTips = [
  'Use a plain white or dark background',
  'Use even lighting and avoid shadows',
  'Keep coins and bills 5 mm apart, no overlapping',
  'Hold the camera 20–30 cm above the items',
  'Keep the camera steady while scanning',
];

/// Questions and answers. A function (not a constant) so the numbers of
/// supported coins and bills always match the app.
List<InfoSection> faqItems() {
  final coins = MoneyClasses.coins.length;
  final bills = MoneyClasses.bills.length;

  return [
    const InfoSection(
      'How do I get the most accurate scan?',
      'Spread your coins and bills on a plain, flat surface in a single layer. '
          'Keep them about 5 mm apart so they do not touch or overlap, hold the '
          'camera 20–30 cm above, and keep it steady until the boxes stop '
          'moving. Flatten folded bills first.',
    ),
    const InfoSection(
      'What lighting conditions work best?',
      'Natural daylight or a bright indoor lamp works well. Avoid harsh '
          'shadows and shiny reflections on the money. Use the flash button '
          'only in low light, and turn it off if it makes the coins glare. '
          'PesoScan will tell you when the picture is too dark or too bright.',
    ),
    const InfoSection(
      'Why are some items flagged with low confidence?',
      'A red or amber label means the app is not sure. This happens with '
          'worn or dirty money, glare, items that are partly hidden, or '
          'designs that look alike (for example BSP and NGC coins of the same '
          'value). Tap the item in the Scan Result to check it, change it or '
          'remove it. Once you check an item it is marked Verified.',
    ),
    const InfoSection(
      'How do I fix a wrong result?',
      'After you capture, tap a row in the Scan Result. Use the check mark '
          'if it is right, the pencil to choose the correct coin or bill, or '
          'the bin to remove something that is not money. If the whole result '
          'looks wrong, tap Rescan.',
    ),
    const InfoSection(
      'Can PesoScan detect counterfeit money?',
      'No. PesoScan only counts coins and bills by how they look. It cannot '
          'tell real money from fake money, so never use it to check whether '
          'money is genuine. For that, use the security features described by '
          'the Bangko Sentral ng Pilipinas.',
    ),
    const InfoSection(
      'Does scanning work without internet?',
      'Yes. The detection runs on your phone, and your history is stored on '
          'your phone. You only need internet to create an account, log in, '
          'receive email codes and reset a password. Once you are logged in, '
          'you stay logged in, even offline.',
    ),
    InfoSection(
      'Which coins and bills are supported?',
      'PesoScan recognizes $coins kinds of coins and $bills kinds of bills '
          '(including polymer notes). Open the Currency Guide to see each one. '
          'Money that is not in the guide, such as old designs or foreign '
          'currency, will not be recognized.',
    ),
    const InfoSection(
      'Why is my coin or bill not being detected?',
      'Check that it is fully inside the gold corners, not too small or too '
          'far, not blurry, and not touching other items. Make sure it is one '
          'of the supported designs in the Currency Guide, and try better '
          'light. Tap Reset and try again.',
    ),
    const InfoSection(
      'Where are my scans stored, and how do I delete them?',
      'Your scans and photos stay on your phone, separately for each account. '
          'In History you can delete one scan, or use Clear All. In Settings, '
          'Clear Cached Images removes the photos but keeps your totals.',
    ),
    const InfoSection(
      'How do I share or save a result?',
      'Open a scan from History and use Share to send it as a picture, Save to '
          'put it in your gallery, or Copy total to copy the amount.',
    ),
    const InfoSection(
      'I forgot my password.',
      'On the login screen tap Forgot password, enter your email and type the '
          '6-digit code we send you. Then choose a new password.',
    ),
    const InfoSection(
      'I did not receive my email code.',
      'Check your spam folder and make sure the email address is right and '
          'you are online. Wait for the 60-second timer, then tap Resend code.',
    ),
  ];
}
