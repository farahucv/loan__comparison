import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/app_settings.dart';
import 'screens/splash_screen.dart';
import 'screens/borrower_dashboard_screen.dart';
import 'screens/choose_loan_type_screen.dart';
import 'screens/secure_loan_assessment_screen.dart';
import 'screens/loan_analysis_screen.dart';
import 'screens/loan_offer_details_screen.dart';
import 'screens/request_status_screen.dart';
import 'screens/borrower_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xybccwmplbkjfmdfmnmx.supabase.co',
    publishableKey: 'sb_publishable_Ydn9fgVbjcoCdVAST2h3eg_u1ykX8kg',
  );

  runApp(const RushdApp());
}

final supabase = Supabase.instance.client;

class RushdApp extends StatelessWidget {
  const RushdApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return AnimatedBuilder(
      animation: settings,
      builder: (_, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Rushd',
        themeMode: settings.isDark ? ThemeMode.dark : ThemeMode.light,

        // Arabic for Flutter's own widgets too (date picker, tooltips, menus).
        locale: settings.isArabic ? const Locale('ar') : const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        theme: ThemeData(
          fontFamily: 'Arial',
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppPalette.bg1,
        ),

        darkTheme: ThemeData(
          fontFamily: 'Arial',
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppPalette.bg3,
        ),

        builder: (context, child) => Directionality(
          textDirection: settings.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),

        home: const SplashScreen(),

        routes: {
          '/borrowerDashboard': (_) => const BorrowerDashboardScreen(),
          '/chooseLoanType': (_) => const ChooseLoanTypeScreen(),
          '/loanAssessment': (_) => const SecureLoanAssessmentScreen(),
          '/loanAnalysis': (_) => const LoanAnalysisScreen(),
          '/loanOfferDetails': (_) => const LoanOfferDetailsScreen(),
          '/requestStatus': (_) => const RequestStatusScreen(),
          '/borrowerProfile': (_) => const BorrowerProfileScreen(),
        },
      ),
    );
  }
}
