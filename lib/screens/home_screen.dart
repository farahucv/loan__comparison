import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import 'login_screen.dart';
import 'lender_register_screen.dart';
import 'borrower_register_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, String>> partnerBanks = const [
    {
      "name": "Riyad Bank",
      "logo": "assets/images/Riyad-Bank-Logo.png",
    },
    {
      "name": "Saudi National Bank",
      "logo": "assets/images/Saudi_National_Bank_Logo.png",
    },
    {
      "name": "Bank Albilad",
      "logo": "assets/images/Albilad-Bank-Logo.png",
    },
    {
      "name": "Al Rajhi Bank",
      "logo": "assets/images/Alrajhi-Bank-Logo.png",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Directionality(
          textDirection: AppSettings.instance.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(
            body: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppPalette.bg1,
                    AppPalette.bg2,
                    AppPalette.bg3,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ================= HEADER =================
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 80,
                        vertical: 20,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/rushd_log.png',
                            width: 180,
                          ),

                          const Spacer(),

                          // Language
                          _languageButton(),

                          const SizedBox(width: 10),

                          // Mode
                          _modeButton(),

                          const SizedBox(width: 16),

                          // Sign in
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LoginScreen(),
                                ),
                              );
                            },
                            child: AppText(
                              'Sign in',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ================= HERO =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 80),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.lightBlue
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: AppSettings.instance.isDark
                                            ? Colors.white70
                                            : const Color(0xff555566),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 8),
                                      AppText(
                                        'AI-supported loan recommendations',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                RichAppText(
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Personalized\n',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Loan Solutions\n',
                                        style: TextStyle(
                                          color: Colors.lightBlue,
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'for You',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                AppText(
                                  'Enter your loan type and financial details,\n'
                                  'compare suitable offers, submit your request\n'
                                  'through Rushd, and let lender representatives\n'
                                  'review it inside the platform.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                ),

                                const SizedBox(height: 30),

                                Wrap(
                                  spacing: 15,
                                  runSpacing: 12,
                                  children: [
                                    ElevatedButton(
                                      style:
                                          ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.lightBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const BorrowerRegisterScreen(),
                                          ),
                                        );
                                      },
                                      child: AppText(
                                        'Start Your Assessment →',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LenderRegisterScreen(),
                                          ),
                                        );
                                      },
                                      child: AppText('I am a Lender'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 50),

                          Expanded(
                            child: Container(
                              height: 350,
                              width: 450,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.asset(
                                  'assets/images/Home_logo.jpeg',
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),

                    // ================= PROCESS =================
                    AppText(
                      'SIMPLE PROCESS',
                      style: const TextStyle(
                        color: Colors.lightBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    AppText(
                      'How Rushd Works',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 250),
                      child: AppText(
                        'A guided flow from loan type selection to lender decision, designed for a clearer borrowing experience.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        processCard(
                          '01',
                          'Choose Loan Type',
                          'Select Personal, Business, or Investment financing based on your need.',
                          Icons.credit_card_outlined,
                        ),
                        processCard(
                          '02',
                          'Enter Financial Details',
                          'Add income, obligations, expenses and requested amount for assessment.',
                          Icons.person_outline,
                        ),
                        processCard(
                          '03',
                          'Compare & Submit',
                          'Review suitable offers and submit your request directly through Rushd.',
                          Icons.compare_arrows,
                        ),
                      ],
                    ),

                    const SizedBox(height: 70),

                    // ================= WHY RUSHD =================
                    whyRushdSection(),

                    const SizedBox(height: 70),

                    // ================= PARTNERS =================
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 80),
                      child: partnersSection(),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LANGUAGE BUTTON
  // ============================================================

  Widget _languageButton() {
    return PopupMenuButton<bool>(
      tooltip: 'Language',
      onSelected: (isArabic) {
        AppSettings.instance.setArabic(isArabic);
      },
      itemBuilder: (context) => [
        PopupMenuItem<bool>(
          value: false,
          child: Row(
            children: [
              Icon(
                !AppSettings.instance.isArabic
                    ? Icons.check
                    : Icons.language,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('English'),
            ],
          ),
        ),
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: [
              Icon(
                AppSettings.instance.isArabic
                    ? Icons.check
                    : Icons.language,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('العربية'),
            ],
          ),
        ),
      ],
      child: _headerSettingButton(
        Icons.language,
        AppSettings.instance.isArabic ? 'اللغة' : 'Language',
      ),
    );
  }

  // ============================================================
  // MODE BUTTON
  // ============================================================

  Widget _modeButton() {
    return PopupMenuButton<bool>(
      tooltip: 'Mode',
      onSelected: (isDark) {
        AppSettings.instance.setDark(isDark);
      },
      itemBuilder: (context) => [
        PopupMenuItem<bool>(
          value: false,
          child: Row(
            children: [
              Icon(
                !AppSettings.instance.isDark
                    ? Icons.check
                    : Icons.light_mode_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Light'),
            ],
          ),
        ),
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: [
              Icon(
                AppSettings.instance.isDark
                    ? Icons.check
                    : Icons.dark_mode_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Dark'),
            ],
          ),
        ),
      ],
      child: _headerSettingButton(
        AppSettings.instance.isDark
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        AppSettings.instance.isArabic ? 'الوضع' : 'Mode',
      ),
    );
  }

  Widget _headerSettingButton(
    IconData icon,
    String label,
  ) {
    final foreground = AppSettings.instance.isDark
        ? Colors.white
        : const Color(0xff202033);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: foreground,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 17,
            color: foreground,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROCESS CARD
  // ============================================================

  Widget processCard(
    String number,
    String title,
    String description,
    IconData icon,
  ) {
    return Container(
      width: 300,
      height: 180,
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                number,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.lightBlue,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          AppText(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 10),

          AppText(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WHY RUSHD
  // ============================================================

  Widget whyRushdSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 350,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppPalette.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppPalette.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'WHY RUSHD?',
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 15),

                AppText(
                  'A smarter way to find\nsuitable loan offers.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 15),

                AppText(
                  'Rushd helps borrowers compare offers based on their financial profile and gives lenders a structured way to review submitted requests.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    featureCard(
                      'AI-supported eligibility score',
                    ),
                    const SizedBox(width: 15),
                    featureCard(
                      'Compare offers from partner banks',
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    featureCard(
                      'Submit requests inside the platform',
                    ),
                    const SizedBox(width: 15),
                    featureCard(
                      'Track lender decisions clearly',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget featureCard(String text) {
    return Expanded(
      child: Container(
        height: 95,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppPalette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppPalette.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.lightBlue,
                ),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.lightBlue,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppText(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PARTNER BANKS
  // ============================================================

  Widget partnersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppPalette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'PARTNER BANKS',
                    style: const TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    'Compare offers from verified banks',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 30),

              Flexible(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: 400),
                  child: AppText(
                    'Rushd displays sample offers from partner banks to demonstrate the comparison and request flow.',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 35),

          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 12,
            children: partnerBanks.map((bank) {
              return Container(
                width: 220,
                height: 90,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppSettings.instance.isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppPalette.border,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Image.asset(
                        bank['logo']!,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stackTrace) {
                          return const Icon(
                            Icons.account_balance,
                            color: Colors.blueGrey,
                            size: 28,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 6),

                    AppText(
                      bank['name']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}