import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/error_messages.dart';

import '../models/app_settings.dart';
import 'home_screen.dart';

const kBlue = Color(0xff2F74F5), kCyan = Color(0xff77B8FF);

BoxDecoration rushdBackground() => BoxDecoration(
  gradient: LinearGradient(
    colors: [AppPalette.bg1, AppPalette.bg2, AppPalette.bg3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

BoxDecoration panel({double radius = 22}) => BoxDecoration(
  color: AppPalette.panel,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppPalette.border),
);

TextStyle white(
  double s, {
  FontWeight w = FontWeight.normal,
  Color c = Colors.white,
}) => TextStyle(
  color: AppSettings.instance.isDark
      ? c
      : (c == Colors.white ||
                c == Colors.white70 ||
                c == Colors.white60 ||
                c == Colors.white54 ||
                c == Colors.white38
            ? const Color(0xff202033)
            : c),
  fontSize: s,
  fontWeight: w,
);

class BorrowerShell extends StatelessWidget {
  final Widget child;
  final int active;

  const BorrowerShell({super.key, required this.child, this.active = 0});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppSettings.instance.tr('Error signing out:')} ${friendlyError(error)}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: rushdBackground(),
      child: SafeArea(
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, box) => box.maxWidth < 860
                  ? _compactHeader(context)
                  : _wideHeader(context),
            ),

            Expanded(child: child),
          ],
        ),
      ),
    ),
  );

  BoxDecoration get _headerDecoration => BoxDecoration(
    color: const Color(0xff130022).withValues(alpha: .55),
    border: Border(
      bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
    ),
  );

  /// Phones and narrow windows: logo + menu.
  Widget _compactHeader(BuildContext context) {
    const items = ['Home', 'Loan Options', 'Request Status', 'My Profile'];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _headerDecoration,
      child: Row(
        children: [
          Image.asset(
            'assets/images/rushd_log.png',
            width: 110,
            errorBuilder: (_, _, _) =>
                AppText('Rushd', style: white(20, w: FontWeight.bold)),
          ),

          const Spacer(),

          PopupMenuButton<int>(
            tooltip: AppSettings.instance.tr('Menu'),
            icon: const Icon(Icons.menu, color: Colors.white),
            color: const Color(0xff1E0B36),
            onSelected: (i) {
              if (i == 4) {
                _signOut(context);
              } else {
                _go(context, i);
              }
            },
            itemBuilder: (_) => [
              for (var i = 0; i < items.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Text(
                    AppSettings.instance.tr(items[i]),
                    style: TextStyle(
                      color: i == active ? kCyan : Colors.white,
                      fontWeight: i == active
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 4,
                child: Text(
                  AppSettings.instance.tr('Sign Out'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wideHeader(BuildContext context) => Container(
    height: 78,
    padding: const EdgeInsets.symmetric(horizontal: 80),
    decoration: _headerDecoration,
    child: Row(
      children: [
        Image.asset(
          'assets/images/rushd_log.png',
          width: 150,
          errorBuilder: (_, _, _) =>
              AppText('Rushd', style: white(22, w: FontWeight.bold)),
        ),

        const Spacer(),

        _nav(context, 'Home', 0),

        const SizedBox(width: 34),

        _nav(context, 'Loan Options', 1),

        const SizedBox(width: 34),

        _nav(context, 'Request Status', 2),

        const SizedBox(width: 34),

        _nav(context, 'My Profile', 3),

        const Spacer(),

        OutlinedButton(
          onPressed: () => _signOut(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .08),
            side: BorderSide(color: Colors.white.withValues(alpha: .12)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          child: AppText('Sign Out', style: white(12, w: FontWeight.bold)),
        ),
      ],
    ),
  );

  void _go(BuildContext context, int i) {
    if (i == 0) {
      Navigator.pushReplacementNamed(context, '/borrowerDashboard');
    }

    if (i == 1) {
      Navigator.pushReplacementNamed(context, '/chooseLoanType');
    }

    if (i == 2) {
      Navigator.pushReplacementNamed(context, '/requestStatus');
    }

    if (i == 3) {
      Navigator.pushReplacementNamed(context, '/borrowerProfile');
    }
  }

  Widget _nav(BuildContext context, String t, int i) => InkWell(
    onTap: () => _go(context, i),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AppText(
        t,
        style: white(
          12,
          w: i == active ? FontWeight.bold : FontWeight.normal,
          c: i == active ? kCyan : Colors.white70,
        ),
      ),
    ),
  );
}

Widget metric(String label, String value, {double? width}) => Container(
  width: width,
  padding: const EdgeInsets.all(16),
  decoration: panel(radius: 14),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(label, style: white(11, c: Colors.white54)),
      const SizedBox(height: 5),
      AppText(value, style: white(18, w: FontWeight.w800)),
    ],
  ),
);

Widget blueButton(String text, VoidCallback tap) => SizedBox(
  height: 48,
  child: ElevatedButton(
    onPressed: tap,
    style: ElevatedButton.styleFrom(
      backgroundColor: kBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: AppText(text, style: white(13, w: FontWeight.bold)),
  ),
);
