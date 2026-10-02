import 'package:flutter/material.dart';

import '../models/app_settings.dart';

import 'login_screen.dart';
import 'lender_register_screen.dart';
import 'borrower_register_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, String>> partnerBanks = const [
    {"name": "Riyad Bank", "logo": "assets/images/Riyad-Bank-Logo.png"},
    {
      "name": "Saudi National Bank",
      "logo": "assets/images/Saudi_National_Bank_Logo.png",
    },
    {"name": "Bank Albilad", "logo": "assets/images/Albilad-Bank-Logo.png"},
    {"name": "Al Rajhi Bank", "logo": "assets/images/Alrajhi-Bank-Logo.png"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.bg1, AppPalette.bg2, AppPalette.bg3],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header / Navbar Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 80,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/images/rushd_log.png', width: 180),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: AppText("Sign in"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Hero Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.lightBlue.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white70,
                                  size: 15,
                                ),
                                const SizedBox(width: 8),
                                AppText(
                                  "AI-supported loan recommendations",
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
                                  text: "Personalized\n",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                TextSpan(
                                  text: "Loan Solutions\n",
                                  style: TextStyle(
                                    color: Colors.lightBlue,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                TextSpan(
                                  text: "for You",
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
                            "Enter your loan type and financial details,\n"
                            "compare suitable offers, submit your request\n"
                            "through Rushd, and let lender representatives\n"
                            "review it inside the platform.",
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 30),

                          Row(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlue,
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
                                child: AppText("Start Your Assessment →"),
                              ),

                              const SizedBox(width: 15),

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
                                child: AppText("I am a Lender"),
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

              // Process Section Header
              AppText(
                "SIMPLE PROCESS",
                style: const TextStyle(
                  color: Colors.lightBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 10),

              AppText(
                "How Rushd Works",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 15),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 250),
                child: AppText(
                  "A guided flow from loan type selection to lender decision, designed for a clearer borrowing experience.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),

              const SizedBox(height: 30),

              // Process Cards Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  processCard(
                    "01",
                    "Choose Loan Type",
                    "Select Personal, Business, or Investment financing based on your need.",
                    Icons.credit_card_outlined,
                  ),
                  processCard(
                    "02",
                    "Enter Financial Details",
                    "Add income, obligations, expenses and requested amount for assessment.",
                    Icons.person_outline,
                  ),
                  processCard(
                    "03",
                    "Compare & Submit",
                    "Review suitable offers and submit your request directly through Rushd.",
                    Icons.compare_arrows,
                  ),
                ],
              ),

              const SizedBox(height: 70),

              // Why Rushd Section
              whyRushdSection(),

              const SizedBox(height: 70),

              // Partners Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80),
                child: partnersSection(),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
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
                  color: Colors.white30,
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
                child: Icon(icon, color: Colors.lightBlue, size: 20),
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
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

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
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  "WHY RUSHD?",
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 15),

                AppText(
                  "A smarter way to find\nsuitable loan offers.",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 15),

                AppText(
                  "Rushd helps borrowers compare offers based on their financial profile and gives lenders a structured way to review submitted requests.",
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
                    featureCard("AI-supported eligibility score"),
                    const SizedBox(width: 15),
                    featureCard("Compare offers from partner banks"),
                  ],
                ),

                const SizedBox(height: 15),

                Row(
                  children: [
                    featureCard("Submit requests inside the platform"),
                    const SizedBox(width: 15),
                    featureCard("Track lender decisions clearly"),
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
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.lightBlue),
              ),
              child: const Icon(Icons.check, color: Colors.lightBlue, size: 14),
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

  Widget partnersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                    "PARTNER BANKS",
                    style: const TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  AppText(
                    "Compare offers from verified banks",
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
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AppText(
                    "Rushd displays sample offers from partner banks to demonstrate the comparison and request flow.",
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: partnerBanks.map((bank) {
              return SizedBox(
                width: 220, // عرض ملموم ومحدد للبطاقات الصغيرة
                height: 90,  // ارتفاع متناسق
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 38,
                        child: Image.asset(
                          bank["logo"]!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
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
                        bank["name"]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}