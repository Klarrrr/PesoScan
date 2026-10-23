import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_colors.dart';

/// Controller to reset the hCaptcha state after a form submission.
class HCaptchaBoxController {
  VoidCallback? _reset;

  void reset() {
    _reset?.call();
  }
}

/// A native "I am human" checkbox card that opens a floating pop-up modal
/// when tapped, preventing any background scrolling while solving puzzles.
class HCaptchaBox extends StatefulWidget {
  /// Paste your public hCaptcha Sitekey (UUID format) here:
  static const String siteKey = '2b7e7d16-35f8-4c16-9dbc-6b58312c0de8';

  /// Paste your Supabase Project URL (from env.json) or domain here:
  static const String baseUrl = 'https://evbnjbryzvdvkinmtklp.supabase.co';

  final ValueChanged<String?> onTokenChanged;
  final HCaptchaBoxController? controller;

  const HCaptchaBox({super.key, required this.onTokenChanged, this.controller});

  @override
  State<HCaptchaBox> createState() => _HCaptchaBoxState();
}

class _HCaptchaBoxState extends State<HCaptchaBox> {
  String? _token;

  @override
  void initState() {
    super.initState();
    widget.controller?._reset = _resetCaptcha;
  }

  void _resetCaptcha() {
    if (!mounted) {
      return;
    }
    setState(() => _token = null);
    widget.onTokenChanged(null);
  }

  @override
  void didUpdateWidget(covariant HCaptchaBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._reset = null;
      widget.controller?._reset = _resetCaptcha;
    }
  }

  @override
  void dispose() {
    widget.controller?._reset = null;
    super.dispose();
  }

  Future<void> _openPopup() async {
    if (_token != null) {
      return;
    }
    FocusScope.of(context).unfocus();

    final token = await HCaptchaDialog.show(context);
    if (!mounted) {
      return;
    }
    if (token != null && token.isNotEmpty) {
      setState(() => _token = token);
      widget.onTokenChanged(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool verified = _token != null;

    return InkWell(
      onTap: verified ? null : _openPopup,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: verified
                ? Colors.greenAccent
                : c.textMuted.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: verified
                    ? Colors.greenAccent.withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: verified ? Colors.greenAccent : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: verified
                  ? const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.greenAccent,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                verified ? 'Verified human' : 'I am human',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.pan_tool_alt_rounded, color: c.gold, size: 22),
                const SizedBox(height: 2),
                Text(
                  'hCaptcha',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating pop-up modal that renders the hCaptcha puzzle and locks touch
/// gestures so dragging inside the puzzle never scrolls the underlying screen.
class HCaptchaDialog extends StatefulWidget {
  const HCaptchaDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const HCaptchaDialog(),
    );
  }

  @override
  State<HCaptchaDialog> createState() => _HCaptchaDialogState();
}

class _HCaptchaDialogState extends State<HCaptchaDialog> {
  late final WebViewController _webController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    final cleanSiteKey = HCaptchaBox.siteKey.trim();

    final html =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://js.hcaptcha.com/1/api.js?onload=initCaptcha&render=explicit" async defer></script>
  <style>
    * {
      box-sizing: border-box;
      touch-action: none;
      -webkit-user-select: none;
      user-select: none;
    }
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #161824;
      display: flex;
      justify-content: center;
      align-items: center;
      overflow: hidden;
      overscroll-behavior: none;
    }
  </style>
</head>
<body>
  <div id="captcha-container"></div>
  <script>
    var widgetId;
    function initCaptcha() {
      widgetId = hcaptcha.render('captcha-container', {
        sitekey: '$cleanSiteKey',
        theme: 'dark',
        callback: function(token) {
          HCaptchaChannel.postMessage('TOKEN:' + token);
        },
        'expired-callback': function() {
          HCaptchaChannel.postMessage('EXPIRED');
        },
        'error-callback': function() {
          HCaptchaChannel.postMessage('ERROR');
        }
      });
      // Automatically open the challenge inside the floating popup
      setTimeout(function() {
        try {
          hcaptcha.execute(widgetId);
        } catch (e) {}
      }, 300);
    }
  </script>
</body>
</html>
''';

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF161824))
      ..addJavaScriptChannel(
        'HCaptchaChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (!mounted) {
            return;
          }
          final msg = message.message;
          if (msg.startsWith('TOKEN:')) {
            final token = msg.substring(6);
            if (token.isNotEmpty) {
              Navigator.of(context).pop(token);
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: HCaptchaBox.baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: c.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 36),
                  Text(
                    'Security Verification',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                    onPressed: () => Navigator.of(context).pop(null),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 500,
                width: double.maxFinite,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: WebViewWidget(
                        controller: _webController,
                        // EagerGestureRecognizer ensures dragging puzzle pieces
                        // stays locked inside the WebView and never scrolls anything else.
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                      ),
                    ),
                    if (_loading) CircularProgressIndicator(color: c.gold),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
