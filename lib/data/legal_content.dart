import 'info_section.dart';

/// ⚠️ Replace this with your team's real email before you publish.
const String contactEmail = 'your-team@example.com';

const String legalLastUpdated = 'October 2026';

/// Terms of Service. Have your adviser read it before you present.
const List<InfoSection> termsSections = [
  InfoSection(
    '1. About PesoScan',
    'PesoScan is a student research project. It uses deep learning (YOLO26) '
        'through your phone camera to recognize and add up Philippine peso '
        'coins and banknotes. By creating an account or using the app you '
        'agree to these Terms.',
  ),
  InfoSection(
    '2. Counting only, not authentication',
    'PesoScan is designed for counting purposes only. It does not detect '
        'counterfeit coins or bills and must not be used to decide whether '
        'money is genuine. Use the official security features described by '
        'the Bangko Sentral ng Pilipinas (BSP) for that.',
  ),
  InfoSection(
    '3. Accuracy of results',
    'Results come from a machine-learning model and can be wrong, for '
        'example with worn money, poor light, overlapping items or designs '
        'that look alike. You are responsible for checking the total before '
        'you rely on it. The PesoScan team is not responsible for losses or '
        'disputes that result from relying on a count.',
  ),
  InfoSection(
    '4. Your account',
    'You need a valid email address to create an account. Keep your password '
        'and email codes private. You are responsible for what happens under '
        'your account. We may limit or close accounts that are misused.',
  ),
  InfoSection(
    '5. Acceptable use',
    'Do not try to break, overload or reverse-engineer the service, access '
        'other people\'s accounts or data, or use PesoScan for anything '
        'unlawful.',
  ),
  InfoSection(
    '6. Your data',
    'How we handle your information is explained in the Privacy Policy. In '
        'short: your scans and photos stay on your phone, and only your '
        'account details are kept on our server.',
  ),
  InfoSection(
    '7. Ownership',
    'The PesoScan app, its design and its code belong to the PesoScan team. '
        'Pictures and descriptions of Philippine currency are shown for '
        'reference only; the currency designs belong to the Bangko Sentral ng '
        'Pilipinas.',
  ),
  InfoSection(
    '8. Changes and availability',
    'PesoScan is a research prototype and is provided "as is", without '
        'promises that it will always work or be available. We may change or '
        'stop the app, and we may update these Terms. If you keep using the '
        'app after a change, you accept the new Terms.',
  ),
  InfoSection(
    '9. Governing law',
    'These Terms are governed by the laws of the Republic of the Philippines.',
  ),
  InfoSection(
    '10. Contact',
    'Questions about these Terms? Email us at $contactEmail.',
  ),
];

/// Privacy Policy, written with the Data Privacy Act of 2012 (RA 10173) in
/// mind. Keep it in step with what the app really does.
const List<InfoSection> privacySections = [
  InfoSection(
    '1. The short version',
    'Your scans and photos stay on your phone. We keep only what is needed '
        'for your account: your email, your username and your (protected) '
        'password. There are no ads, no tracking and we do not sell your '
        'information.',
  ),
  InfoSection(
    '2. What we collect',
    'Account details: your email address, username and password. Your '
        'password is stored by our account provider in a protected, '
        'one-way form that we cannot read. Technical records such as '
        'sign-in times are kept by that provider to keep the service secure. '
        'On your phone only: your scan results, scan photos and app '
        'settings.',
  ),
  InfoSection(
    '3. Camera and photos',
    'PesoScan uses the camera to detect coins and bills on your phone. '
        'Pictures are processed on your device. A photo is taken only when you '
        'press the capture button, and it is stored in the app\'s private '
        'storage. Photos are never uploaded. A picture leaves your phone only '
        'if you choose Share or Save.',
  ),
  InfoSection(
    '4. How we use your information',
    'We use your email and username to create your account, to send you '
        'verification and login codes, and to keep your account secure. We '
        'do not use it for anything else.',
  ),
  InfoSection(
    '5. Services we rely on',
    'Your account is handled by Supabase (a database and sign-in service). '
        'Verification emails are sent through an email delivery service. '
        'These providers process your email address on our behalf, and their '
        'servers may be outside the Philippines.',
  ),
  InfoSection(
    '6. Sharing',
    'We do not sell or rent your information. We share it only with the '
        'service providers above, to run the app, or when the law requires '
        'it.',
  ),
  InfoSection(
    '7. Keeping and deleting your data',
    'Scans stay on your phone until you delete them: delete one scan, use '
        'Clear All in History, or use Clear Cached Images in Settings to '
        'remove photos only. Uninstalling the app removes the data stored on '
        'the phone. To delete your account, email us at $contactEmail.',
  ),
  InfoSection(
    '8. Your rights',
    'Under the Data Privacy Act of 2012 (Republic Act No. 10173) you have the '
        'right to be informed, to access and correct your personal data, to '
        'object to its processing, to ask for it to be erased or blocked, to '
        'data portability, and to complain to the National Privacy '
        'Commission. To use these rights, email $contactEmail.',
  ),
  InfoSection(
    '9. Security',
    'Sign-in uses your password plus a one-time code sent to your email. '
        'Connections to our server are encrypted. The app keeps you signed in '
        'on your phone, so please lock your phone. No system is perfectly '
        'secure, but we take reasonable steps to protect your data.',
  ),
  InfoSection(
    '10. Children',
    'PesoScan is not designed for young children. If you are under 18, '
        'please use it with a parent or guardian.',
  ),
  InfoSection(
    '11. Changes to this policy',
    'We may update this policy and will change the date below when we do.',
  ),
  InfoSection('12. Contact', 'Privacy questions or requests: $contactEmail.'),
];
