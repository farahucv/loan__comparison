import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();
  bool isDark = true;
  bool isArabic = false;
  void setDark(bool value) { if (isDark == value) return; isDark = value; notifyListeners(); }
  void setArabic(bool value) { if (isArabic == value) return; isArabic = value; notifyListeners(); }

  String tr(String value) {
    if (!isArabic) return value;
    const m = <String,String>{
      'Home':'الرئيسية','Loan Options':'خيارات القروض','Request Status':'حالة الطلب','My Profile':'ملفي الشخصي','Sign Out':'تسجيل الخروج',
      'Get Started':'ابدأ الآن','Welcome Back':'مرحبًا بعودتك','Sign in to continue to your account':'سجّل الدخول للمتابعة إلى حسابك',
      'Create Account':'إنشاء حساب','Choose your account type':'اختر نوع حسابك','Borrower':'مقترض','Lender':'جهة تمويل',
      'Borrower Dashboard':'لوحة المقترض','Choose Loan Type':'اختر نوع القرض','Continue Assessment':'متابعة التقييم','View Loan Offers':'عرض عروض القروض','Track Requests':'تتبع الطلبات',
      'Preferred Loan':'القرض المفضل','Submitted Requests':'الطلبات المرسلة','Pending Requests':'الطلبات المعلقة',
      'Personal Loan':'قرض شخصي','Business Loan':'قرض أعمال','Investment Loan':'قرض استثماري',
      'Secure Loan Assessment':'تقييم القرض الآمن','Full Name':'الاسم الكامل','Monthly Income (SAR)':'الدخل الشهري (ر.س)','Existing Loans / Debts (SAR)':'القروض / الديون الحالية (ر.س)','Monthly Expenses (SAR)':'المصروفات الشهرية (ر.س)','Desired Loan Amount (SAR)':'مبلغ القرض المطلوب (ر.س)','Check My Loan Options':'تحقق من خيارات القرض',
      'Your Loan Analysis':'تحليل القرض','View All Comparison':'عرض المقارنة كاملة','Rushd AI Personal Advisor':'مستشار رشد الذكي','AI Top Recommendations':'أفضل توصيات الذكاء الاصطناعي','View Offer':'عرض العرض',
      'Back to Comparison':'العودة للمقارنة','Key Offer Features':'مزايا العرض الرئيسية','Contact & Branch':'التواصل والفرع','Eligibility Formula':'معادلة الأهلية','Submit Loan Request Through Rushd':'إرسال طلب القرض عبر رشد',
      'Track your submitted loan requests.':'تابع طلبات القروض التي أرسلتها.','No submitted requests yet.':'لا توجد طلبات مرسلة حتى الآن.','Pending':'قيد الانتظار',
      'Borrower Profile':'ملف المقترض','Profile Status':'حالة الملف','Email':'البريد الإلكتروني','Mobile':'الجوال','Monthly Income':'الدخل الشهري','Monthly Expenses':'المصروفات الشهرية','Existing Loans/Debts':'القروض/الديون الحالية','Preferred Loan Type':'نوع القرض المفضل','Update Financial Profile':'تحديث الملف المالي','Not entered':'غير مدخل',
      'Preferences':'التفضيلات','Appearance':'المظهر','Language':'اللغة','Dark':'داكن','Light':'فاتح','English':'English','Arabic':'العربية',
      'Review Requests':'مراجعة الطلبات','No Borrower Requests':'لا توجد طلبات مقترضين','Borrower loan applications will appear here.':'ستظهر طلبات القروض للمقترضين هنا.','Manage Offers':'إدارة العروض','Add Offer':'إضافة عرض','Performance Dashboard':'لوحة الأداء','Lender Dashboard':'لوحة جهة التمويل',
    };
    if (m.containsKey(value)) return m[value]!;
    var out=value;
    m.forEach((k,v){ out=out.replaceAll(k,v); });
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
    final c=s.color;
    if (c==Colors.white || c==Colors.white70 || c==Colors.white60 || c==Colors.white54 || c==Colors.white38) return s.copyWith(color: const Color(0xff202033));
    return s;
  }
}

class AppPalette {
  static Color get bg1 => AppSettings.instance.isDark ? const Color(0xff2B0A4D) : const Color(0xffF7F5FC);
  static Color get bg2 => AppSettings.instance.isDark ? const Color(0xff17052B) : const Color(0xffF0ECF8);
  static Color get bg3 => AppSettings.instance.isDark ? const Color(0xff0F021C) : const Color(0xffE8E2F3);
  static Color get panel => AppSettings.instance.isDark ? Colors.white.withOpacity(.085) : Colors.white.withOpacity(.90);
  static Color get border => AppSettings.instance.isDark ? Colors.white.withOpacity(.08) : const Color(0xffD8D0E6);
}

class RichAppText extends StatelessWidget {
  final TextSpan text;
  final TextAlign textAlign;
  const RichAppText({super.key, required this.text, this.textAlign = TextAlign.start});

  TextSpan _translateSpan(TextSpan span) {
    return TextSpan(
      text: span.text == null ? null : AppSettings.instance.tr(span.text!),
      style: AppText._style(span.style),
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
      children: span.children?.map((child) {
        if (child is TextSpan) return _translateSpan(child);
        return child;
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => RichText(
        text: _translateSpan(text),
        textAlign: textAlign,
      );
}
