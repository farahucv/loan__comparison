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
      'Sign in to continue to your account': 'سجّل الدخول للمتابعة إلى حسابك',
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

      'AI-supported eligibility score': 'تقييم أهلية مدعوم بالذكاء الاصطناعي',
      'Compare offers from banks shown (sample data)':
          'قارن عروض البنوك المعروضة (بيانات تجريبية)',
      'Submit requests inside the platform': 'أرسل الطلبات داخل المنصة',
      'Track lender decisions clearly': 'تابع قرارات جهات التمويل بوضوح',

      'BANKS SHOWN (SAMPLE DATA)': 'البنوك المعروضة (بيانات تجريبية)',
      'Rushd displays sample offers from the banks shown (sample data) to demonstrate the comparison and request flow.':
          'يعرض رشد نماذج من عروض البنوك المعروضة (بيانات تجريبية) لتوضيح آلية المقارنة وإرسال الطلبات.',
      'Bank names are used for academic demonstration only; Rushd has no partnership with these banks.':
          'أسماء البنوك مستخدمة لأغراض أكاديمية فقط، ولا توجد شراكة بين رشد وهذه البنوك.',

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
      'Make sure your information is accurate to get accurate offers.':
          'تأكد من صحة بياناتك للحصول على عروض دقيقة.',
      'Requesting a loan with incorrect information may put your account at risk of being banned.':
          'تقديم طلب قرض ببيانات غير صحيحة قد يعرّض حسابك لخطر الحظر.',

      // Loan application
      'Proceed to Get Your Loan': 'تابع للحصول على قرضك',
      'Continue Your Journey': 'أكمل رحلتك',
      'Loan Application': 'طلب القرض',
      'Your Information': 'بياناتك',
      'This information is sent to the bank for review. Make sure it is accurate.':
          'تُرسل هذه البيانات إلى البنك للمراجعة. تأكد من صحتها.',
      'National ID / Iqama Number': 'رقم الهوية / الإقامة',
      'City': 'المدينة',
      'Address (optional)': 'العنوان (اختياري)',
      'Employer': 'جهة العمل',
      'Job Title': 'المسمى الوظيفي',
      'Years at Current Job': 'سنوات العمل الحالية',
      'IBAN (optional)': 'رقم الآيبان (اختياري)',
      'Notes for the bank (optional)': 'ملاحظات للبنك (اختياري)',
      'Documents': 'المستندات',
      'Upload any documents the bank may need, such as your ID, salary certificate or bank statement (PDF, JPG or PNG, up to 5 MB each).':
          'ارفع أي مستندات قد يحتاجها البنك، مثل الهوية أو شهادة الراتب أو كشف الحساب (PDF أو JPG أو PNG، بحد أقصى 5 ميغابايت لكل ملف).',
      'No documents uploaded yet.': 'لم يتم رفع أي مستندات بعد.',
      'National ID': 'الهوية الوطنية',
      'Salary Certificate': 'شهادة الراتب',
      'Bank Statement': 'كشف الحساب',
      'Other': 'أخرى',
      'Choose File': 'اختر ملفًا',
      'Open': 'فتح',
      'Remove': 'إزالة',
      'Call': 'اتصال',
      'Questions? Call the bank': 'لديك أسئلة؟ اتصل بالبنك',
      'The bank representative can also call you on the phone number saved in your profile.':
          'يمكن لممثل البنك أيضًا الاتصال بك على رقم الجوال المحفوظ في ملفك.',
      'Submit Application to the Bank': 'إرسال الطلب إلى البنك',
      'Resubmit Application': 'إعادة إرسال الطلب',
      'Your request was approved. Complete the application below and the bank will review it.':
          'تمت الموافقة على طلبك. أكمل الطلب أدناه وسيقوم البنك بمراجعته.',
      'APPLICATION APPROVED': 'تمت الموافقة على الطلب',
      'APPLICATION NOT APPROVED': 'لم تتم الموافقة على الطلب',
      'ACTION REQUIRED': 'مطلوب إجراء',
      'UNDER REVIEW': 'قيد المراجعة',
      'The bank approved your application. A bank representative will contact you to finalize the loan.':
          'وافق البنك على طلبك. سيتواصل معك ممثل البنك لإنهاء إجراءات القرض.',
      'The bank could not approve your application.':
          'لم يتمكن البنك من الموافقة على طلبك.',
      'The bank needs more information. Update your details or add documents, then resubmit.':
          'يحتاج البنك إلى معلومات إضافية. حدّث بياناتك أو أضف مستندات ثم أعد الإرسال.',
      'Your application was sent. The bank is reviewing it.':
          'تم إرسال طلبك. البنك يقوم بمراجعته.',
      'Message from the bank': 'رسالة من البنك',
      'Submitted': 'تم الإرسال',
      'Bank review': 'مراجعة البنك',
      'Decision': 'القرار',
      'Application status: Approved by the bank':
          'حالة الطلب: تمت الموافقة من البنك',
      'Application status: Not approved': 'حالة الطلب: لم تتم الموافقة',
      'Application status: The bank needs more information':
          'حالة الطلب: البنك يحتاج إلى معلومات إضافية',
      'Application status: Under review by the bank':
          'حالة الطلب: قيد المراجعة لدى البنك',
      'Waiting for the borrower to complete the loan application.':
          'بانتظار أن يكمل المقترض طلب القرض.',
      'The borrower did not upload any documents.':
          'لم يرفع المقترض أي مستندات.',
      'Approve Application': 'الموافقة على الطلب',
      'Request More Info': 'طلب معلومات إضافية',
      'Request More Information': 'طلب معلومات إضافية',
      'Send to Borrower': 'إرسال إلى المقترض',
      'Call Borrower': 'اتصل بالمقترض',
      'Cancel': 'إلغاء',
      'Reject': 'رفض',
      'Yes, Approve': 'نعم، وافق',
      'Yes, Reject': 'نعم، ارفض',
      'Reject Application': 'رفض الطلب',
      'READY FOR REVIEW': 'جاهز للمراجعة',
      'MORE INFO REQUESTED': 'تم طلب معلومات إضافية',
      'APPLICATION REJECTED': 'تم رفض الطلب',
      'Waiting for the borrower to add the requested information.':
          'بانتظار أن يضيف المقترض المعلومات المطلوبة.',
      'Tell the borrower what is missing': 'أخبر المقترض بما ينقصه',
      'Enter the reason for rejection': 'اكتب سبب الرفض',
      'Approve this loan application? The borrower will be notified to expect your contact.':
          'الموافقة على طلب القرض هذا؟ سيعرف المقترض أن البنك سيتواصل معه.',

      // Next step
      "What's the next step?": 'ما الخطوة التالية؟',
      'Next Step': 'الخطوة التالية',
      'Got it': 'حسنًا',
      'Congratulations, your loan request has been approved by the lender. '
              'To continue with the procedures and receive your loan, please visit '
              'the bank in person and complete the remaining requirements.':
          'تهانينا، تمت الموافقة على طلب قرضك من قبل جهة التمويل. '
          'لاستكمال الإجراءات واستلام القرض، يُرجى مراجعة البنك شخصيًا '
          'وإنهاء المتطلبات المتبقية.',

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
      'Submit Loan Request Through Rushd': 'إرسال طلب القرض عبر رشد',

      // Requests
      'Track your submitted loan requests.': 'تابع طلبات القروض التي أرسلتها.',
      'No submitted requests yet.': 'لا توجد طلبات مرسلة حتى الآن.',
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
      'Your lender account is pending verification by Rushd':
          'حساب جهة التمويل الخاص بك قيد التحقق من قبل رشد',
      'Your lender account is pending verification by Rushd.':
          'حساب جهة التمويل الخاص بك قيد التحقق من قبل رشد.',
      'Thank you for registering. Before you can publish loan offers and review borrower requests, the Rushd team needs to confirm your account. You will get full access as soon as it is verified.':
          'شكرًا لتسجيلك. قبل أن تتمكن من نشر عروض التمويل ومراجعة طلبات المقترضين، يحتاج فريق رشد إلى تأكيد حسابك. ستحصل على الوصول الكامل فور التحقق منه.',
      'Check Again': 'تحقق مرة أخرى',
      'Your account is still pending verification.':
          'حسابك لا يزال قيد التحقق.',

      // Errors
      'This request has already been decided':
          'تم اتخاذ قرار بشأن هذا الطلب مسبقًا',
      'This application has already been decided':
          'تم اتخاذ قرار بشأن هذا الطلب مسبقًا',
      'You do not have permission to do this.': 'ليس لديك صلاحية للقيام بذلك.',
      'File is too large. The maximum size is 5 MB.':
          'الملف كبير جدًا. الحد الأقصى للحجم 5 ميغابايت.',
      'Only PDF, JPG and PNG files are allowed.':
          'يُسمح فقط بملفات PDF و JPG و PNG.',
      'You can only upload documents to your own loan requests.':
          'يمكنك رفع المستندات لطلبات القروض الخاصة بك فقط.',

      // ===== Common =====
      'Rushd': 'رشد',
      'Menu': 'القائمة',
      'Back': 'رجوع',
      'Next': 'التالي',
      'Refresh': 'تحديث',
      'Continue': 'متابعة',
      'Edit': 'تعديل',
      'Delete': 'حذف',
      'Approve': 'موافقة',
      'Try Again': 'حاول مرة أخرى',
      'Something went wrong.': 'حدث خطأ ما.',
      'Demo only': 'للعرض التجريبي فقط',
      'Ended': 'انتهت',
      'Expired': 'منتهي',
      'd': 'ي',
      ', ': '، ',
      'Date': 'التاريخ',
      'Bank': 'البنك',
      'IBAN': 'الآيبان',
      'Address': 'العنوان',
      'Password': 'كلمة المرور',
      'Phone Number': 'رقم الجوال',
      'Mobile Number': 'رقم الجوال',
      'Email Address': 'البريد الإلكتروني',
      'Contact': 'التواصل',
      'Contact Email': 'البريد الإلكتروني للتواصل',
      'Available': 'متاح',
      'Rate': 'المعدل',
      'Term': 'المدة',
      'months': 'شهرًا',
      'minutes': 'دقيقة',
      'for': 'لمدة',
      'Step': 'الخطوة',
      'of': 'من',
      'Reason': 'السبب',
      'Reason:': 'السبب:',
      'Welcome,': 'مرحبًا،',
      'Welcome, ': 'مرحبًا، ',
      'Phone:': 'الجوال:',
      'Rate:': 'المعدل:',
      'Term:': 'المدة:',
      'Number copied:': 'تم نسخ الرقم:',
      'Could not open the document:': 'تعذر فتح المستند:',
      'Error loading dashboard:': 'خطأ في تحميل اللوحة:',
      'Error loading profile:': 'خطأ في تحميل الملف الشخصي:',
      'Error signing out:': 'خطأ في تسجيل الخروج:',
      'Error loading statistics:': 'خطأ في تحميل الإحصائيات:',
      'Error loading offers:': 'خطأ في تحميل العروض:',
      'Unexpected response from the server.': 'استجابة غير متوقعة من الخادم.',
      'Could not connect to the server. Check your internet connection.':
          'تعذر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.',
      'This record already exists.': 'هذا السجل موجود مسبقًا.',
      'Some of the values entered are not allowed.':
          'بعض القيم المدخلة غير مسموح بها.',
      'The database needs the latest Rushd update. Please run the newest migration.':
          'قاعدة البيانات تحتاج إلى آخر تحديث لرشد. يرجى تشغيل أحدث ملف ترحيل.',

      // ===== Banks =====
      'Al Rajhi Bank': 'مصرف الراجحي',
      'Riyad Bank': 'بنك الرياض',
      'Saudi National Bank': 'البنك الأهلي السعودي',
      'Bank Albilad': 'بنك البلاد',

      // ===== Home / splash =====
      'Personalized\n': 'حلول مخصصة\n',
      'Loan Solutions\n': 'للقروض\n',
      'A Smarter way to find suitable loan offers.':
          'طريقة أذكى للعثور على عروض القروض المناسبة.',

      // ===== Login & registration =====
      'Sign In': 'تسجيل الدخول',
      "Don't have an account?": 'ليس لديك حساب؟',
      'Please enter email and password':
          'يرجى إدخال البريد الإلكتروني وكلمة المرور',
      'Unable to sign in.': 'تعذر تسجيل الدخول.',
      'User profile was not found.': 'لم يتم العثور على ملف المستخدم.',
      'Unknown account type.': 'نوع الحساب غير معروف.',
      'Borrower Registration': 'تسجيل المقترض',
      'Create your borrower account': 'أنشئ حساب المقترض',
      'Bank Agent Registration': 'تسجيل ممثل البنك',
      'Create your lender account': 'أنشئ حساب جهة التمويل',
      'Lender Representative': 'ممثل جهة التمويل',
      'Represented Bank': 'البنك الذي تمثله',
      'Create New Account': 'إنشاء حساب جديد',
      'Please enter your name': 'يرجى إدخال اسمك',
      'Name must contain letters only': 'يجب أن يحتوي الاسم على حروف فقط',
      'Please enter email': 'يرجى إدخال البريد الإلكتروني',
      'Enter a valid email': 'أدخل بريدًا إلكترونيًا صحيحًا',
      'Please enter phone number': 'يرجى إدخال رقم الجوال',
      'Phone number must be 10 digits': 'يجب أن يتكون رقم الجوال من 10 أرقام',
      'Please enter mobile number': 'يرجى إدخال رقم الجوال',
      'Mobile number must be 10 digits': 'يجب أن يتكون رقم الجوال من 10 أرقام',
      'Please enter password': 'يرجى إدخال كلمة المرور',
      'Password must be at least 6 characters':
          'يجب ألا تقل كلمة المرور عن 6 أحرف',
      'Please select represented bank': 'يرجى اختيار البنك الذي تمثله',
      'Account could not be created.': 'تعذر إنشاء الحساب.',
      'Lender account could not be created.': 'تعذر إنشاء حساب جهة التمويل.',
      'Account created successfully. Please confirm your email, then sign in.':
          'تم إنشاء الحساب بنجاح. يرجى تأكيد بريدك الإلكتروني ثم تسجيل الدخول.',
      'Account created. Please confirm your email, then sign in.':
          'تم إنشاء الحساب. يرجى تأكيد بريدك الإلكتروني ثم تسجيل الدخول.',

      // Supabase sign-in messages
      'Invalid login credentials': 'بيانات الدخول غير صحيحة',
      'User already registered': 'هذا المستخدم مسجل مسبقًا',
      'Email not confirmed': 'لم يتم تأكيد البريد الإلكتروني',
      'Password should be at least 6 characters':
          'يجب ألا تقل كلمة المرور عن 6 أحرف',
      'Password should be at least 6 characters.':
          'يجب ألا تقل كلمة المرور عن 6 أحرف.',
      'Unable to validate email address: invalid format':
          'تعذر التحقق من البريد الإلكتروني: صيغة غير صحيحة',
      'Email rate limit exceeded':
          'تم تجاوز حد إرسال الرسائل. حاول مرة أخرى لاحقًا.',

      // ===== Borrower dashboard & loan type =====
      'Continue your loan journey, compare suitable offers, and track requests submitted through Rushd.':
          'أكمل رحلة قرضك، وقارن العروض المناسبة، وتابع الطلبات المرسلة عبر رشد.',
      'Personal, business, or investment loan.':
          'قرض شخصي أو تجاري أو استثماري.',
      'Update your financial information.': 'حدّث بياناتك المالية.',
      'Compare available loan offers.': 'قارن عروض القروض المتاحة.',
      'See pending, approved, or rejected requests.':
          'اطّلع على الطلبات المعلقة أو المقبولة أو المرفوضة.',
      'Review saved contact and financial information.':
          'راجع بيانات التواصل والبيانات المالية المحفوظة.',
      'This helps Rushd show relevant offers and recommendations.':
          'يساعد ذلك رشد على عرض العروض والتوصيات المناسبة.',
      'For individual financing needs.': 'لاحتياجات التمويل الفردية.',
      'For small businesses and business owners.':
          'للمنشآت الصغيرة وأصحاب الأعمال.',
      'For users seeking financing for investment purposes.':
          'لمن يبحث عن تمويل لأغراض استثمارية.',

      // ===== Profile & assessment =====
      'User is not signed in.': 'المستخدم لم يسجل الدخول.',
      'Financial information saved and ready for loan assessment.':
          'تم حفظ البيانات المالية وهي جاهزة لتقييم القرض.',
      'Complete your financial assessment to save your profile.':
          'أكمل تقييمك المالي لحفظ ملفك.',
      'Please enter a valid monthly income.': 'يرجى إدخال دخل شهري صحيح.',
      'Please enter valid existing debts.': 'يرجى إدخال ديون حالية صحيحة.',
      'Please enter valid monthly expenses.': 'يرجى إدخال مصروفات شهرية صحيحة.',
      'Please enter a valid desired loan amount.': 'يرجى إدخال مبلغ قرض صحيح.',
      'You must sign in before saving the assessment.':
          'يجب تسجيل الدخول قبل حفظ التقييم.',
      'Financial information saved successfully.':
          'تم حفظ البيانات المالية بنجاح.',
      'Selected type:': 'النوع المختار:',

      // ===== Loan analysis & offer details =====
      'Refresh Offers': 'تحديث العروض',
      'Requested Amount': 'المبلغ المطلوب',
      'Rushd Loan Recommendations': 'توصيات رشد للقروض',
      'Offers are retrieved from the banks shown (sample data) and filtered according to your selected loan type and requested amount.':
          'يتم جلب العروض من البنوك المعروضة (بيانات تجريبية) وتصفيتها حسب نوع القرض والمبلغ المطلوب.',
      'Available Offers': 'العروض المتاحة',
      'Max Amount': 'الحد الأقصى للمبلغ',
      'Eligibility Analysis': 'تحليل الأهلية',
      'Eligibility Score': 'درجة الأهلية',
      'Classification': 'التصنيف',
      'Monthly Installment': 'القسط الشهري',
      'Installment Ratio': 'نسبة القسط',
      'DTI': 'نسبة الدين إلى الدخل',
      'Highly Suitable': 'مناسب جدًا',
      'Suitable': 'مناسب',
      'Moderately Suitable': 'مناسب إلى حد ما',
      'Not Suitable': 'غير مناسب',
      'This offer matches your selected loan type and requested amount. The eligibility result is a preliminary suitability indicator.':
          'يتوافق هذا العرض مع نوع القرض والمبلغ المطلوب. نتيجة الأهلية مؤشر أولي للملاءمة.',
      'This offer matches your selected loan type and supports your requested amount.':
          'يتوافق هذا العرض مع نوع القرض ويدعم المبلغ المطلوب.',
      'No matching offers found.': 'لم يتم العثور على عروض مطابقة.',
      'Unable to load offers.': 'تعذر تحميل العروض.',
      'Requested amount is not available.': 'المبلغ المطلوب غير متوفر.',
      'Loan request submitted successfully.': 'تم إرسال طلب القرض بنجاح.',
      'Offer information is not available.': 'معلومات العرض غير متوفرة.',
      'Interest Rate': 'معدل الربح',
      'Maximum Term': 'أقصى مدة',
      'Maximum Amount': 'الحد الأقصى للمبلغ',
      'Loan Type': 'نوع القرض',
      'This eligibility result is a preliminary suitability indicator and does not represent final loan approval.':
          'نتيجة الأهلية هذه مؤشر أولي للملاءمة ولا تمثل موافقة نهائية على القرض.',
      'This result is a preliminary suitability indicator and does not represent final loan approval.':
          'هذه النتيجة مؤشر أولي للملاءمة ولا تمثل موافقة نهائية على القرض.',
      'The eligibility result is a preliminary decision-support indicator and does not represent final loan approval.':
          'نتيجة الأهلية مؤشر أولي لدعم القرار ولا تمثل موافقة نهائية على القرض.',
      'Eligibility could not be calculated for this offer.':
          'تعذر حساب الأهلية لهذا العرض.',
      'Offer Details': 'تفاصيل العرض',
      'Financing offer from': 'عرض تمويل من',
      'Maximum term': 'أقصى مدة',
      'Maximum financing': 'أقصى تمويل',
      'Submit Request': 'إرسال الطلب',
      'Loan Offer': 'عرض القرض',
      'Eligibility': 'الأهلية',
      'Interest Rate:': 'معدل الربح:',
      'Maximum Term:': 'أقصى مدة:',
      'Score:': 'الدرجة:',
      'Classification:': 'التصنيف:',
      'Monthly Installment:': 'القسط الشهري:',
      'DTI:': 'نسبة الدين إلى الدخل:',
      'Installment Ratio:': 'نسبة القسط:',
      'Offer information is incomplete.': 'معلومات العرض غير مكتملة.',
      'Borrower is not signed in.': 'المقترض لم يسجل الدخول.',
      'Invalid request status.': 'حالة الطلب غير صالحة.',
      'Invalid application status.': 'حالة طلب التمويل غير صالحة.',

      // ===== Request status =====
      'Unable to load requests.': 'تعذر تحميل الطلبات.',
      'Choose a loan offer and submit it to track it here.':
          'اختر عرض قرض وأرسله لتتابعه هنا.',
      'APPROVED': 'مقبول',
      'REJECTED': 'مرفوض',
      'PENDING': 'قيد الانتظار',
      'Your loan request has been approved by the lender.':
          'تمت الموافقة على طلب قرضك من قبل جهة التمويل.',
      'Your loan request was not approved by the lender.':
          'لم تتم الموافقة على طلب قرضك من قبل جهة التمويل.',
      'Your request is currently under review by the lender.':
          'طلبك قيد المراجعة حاليًا لدى جهة التمويل.',
      'Request': 'الطلب',
      'Application': 'طلب التمويل',
      'Offer': 'العرض',
      'Signing': 'التوقيع',
      'Cooling-off': 'فترة التراجع',
      'Active': 'نشط',
      'Waiting for the lender to review your request':
          'بانتظار مراجعة جهة التمويل لطلبك',
      'Request not approved': 'لم تتم الموافقة على الطلب',
      'Request approved — complete your application':
          'تمت الموافقة على الطلب — أكمل طلب التمويل',
      'Application under review by the bank': 'طلب التمويل قيد مراجعة البنك',
      'The bank needs more information': 'البنك يحتاج إلى معلومات إضافية',
      'Application not approved': 'لم تتم الموافقة على طلب التمويل',
      'Application approved — waiting for the final offer':
          'تمت الموافقة على طلب التمويل — بانتظار العرض النهائي',
      'Your final offer is ready': 'عرضك النهائي جاهز',
      'You declined the offer': 'لقد رفضت العرض',
      'The offer expired': 'انتهت صلاحية العرض',
      'Offer accepted — sign the agreement': 'تم قبول العرض — وقّع الاتفاقية',
      'Agreement signed — cooling-off period':
          'تم توقيع الاتفاقية — فترة التراجع',
      'Financing active': 'التمويل نشط',
      'Withdrawn from the agreement': 'تم الانسحاب من الاتفاقية',

      // ===== Loan application (4 steps) =====
      'Identity': 'الهوية',
      'Employment & income': 'العمل والدخل',
      'Review & consents': 'المراجعة والإقرارات',
      '3-Month Bank Statement': 'كشف حساب لآخر 3 أشهر',
      'Government': 'حكومي',
      'Private sector': 'قطاع خاص',
      'Military': 'عسكري',
      'Retired': 'متقاعد',
      'Use test data — do not enter your real ID or IBAN.':
          'استخدم بيانات تجريبية — لا تُدخل رقم هويتك أو الآيبان الحقيقي.',
      'Please enter your full name.': 'يرجى إدخال اسمك الكامل.',
      'National ID / Iqama number must be 10 digits and start with 1 or 2.':
          'يجب أن يتكون رقم الهوية / الإقامة من 10 أرقام ويبدأ بـ 1 أو 2.',
      'Please enter your date of birth.': 'يرجى إدخال تاريخ ميلادك.',
      'You must be at least 18 years old.': 'يجب ألا يقل عمرك عن 18 عامًا.',
      'Please enter your city.': 'يرجى إدخال مدينتك.',
      'Please verify your identity first.': 'يرجى التحقق من هويتك أولًا.',
      'Please enter your employer.': 'يرجى إدخال جهة عملك.',
      'Please choose your employment sector.': 'يرجى اختيار قطاع عملك.',
      'Years at current job must be a number.':
          'يجب أن تكون سنوات العمل الحالية رقمًا.',
      'Add your monthly salary to your profile first.':
          'أضف راتبك الشهري إلى ملفك أولًا.',
      'IBAN must be SA followed by 22 digits (24 characters).':
          'يجب أن يبدأ الآيبان بـ SA متبوعًا بـ 22 رقمًا (24 خانة).',
      'Please upload:': 'يرجى رفع:',
      'Date of birth': 'تاريخ الميلاد',
      'Select date': 'اختر التاريخ',
      'Could not read the selected file.': 'تعذرت قراءة الملف المحدد.',
      'Application sent to the bank for review.':
          'تم إرسال الطلب إلى البنك للمراجعة.',
      'Unable to load the application.': 'تعذر تحميل الطلب.',
      'Identity verified (simulated)': 'تم التحقق من الهوية (محاكاة)',
      'Verifying…': 'جارٍ التحقق…',
      'Verify identity (simulated)': 'التحقق من الهوية (محاكاة)',
      'In a live service this step uses the national digital-identity platform.':
          'في الخدمة الفعلية تتم هذه الخطوة عبر منصة الهوية الرقمية الوطنية.',
      'Employment sector': 'قطاع العمل',
      'Monthly salary': 'الراتب الشهري',
      'Not set': 'غير محدد',
      'Update profile': 'تحديث الملف',
      'Salary account IBAN': 'آيبان حساب الراتب',
      'SA followed by 22 digits (24 characters). The financing is paid into this account.':
          'SA متبوعًا بـ 22 رقمًا (24 خانة). يُودَع التمويل في هذا الحساب.',
      'PDF, JPG or PNG, up to 5 MB each.':
          'PDF أو JPG أو PNG، بحد أقصى 5 ميغابايت لكل ملف.',
      'Missing': 'غير مرفوع',
      'Uploaded': 'تم الرفع',
      'Accepted': 'مقبول',
      'Needs re-upload': 'يحتاج إعادة رفع',
      'Tap to choose a file': 'اضغط لاختيار ملف',
      'Add another file': 'إضافة ملف آخر',
      'Other documents': 'مستندات أخرى',
      'Consents': 'الإقرارات',
      'I consent to a credit-bureau check (simulated)':
          'أوافق على الاستعلام من شركة المعلومات الائتمانية (محاكاة)',
      'The information I gave is accurate': 'المعلومات التي قدمتها صحيحة',
      'I understand this is a simulation': 'أفهم أن هذه محاكاة',
      'Identity check': 'التحقق من الهوية',
      'Verified (simulated)': 'تم التحقق (محاكاة)',
      'Not verified': 'لم يتم التحقق',
      'Files': 'الملفات',
      'Continue to your financing offer': 'تابع إلى عرض التمويل',
      'The bank approved your application. Your final financing offer will appear here.':
          'وافق البنك على طلبك. سيظهر عرض التمويل النهائي هنا.',
      'has not added a phone number yet.': 'لم يضف رقم جوال بعد.',

      // ===== Financing offer / Key Facts Statement =====
      'Your final offer': 'عرضك النهائي',
      'Unable to load the offer.': 'تعذر تحميل العرض.',
      'No offer yet': 'لا يوجد عرض بعد',
      'The bank has not issued a financing offer for this application yet.':
          'لم يُصدر البنك عرض تمويل لهذا الطلب بعد.',
      'This is a simulated offer for a graduation project. No real financing is provided.':
          'هذا عرض محاكاة لمشروع تخرج. لا يتم تقديم تمويل حقيقي.',
      'Offer accepted': 'تم قبول العرض',
      'You accepted this offer. Continue to sign the agreement.':
          'لقد قبلت هذا العرض. تابع لتوقيع الاتفاقية.',
      'Offer declined': 'تم رفض العرض',
      'You declined this offer. The bank may send you a new one.':
          'لقد رفضت هذا العرض. قد يرسل لك البنك عرضًا جديدًا.',
      'Offer expired': 'انتهت صلاحية العرض',
      'This offer is no longer valid. Ask the bank for a new offer.':
          'هذا العرض لم يعد صالحًا. اطلب من البنك عرضًا جديدًا.',
      'Offer closed': 'العرض مغلق',
      'View progress': 'عرض التقدم',
      'Monthly installment': 'القسط الشهري',
      'Flat rate': 'ربح ثابت',
      'Reducing balance': 'رصيد متناقص',
      'Tawarruq-based personal finance (simulated)':
          'تمويل شخصي بصيغة التورق (محاكاة)',
      'Valid for': 'صالح لمدة',
      'minutes (demo mode)': 'دقيقة (وضع العرض التجريبي)',
      'business days after signing': 'أيام عمل بعد التوقيع',
      'Key Facts Statement — ملخص المعلومات الأساسية':
          'ملخص المعلومات الأساسية — Key Facts Statement',
      'Financed amount': 'مبلغ التمويل',
      'Profit rate': 'معدل الربح',
      '(flat)': '(ثابت)',
      '(reducing balance)': '(رصيد متناقص)',
      'Annual percentage rate (APR)': 'معدل النسبة السنوي (APR)',
      'Admin fee': 'الرسوم الإدارية',
      'Amount paid into your account': 'المبلغ المودع في حسابك',
      'Total profit': 'إجمالي الربح',
      'Total repayable': 'إجمالي المبلغ المستحق',
      'First installment (estimated)': 'القسط الأول (تقديري)',
      'Last installment (estimated)': 'القسط الأخير (تقديري)',
      'Debt burden ratio': 'نسبة عبء الدين',
      'Offer valid until': 'العرض صالح حتى',
      'Early settlement': 'السداد المبكر',
      'You may repay the whole amount early at any time. Profit for the remaining period is not charged; the bank may only ask for a limited compensation allowed by SAMA rules (simulated).':
          'يمكنك سداد كامل المبلغ مبكرًا في أي وقت. لا يُحتسب الربح عن المدة المتبقية، ويجوز للبنك طلب تعويض محدود فقط وفق قواعد البنك المركزي السعودي (محاكاة).',
      'Cooling-off right': 'حق التراجع',
      'After you sign, you can withdraw from the agreement without penalty within':
          'بعد التوقيع، يمكنك الانسحاب من الاتفاقية دون أي غرامة خلال',
      'Total repayable = all monthly installments + the admin fee. The admin fee is deducted from the amount paid into your account.':
          'إجمالي المبلغ المستحق = جميع الأقساط الشهرية + الرسوم الإدارية. تُخصم الرسوم الإدارية من المبلغ المودع في حسابك.',
      'Full repayment schedule': 'جدول السداد الكامل',
      'Estimated dates; the final schedule starts when the funds are released.':
          'تواريخ تقديرية؛ يبدأ الجدول النهائي عند صرف المبلغ.',
      'No schedule yet.': 'لا يوجد جدول بعد.',
      '#': '#',
      'Due date': 'تاريخ الاستحقاق',
      'Principal': 'الأصل',
      'Profit': 'الربح',
      'Installment': 'القسط',
      'Remaining': 'المتبقي',
      'Decline': 'رفض',
      'Accept offer': 'قبول العرض',
      'Decline offer': 'رفض العرض',
      'Please tell the bank why you are declining this offer.':
          'يرجى إخبار البنك بسبب رفضك لهذا العرض.',
      'Please write a reason first.': 'يرجى كتابة السبب أولًا.',
      'You declined the offer.': 'لقد رفضت العرض.',
      'Offer accepted. Please sign the agreement.':
          'تم قبول العرض. يرجى توقيع الاتفاقية.',
      'Before you accept': 'قبل أن تقبل',
      'Please confirm the following to accept the offer.':
          'يرجى تأكيد ما يلي لقبول العرض.',
      'I have read the Key Facts Statement and the terms':
          'قرأت ملخص المعلومات الأساسية والشروط',
      'I understand this is a simulation and no real financing is provided':
          'أفهم أن هذه محاكاة ولا يتم تقديم تمويل حقيقي',
      'I agree that Rushd shares my application with this bank':
          'أوافق على أن يشارك رشد طلبي مع هذا البنك',
      'Optional: release the funds before the cooling-off period ends':
          'اختياري: صرف المبلغ قبل انتهاء فترة التراجع',
      'Some banks allow early release. If the funds are released early, you can no longer withdraw from the agreement.':
          'تسمح بعض البنوك بالصرف المبكر. إذا صُرف المبلغ مبكرًا فلن تتمكن من الانسحاب من الاتفاقية.',

      // ===== Signing & cooling-off =====
      'Sign your agreement': 'وقّع اتفاقيتك',
      'Unable to load the agreement.': 'تعذر تحميل الاتفاقية.',
      'Accept an offer first to create your agreement.':
          'اقبل عرضًا أولًا لإنشاء اتفاقيتك.',
      'Agreement summary': 'ملخص الاتفاقية',
      'Reference number': 'الرقم المرجعي',
      'Offer accepted on': 'تاريخ قبول العرض',
      'Signed on': 'تاريخ التوقيع',
      'Early release of funds': 'الصرف المبكر للمبلغ',
      'Allowed by you': 'مسموح من قبلك',
      'Not allowed': 'غير مسموح',
      'Sign with a one-time code': 'التوقيع برمز لمرة واحدة',
      'We send a 6-digit code to the phone number in your profile. Enter it to sign the agreement electronically.':
          'نرسل رمزًا من 6 أرقام إلى رقم الجوال في ملفك. أدخله لتوقيع الاتفاقية إلكترونيًا.',
      'Send signing code': 'إرسال رمز التوقيع',
      'Your signing code is': 'رمز التوقيع الخاص بك هو',
      'In a live service it is sent by SMS and valid for 5 minutes.':
          'في الخدمة الفعلية يُرسل برسالة نصية ويكون صالحًا لمدة 5 دقائق.',
      'Sign agreement': 'توقيع الاتفاقية',
      'Send a new code': 'إرسال رمز جديد',
      'Attempts left:': 'المحاولات المتبقية:',
      'Agreement signed': 'تم توقيع الاتفاقية',
      'Signed electronically with a one-time code (simulated).':
          'تم التوقيع إلكترونيًا برمز لمرة واحدة (محاكاة).',
      'Cooling-off period': 'فترة التراجع',
      'You can withdraw from this agreement without any penalty until the time below. After that, the bank can release the funds.':
          'يمكنك الانسحاب من هذه الاتفاقية دون أي غرامة حتى الوقت المحدد أدناه. بعد ذلك يمكن للبنك صرف المبلغ.',
      'The cooling-off period has ended. The bank can now release the funds to your account.':
          'انتهت فترة التراجع. يمكن للبنك الآن صرف المبلغ إلى حسابك.',
      'Demo mode: the cooling-off period is shortened to':
          'وضع العرض التجريبي: تم تقصير فترة التراجع إلى',
      'You allowed early release, so the bank may release the funds before this period ends.':
          'لقد سمحت بالصرف المبكر، لذا قد يصرف البنك المبلغ قبل انتهاء هذه الفترة.',
      'Time left to withdraw': 'الوقت المتبقي للانسحاب',
      'Ended on': 'انتهت في',
      'Withdraw from agreement': 'الانسحاب من الاتفاقية',
      'You are within the cooling-off period, so you can withdraw without penalty. The agreement will be cancelled and no funds will be released. Continue?':
          'أنت ضمن فترة التراجع، لذا يمكنك الانسحاب دون غرامة. سيتم إلغاء الاتفاقية ولن يُصرف أي مبلغ. هل تريد المتابعة؟',
      'Yes, withdraw': 'نعم، انسحب',
      'You withdrew from the agreement.': 'لقد انسحبت من الاتفاقية.',
      'You withdrew from this agreement': 'لقد انسحبت من هذه الاتفاقية',
      'The agreement was cancelled during the cooling-off period. No funds were released.':
          'تم إلغاء الاتفاقية خلال فترة التراجع. لم يُصرف أي مبلغ.',
      'The funds were released (simulated). See your repayment schedule in the progress page.':
          'تم صرف المبلغ (محاكاة). اطّلع على جدول السداد في صفحة التقدم.',

      // ===== Financing progress =====
      'Financing progress': 'تقدم التمويل',
      'Unable to load your financing.': 'تعذر تحميل بيانات التمويل.',
      'No application yet': 'لا يوجد طلب بعد',
      'Complete your loan application to start the financing journey.':
          'أكمل طلب القرض لبدء رحلة التمويل.',
      'Start application': 'ابدأ الطلب',
      'Timeline': 'المراحل',
      'Repayment schedule': 'جدول السداد',
      'This journey is a simulation. No real money is sent and no real contract is signed.':
          'هذه الرحلة محاكاة. لا يتم إرسال أموال حقيقية ولا توقيع عقد حقيقي.',
      'Application approved': 'تمت الموافقة على الطلب',
      'Offer issued': 'تم إصدار العرض',
      'Waiting for the bank to send your final offer.':
          'بانتظار أن يرسل البنك عرضك النهائي.',
      'Offer version': 'إصدار العرض',
      'Reference': 'المرجع',
      'Signed': 'تم التوقيع',
      'Ends': 'تنتهي',
      'Disbursed': 'تم الصرف',
      'In progress': 'قيد التنفيذ',
      'Not started': 'لم تبدأ',
      'Disbursement receipt': 'إيصال الصرف',
      'Rushd — disbursement receipt (simulated)': 'رشد — إيصال الصرف (محاكاة)',
      'Admin fee deducted': 'الرسوم الإدارية المخصومة',
      'Copy receipt': 'نسخ الإيصال',
      'Receipt copied.': 'تم نسخ الإيصال.',
      'Next installment': 'القسط القادم',
      'Due on': 'يستحق في',

      // ===== Lender side =====
      'Lender Representative Dashboard': 'لوحة ممثل جهة التمويل',
      'Active Offers': 'العروض النشطة',
      'Bank Requests': 'طلبات البنك',
      'Average Rate': 'متوسط المعدل',
      "Edit, update, or delete your bank's offers.":
          'عدّل أو حدّث أو احذف عروض بنكك.',
      'Check borrower applications.': 'راجع طلبات المقترضين.',
      'Add New Offer': 'إضافة عرض جديد',
      'Add New Loan Offer': 'إضافة عرض قرض جديد',
      'Edit Loan Offer': 'تعديل عرض القرض',
      'Offer Name': 'اسم العرض',
      'Please select loan type': 'يرجى اختيار نوع القرض',
      'Please select a loan type.': 'يرجى اختيار نوع القرض.',
      'Interest Rate (%)': 'معدل الربح (%)',
      'Max Term (Months)': 'أقصى مدة (بالأشهر)',
      'Maximum Amount (SAR)': 'الحد الأقصى للمبلغ (ر.س)',
      'Create Offer': 'إنشاء العرض',
      'Save Changes': 'حفظ التغييرات',
      'This field is required': 'هذا الحقل مطلوب',
      'Please enter a valid interest rate.': 'يرجى إدخال معدل ربح صحيح.',
      'Please enter a valid repayment term.': 'يرجى إدخال مدة سداد صحيحة.',
      'Please enter a valid maximum amount.': 'يرجى إدخال حد أقصى صحيح للمبلغ.',
      'Offer created successfully.': 'تم إنشاء العرض بنجاح.',
      'Offer updated successfully.': 'تم تحديث العرض بنجاح.',
      'Delete Offer': 'حذف العرض',
      'Are you sure you want to delete this offer?':
          'هل أنت متأكد من حذف هذا العرض؟',
      'Offer deleted:': 'تم حذف العرض:',
      'No offers available.': 'لا توجد عروض متاحة.',
      'Lender is not signed in.': 'جهة التمويل لم تسجل الدخول.',
      'Bank name was not found for this lender.':
          'لم يتم العثور على اسم البنك لجهة التمويل هذه.',
      'New Requests:': 'الطلبات الجديدة:',
      'Borrower Financial Information': 'البيانات المالية للمقترض',
      'Current Monthly Obligations': 'الالتزامات الشهرية الحالية',
      'Approve Request': 'الموافقة على الطلب',
      'Are you sure you want to approve this request?':
          'هل أنت متأكد من الموافقة على هذا الطلب؟',
      'Reject Request': 'رفض الطلب',
      'Rejection Reason': 'سبب الرفض',
      'Please enter a rejection reason.': 'يرجى إدخال سبب الرفض.',
      'Request approved successfully.': 'تمت الموافقة على الطلب بنجاح.',
      'Request rejected.': 'تم رفض الطلب.',
      'Application approved.': 'تمت الموافقة على الطلب.',
      'Application rejected.': 'تم رفض الطلب.',
      'Request for more information sent to the borrower.':
          'تم إرسال طلب معلومات إضافية إلى المقترض.',
      'Please write a message first.': 'يرجى كتابة رسالة أولًا.',
      'National ID / Iqama': 'الهوية / الإقامة',
      'Notes from the borrower': 'ملاحظات من المقترض',
      'No phone number saved for this borrower.':
          'لا يوجد رقم جوال محفوظ لهذا المقترض.',
      'Borrower phone:': 'جوال المقترض:',
      'Your message:': 'رسالتك:',

      // ===== Database rules (shown through friendlyError) =====
      'You must sign in first.': 'يجب تسجيل الدخول أولًا.',
      'Application not found.': 'لم يتم العثور على الطلب.',
      'An offer can only be issued for an approved application.':
          'لا يمكن إصدار عرض إلا لطلب تمت الموافقة عليه.',
      'This application already has a live financing offer.':
          'يوجد لهذا الطلب عرض تمويل قائم بالفعل.',
      'Rate type must be flat or reducing.':
          'يجب أن يكون نوع الربح ثابتًا أو متناقصًا.',
      'The amount must be greater than zero.':
          'يجب أن يكون المبلغ أكبر من صفر.',
      'The profit rate must be between 0 and 100 percent.':
          'يجب أن يكون معدل الربح بين 0 و100٪.',
      'The admin fee cannot be negative.':
          'لا يمكن أن تكون الرسوم الإدارية سالبة.',
      "The borrower's monthly income is missing, so the Debt Burden Ratio cannot be checked.":
          'الدخل الشهري للمقترض غير موجود، لذا لا يمكن التحقق من نسبة عبء الدين.',
      'Financing offer not found.': 'لم يتم العثور على عرض التمويل.',
      'This offer is no longer open.': 'هذا العرض لم يعد متاحًا.',
      'This offer has expired. Ask the bank for a new offer.':
          'انتهت صلاحية هذا العرض. اطلب من البنك عرضًا جديدًا.',
      'Please accept all the required consents.':
          'يرجى الموافقة على جميع الإقرارات المطلوبة.',
      'Agreement not found.': 'لم يتم العثور على الاتفاقية.',
      'This agreement is not waiting for a signature.':
          'هذه الاتفاقية لا تنتظر التوقيع.',
      'Please request a signing code first.': 'يرجى طلب رمز التوقيع أولًا.',
      'The signing code has expired. Please request a new code.':
          'انتهت صلاحية رمز التوقيع. يرجى طلب رمز جديد.',
      'Too many incorrect attempts. Please request a new code.':
          'محاولات خاطئة كثيرة. يرجى طلب رمز جديد.',
      'Incorrect code.': 'الرمز غير صحيح.',
      'You can only withdraw during the cooling-off period.':
          'يمكنك الانسحاب خلال فترة التراجع فقط.',
      'Funds can only be released for a signed agreement in its cooling-off period.':
          'لا يمكن صرف المبلغ إلا لاتفاقية موقّعة في فترة التراجع.',
      'The borrower has not provided a valid Saudi IBAN (SA followed by 22 digits).':
          'لم يقدّم المقترض رقم آيبان سعوديًا صحيحًا (SA متبوعًا بـ 22 رقمًا).',
      'Role, bank and verification status can only be changed by the platform administrator':
          'لا يمكن تغيير الدور أو البنك أو حالة التحقق إلا من قبل مسؤول المنصة',
      'An offer cannot be moved to another lender':
          'لا يمكن نقل العرض إلى جهة تمويل أخرى',
      'Only the assigned lender can update this request':
          'يمكن لجهة التمويل المعنية فقط تحديث هذا الطلب',
      'Only the decision and rejection reason can be changed':
          'يمكن تغيير القرار وسبب الرفض فقط',
      'Invalid decision': 'قرار غير صالح',
      'Application ownership fields cannot be changed':
          'لا يمكن تغيير بيانات ملكية الطلب',
      "Lenders cannot edit the applicant's details":
          'لا يمكن لجهة التمويل تعديل بيانات مقدم الطلب',
      'Only the lender can write the lender message':
          'يمكن لجهة التمويل فقط كتابة رسالتها',
      'Borrower financial profile was not found':
          'لم يتم العثور على الملف المالي للمقترض',
      'Loan offer was not found': 'لم يتم العثور على عرض القرض',
      'Loan offer is not active': 'عرض القرض غير نشط',
      'Lender does not match the selected offer':
          'جهة التمويل لا تطابق العرض المختار',
      'Loan type does not match the selected offer':
          'نوع القرض لا يطابق العرض المختار',
      'Requested amount exceeds the offer maximum amount':
          'المبلغ المطلوب يتجاوز الحد الأقصى للعرض',
      'Monthly income must be greater than zero':
          'يجب أن يكون الدخل الشهري أكبر من صفر',
      'Monthly income must be greater than zero.':
          'يجب أن يكون الدخل الشهري أكبر من صفر.',
      'Monthly obligations cannot be negative':
          'لا يمكن أن تكون الالتزامات الشهرية سالبة',
      'Current monthly obligations cannot be negative.':
          'لا يمكن أن تكون الالتزامات الشهرية الحالية سالبة.',
      'Loan amount must be greater than zero':
          'يجب أن يكون مبلغ القرض أكبر من صفر',
      'Loan amount must be greater than zero.':
          'يجب أن يكون مبلغ القرض أكبر من صفر.',
      'Interest rate cannot be negative': 'لا يمكن أن يكون معدل الربح سالبًا',
      'Interest rate cannot be negative.': 'لا يمكن أن يكون معدل الربح سالبًا.',
      'Loan term must be greater than zero':
          'يجب أن تكون مدة القرض أكبر من صفر',
      'Repayment period must be greater than zero.':
          'يجب أن تكون مدة السداد أكبر من صفر.',
      'The amount must be greater than zero': 'يجب أن يكون المبلغ أكبر من صفر',
      'The profit rate cannot be negative': 'لا يمكن أن يكون معدل الربح سالبًا',
      'The term must be greater than zero': 'يجب أن تكون المدة أكبر من صفر',
      'Rate type must be flat or reducing':
          'يجب أن يكون نوع الربح ثابتًا أو متناقصًا',
      'The APR cannot be calculated for these values':
          'لا يمكن حساب معدل النسبة السنوي لهذه القيم',
      'The admin fee cannot be negative':
          'لا يمكن أن تكون الرسوم الإدارية سالبة',
      'The admin fee must be less than the amount':
          'يجب أن تكون الرسوم الإدارية أقل من المبلغ',
    };

    if (m.containsKey(value)) {
      return m[value]!;
    }

    // Not an exact key (e.g. a sentence with a name or number inside):
    // replace the known phrases it contains, longest first, as whole words.
    // Single words are only translated on an exact match, so names typed
    // by users (offer names, cities) are not half-translated.
    var out = value;

    final phrases =
        m.keys
            .where((k) => !_singleWord.hasMatch(k) && value.contains(k))
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in phrases) {
      out = out.replaceAll(
        RegExp('(?<![A-Za-z])${RegExp.escape(key)}(?![A-Za-z])'),
        m[key]!,
      );
    }

    return out;
  }

  static final RegExp _singleWord = RegExp(r'^[A-Za-z]+$');
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
      return s.copyWith(color: const Color(0xff202033));
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
      ? Colors.white.withValues(alpha: .085)
      : Colors.white.withValues(alpha: .90);

  static Color get border => AppSettings.instance.isDark
      ? Colors.white.withValues(alpha: .08)
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
        if (child is TextSpan) {
          return _translateSpan(child);
        }
        return child;
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(text: _translateSpan(text), textAlign: textAlign);
  }
}
