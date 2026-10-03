import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  bool isDark = true;
  bool isArabic = false;

  void setDark(bool value) {
    if (isDark == value) return;
    isDark = value;
    notifyListeners();
  }

  void setArabic(bool value) {
    if (isArabic == value) return;
    isArabic = value;
    notifyListeners();
  }

  String tr(String value) {
    if (!isArabic) return value;

    const m = <String, String>{
      // Navigation
      'Home': 'الرئيسية',
      'Loan Options': 'خيارات القروض',
      'Request Status': 'حالة الطلب',
      'My Profile': 'ملفي الشخصي',
      'Sign Out': 'تسجيل الخروج',
      'Sign in': 'تسجيل الدخول',

      // Authentication
      'Get Started': 'ابدأ الآن',
      'Welcome Back': 'مرحبًا بعودتك',
      'Sign in to continue to your account':
          'سجّل الدخول للمتابعة إلى حسابك',
      'Create Account': 'إنشاء حساب',
      'Choose your account type': 'اختر نوع حسابك',
      'Borrower': 'مقترض',
      'Lender': 'جهة تمويل',

      // Home
      'AI-supported loan recommendations':
          'توصيات قروض مدعومة بالذكاء الاصطناعي',
      'Personalized': 'حلول مخصصة',
      'Loan Solutions': 'للقروض',
      'for You': 'تناسبك',
      'Enter your loan type and financial details,\n'
              'compare suitable offers, submit your request\n'
              'through Rushd, and let lender representatives\n'
              'review it inside the platform.':
          'أدخل نوع القرض وبياناتك المالية،\n'
              'وقارن بين العروض المناسبة، ثم أرسل طلبك\n'
              'من خلال رشد ليتمكن ممثلو جهات التمويل\n'
              'من مراجعته داخل المنصة.',
      'Start Your Assessment →': 'ابدأ تقييمك ←',
      'I am a Lender': 'أنا جهة تمويل',

      'SIMPLE PROCESS': 'خطوات بسيطة',
      'How Rushd Works': 'كيف يعمل رشد',
      'A guided flow from loan type selection to lender decision, designed for a clearer borrowing experience.':
          'رحلة واضحة تبدأ باختيار نوع القرض وتنتهي بقرار جهة التمويل، لتجربة اقتراض أكثر وضوحًا.',

      'Enter Financial Details': 'أدخل بياناتك المالية',
      'Compare & Submit': 'قارن وأرسل الطلب',
      'Select Personal, Business, or Investment financing based on your need.':
          'اختر التمويل الشخصي أو تمويل الأعمال أو الاستثمار حسب احتياجك.',
      'Add income, obligations, expenses and requested amount for assessment.':
          'أضف الدخل والالتزامات والمصروفات والمبلغ المطلوب لإجراء التقييم.',
      'Review suitable offers and submit your request directly through Rushd.':
          'راجع العروض المناسبة وأرسل طلبك مباشرة من خلال رشد.',

      'WHY RUSHD?': 'لماذا رشد؟',
      'A smarter way to find\nsuitable loan offers.':
          'طريقة أذكى للعثور على\nعروض القروض المناسبة.',
      'Rushd helps borrowers compare offers based on their financial profile and gives lenders a structured way to review submitted requests.':
          'يساعد رشد المقترضين على مقارنة العروض بناءً على ملفهم المالي، ويوفر لجهات التمويل طريقة منظمة لمراجعة الطلبات المقدمة.',

      'AI-supported eligibility score':
          'تقييم أهلية مدعوم بالذكاء الاصطناعي',
      'Compare offers from partner banks':
          'قارن عروض البنوك الشريكة',
      'Submit requests inside the platform':
          'أرسل الطلبات داخل المنصة',
      'Track lender decisions clearly':
          'تابع قرارات جهات التمويل بوضوح',

      'PARTNER BANKS': 'البنوك الشريكة',
      'Compare offers from verified banks':
          'قارن العروض من البنوك المعتمدة',
      'Rushd displays sample offers from partner banks to demonstrate the comparison and request flow.':
          'يعرض رشد نماذج من عروض البنوك الشريكة لتوضيح آلية المقارنة وإرسال الطلبات.',

      // Borrower
      'Borrower Dashboard': 'لوحة المقترض',
      'Choose Loan Type': 'اختر نوع القرض',
      'Continue Assessment': 'متابعة التقييم',
      'View Loan Offers': 'عرض عروض القروض',
      'Track Requests': 'تتبع الطلبات',
      'Preferred Loan': 'القرض المفضل',
      'Submitted Requests': 'الطلبات المرسلة',
      'Pending Requests': 'الطلبات المعلقة',

      // Loan types
      'Personal Loan': 'قرض شخصي',
      'Business Loan': 'قرض أعمال',
      'Investment Loan': 'قرض استثماري',

      // Assessment
      'Secure Loan Assessment': 'تقييم القرض الآمن',
      'Full Name': 'الاسم الكامل',
      'Monthly Income (SAR)': 'الدخل الشهري (ر.س)',
      'Existing Loans / Debts (SAR)': 'القروض / الديون الحالية (ر.س)',
      'Monthly Expenses (SAR)': 'المصروفات الشهرية (ر.س)',
      'Desired Loan Amount (SAR)': 'مبلغ القرض المطلوب (ر.س)',
      'Check My Loan Options': 'تحقق من خيارات القرض',

      // Analysis
      'Your Loan Analysis': 'تحليل القرض',
      'View All Comparison': 'عرض المقارنة كاملة',
      'Rushd AI Personal Advisor': 'مستشار رشد الذكي',
      'AI Top Recommendations': 'أفضل توصيات الذكاء الاصطناعي',
      'View Offer': 'عرض العرض',

      // Offer
      'Back to Comparison': 'العودة للمقارنة',
      'Key Offer Features': 'مزايا العرض الرئيسية',
      'Contact & Branch': 'التواصل والفرع',
      'Eligibility Formula': 'معادلة الأهلية',
      'Submit Loan Request Through Rushd':
          'إرسال طلب القرض عبر رشد',

      // Requests
      'Track your submitted loan requests.':
          'تابع طلبات القروض التي أرسلتها.',
      'No submitted requests yet.':
          'لا توجد طلبات مرسلة حتى الآن.',
      'Pending': 'قيد الانتظار',

      // Profile
      'Borrower Profile': 'ملف المقترض',
      'Profile Status': 'حالة الملف',
      'Email': 'البريد الإلكتروني',
      'Mobile': 'الجوال',
      'Monthly Income': 'الدخل الشهري',
      'Monthly Expenses': 'المصروفات الشهرية',
      'Existing Loans/Debts': 'القروض/الديون الحالية',
      'Preferred Loan Type': 'نوع القرض المفضل',
      'Update Financial Profile': 'تحديث الملف المالي',
      'Not entered': 'غير مدخل',

      // Settings
      'Preferences': 'التفضيلات',
      'Appearance': 'المظهر',
      'Language': 'اللغة',
      'Mode': 'الوضع',
      'Dark': 'داكن',
      'Light': 'فاتح',
      'English': 'English',
      'Arabic': 'العربية',

      // Lender
      'Review Requests': 'مراجعة الطلبات',
      'No Borrower Requests': 'لا توجد طلبات مقترضين',
      'Borrower loan applications will appear here.':
          'ستظهر طلبات القروض للمقترضين هنا.',
      'Manage Offers': 'إدارة العروض',
      'Add Offer': 'إضافة عرض',
      'Performance Dashboard': 'لوحة الأداء',
      'Lender Dashboard': 'لوحة جهة التمويل',
    };

    if (m.containsKey(value)) {
      return m[value]!;
    }

    var out = value;

    m.forEach((key, translatedValue) {
      out = out.replaceAll(key, translatedValue);
    });

    return out;
  }
}

class AppText extends Text {
  AppText(
    String data, {
    Key? key,
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    TextScaler? textScaler,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
    Color? selectionColor,
  }) : super(
          AppSettings.instance.tr(data),
          key: key,
          style: _style(style),
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
        );

  static TextStyle? _style(TextStyle? s) {
    if (s == null || AppSettings.instance.isDark) return s;

    final c = s.color;

    if (c == Colors.white ||
        c == Colors.white70 ||
        c == Colors.white60 ||
        c == Colors.white54 ||
        c == Colors.white38) {
      return s.copyWith(
        color: const Color(0xff202033),
      );
    }

    return s;
  }
}

class AppPalette {
  static Color get bg1 => AppSettings.instance.isDark
      ? const Color(0xff2B0A4D)
      : const Color(0xffF7F5FC);

  static Color get bg2 => AppSettings.instance.isDark
      ? const Color(0xff17052B)
      : const Color(0xffF0ECF8);

  static Color get bg3 => AppSettings.instance.isDark
      ? const Color(0xff0F021C)
      : const Color(0xffE8E2F3);

  static Color get panel => AppSettings.instance.isDark
      ? Colors.white.withOpacity(.085)
      : Colors.white.withOpacity(.90);

  static Color get border => AppSettings.instance.isDark
      ? Colors.white.withOpacity(.08)
      : const Color(0xffD8D0E6);
}

class RichAppText extends StatelessWidget {
  final TextSpan text;
  final TextAlign textAlign;

  const RichAppText({
    super.key,
    required this.text,
    this.textAlign = TextAlign.start,
  });

  TextSpan _translateSpan(TextSpan span) {
    return TextSpan(
      text: span.text == null
          ? null
          : AppSettings.instance.tr(span.text!),
      style: AppText._style(span.style),
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
      children: span.children?.map((child) {
        if (child is TextSpan) {
          return _translateSpan(child);
        }
        return child;
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: _translateSpan(text),
      textAlign: textAlign,
    );
  }
}