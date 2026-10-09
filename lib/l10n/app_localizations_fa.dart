// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appName => 'ورق';

  @override
  String get library => 'کتابخانه';

  @override
  String get settings => 'تنظیمات';

  @override
  String get addBook => 'افزودن کتاب';

  @override
  String get continueReading => 'ادامهٔ خواندن';

  @override
  String get allBooks => 'همهٔ کتاب‌ها';

  @override
  String get emptyLibraryTitle => 'هنوز کتابی اضافه نشده';

  @override
  String get emptyLibraryBody =>
      'یک فایل PDF، EPUB، Markdown، HTML یا متنی اضافه کن؛ هر بار از همان‌جایی باز می‌شود که بسته بودی.';

  @override
  String pageOf(String page, String count) {
    return 'صفحهٔ $page از $count';
  }

  @override
  String get notStarted => 'شروع نشده';

  @override
  String get remove => 'حذف از کتابخانه';

  @override
  String get removeTitle => 'این کتاب حذف شود؟';

  @override
  String removeBody(String title) {
    return '«$title» و موقعیت خواندنش از این دستگاه پاک می‌شود. فایل اصلی که وارد کرده بودی سر جایش می‌ماند.';
  }

  @override
  String get cancel => 'انصراف';

  @override
  String get importing => 'در حال افزودن…';

  @override
  String importFailed(String name) {
    return '«$name» اضافه نشد. مطمئن شو فایل سالم است و یکی از این‌هاست: PDF، EPUB، Markdown، HTML، متن.';
  }

  @override
  String alreadyInLibrary(String title) {
    return '«$title» از قبل در کتابخانه هست.';
  }

  @override
  String get bookFileMissing =>
      'فایل این کتاب روی دستگاه نیست. حذفش کن و دوباره اضافه کن.';

  @override
  String get appearance => 'ظاهر';

  @override
  String get lookLight => 'روشن';

  @override
  String get lookPaper => 'کاغذی';

  @override
  String get lookDark => 'تیره';

  @override
  String get lookBlack => 'سیاه';

  @override
  String get language => 'زبان';

  @override
  String get languageSystem => 'زبان سیستم';

  @override
  String get pageColor => 'رنگ صفحه';

  @override
  String get pageColorHint => 'برای همین کتاب ذخیره می‌شود.';

  @override
  String get paperOriginal => 'اصلی';

  @override
  String get paperPaper => 'کاغذی';

  @override
  String get paperSepia => 'سپیا';

  @override
  String get paperGreen => 'سبز';

  @override
  String get paperGray => 'خاکستری';

  @override
  String get paperDark => 'تیره';

  @override
  String get paperBlack => 'سیاه';

  @override
  String get strength => 'شدت';

  @override
  String get contrast => 'کنتراست';

  @override
  String get zoomIn => 'بزرگ‌نمایی';

  @override
  String get zoomOut => 'کوچک‌نمایی';

  @override
  String get back => 'بازگشت';

  @override
  String get notes => 'یادداشت‌ها';

  @override
  String get search => 'جست‌وجو';

  @override
  String get searchHint => 'جست‌وجو در کتاب‌ها، هایلایت‌ها و یادداشت‌ها';

  @override
  String get searchEmptyTitle => 'جست‌وجو در همه‌چیز';

  @override
  String get searchEmptyBody =>
      'یک کلمه بنویس تا عنوان کتاب‌ها، جمله‌های هایلایت‌شده و یادداشت‌هایت پیدا شود.';

  @override
  String noResults(String query) {
    return 'برای «$query» چیزی پیدا نشد.';
  }

  @override
  String get books => 'کتاب‌ها';

  @override
  String get highlights => 'هایلایت‌ها';

  @override
  String get recent => 'اخیراً خوانده‌شده';

  @override
  String get newNote => 'یادداشت تازه';

  @override
  String get noNotesTitle => 'هنوز یادداشتی نیست';

  @override
  String get noNotesBody =>
      'یک فکر را بنویس. خط اول عنوان می‌شود و Markdown هم کار می‌کند.';

  @override
  String get noteHint => 'خط اول عنوان، بعد یادداشت…';

  @override
  String get untitled => 'بدون عنوان';

  @override
  String get deleteNote => 'حذف یادداشت';

  @override
  String get deleteNoteTitle => 'این یادداشت حذف شود؟';

  @override
  String deleteNoteBody(String title) {
    return '«$title» از این دستگاه پاک می‌شود.';
  }

  @override
  String get delete => 'حذف';

  @override
  String get done => 'تمام';

  @override
  String get preview => 'پیش‌نمایش';

  @override
  String get edit => 'ویرایش';

  @override
  String get selectNote =>
      'یک یادداشت را از فهرست انتخاب کن یا یادداشت تازه بساز.';

  @override
  String get highlight => 'هایلایت';

  @override
  String get highlightColor => 'رنگ هایلایت';

  @override
  String get highlightHint => 'اول متن را روی صفحه انتخاب کن، بعد هایلایتش کن.';

  @override
  String get noHighlightsTitle => 'هنوز هایلایتی نیست';

  @override
  String get noHighlightsBody =>
      'یک جمله را انتخاب کن و دکمهٔ هایلایت را بزن. همین‌جا با شمارهٔ صفحه‌اش می‌آید.';

  @override
  String get highlightNoteHint => 'برای این هایلایت یادداشت بنویس…';

  @override
  String get deleteHighlight => 'حذف هایلایت';

  @override
  String pageN(String page) {
    return 'صفحهٔ $page';
  }

  @override
  String get findInBook => 'جست‌وجو در کتاب';

  @override
  String get findHint => 'جست‌وجو در این کتاب';

  @override
  String matchOf(String index, String count) {
    return '$index از $count';
  }

  @override
  String get noMatches => 'موردی نیست';

  @override
  String get previous => 'قبلی';

  @override
  String get next => 'بعدی';

  @override
  String get accentColor => 'رنگ تأکید';

  @override
  String get accentBlue => 'آبی';

  @override
  String get accentPurple => 'بنفش';

  @override
  String get accentPink => 'صورتی';

  @override
  String get accentRed => 'قرمز';

  @override
  String get accentOrange => 'نارنجی';

  @override
  String get accentGreen => 'سبز';

  @override
  String get accentGraphite => 'گرافیت';

  @override
  String get colorYellow => 'زرد';

  @override
  String get general => 'عمومی';

  @override
  String get about => 'درباره';

  @override
  String get version => 'نسخه';

  @override
  String get storedOnDevice =>
      'همه‌چیز اول روی همین دستگاه ذخیره می‌شود؛ همگام‌سازی اختیاری است.';

  @override
  String get textWeight => 'پررنگی متن';

  @override
  String get tasks => 'کارها';

  @override
  String get today => 'امروز';

  @override
  String get tomorrow => 'فردا';

  @override
  String get yesterday => 'دیروز';

  @override
  String get nextWeek => 'هفتهٔ بعد';

  @override
  String get scheduled => 'زمان‌دار';

  @override
  String get allTasks => 'همه';

  @override
  String get completed => 'انجام‌شده';

  @override
  String get projects => 'پروژه‌ها';

  @override
  String get newProject => 'پروژهٔ تازه';

  @override
  String get projectName => 'نام پروژه';

  @override
  String get rename => 'تغییر نام';

  @override
  String get deleteProject => 'حذف پروژه';

  @override
  String deleteProjectBody(String name) {
    return '«$name» حذف می‌شود. کارهایش می‌مانند، بدون پروژه.';
  }

  @override
  String get create => 'ساختن';

  @override
  String get save => 'ذخیره';

  @override
  String get newTaskHint => 'کار تازه، بعد Enter';

  @override
  String get noTasksTitle => 'اینجا چیزی نیست';

  @override
  String get noTasksBody => 'یک کار را در کادر بالا بنویس و Enter بزن.';

  @override
  String get nothingTodayTitle => 'برای امروز کاری نیست';

  @override
  String get nothingTodayBody =>
      'کارهایی که سررسیدشان امروز است یا گذشته، اینجا می‌آیند.';

  @override
  String get noCompletedBody => 'کارهای تمام‌شده اینجا می‌مانند.';

  @override
  String get taskTitleHint => 'عنوان کار';

  @override
  String get taskNotesHint => 'توضیح';

  @override
  String get project => 'پروژه';

  @override
  String get noProject => 'بدون پروژه';

  @override
  String get dueDate => 'سررسید';

  @override
  String get noDate => 'بدون تاریخ';

  @override
  String get priority => 'اولویت';

  @override
  String get priorityNone => 'ندارد';

  @override
  String get priorityLow => 'کم';

  @override
  String get priorityMedium => 'متوسط';

  @override
  String get priorityHigh => 'زیاد';

  @override
  String get repeat => 'تکرار';

  @override
  String get repeatNone => 'ندارد';

  @override
  String get repeatDaily => 'هر روز';

  @override
  String get repeatWeekly => 'هر هفته';

  @override
  String get repeatMonthly => 'هر ماه';

  @override
  String get repeatNeedsDate => 'تکرار به سررسید نیاز دارد.';

  @override
  String get subtasks => 'زیرکارها';

  @override
  String get addSubtask => 'زیرکار تازه، بعد Enter';

  @override
  String subtaskProgress(String done, String count) {
    return '$done از $count';
  }

  @override
  String get deleteTask => 'حذف کار';

  @override
  String get openSource => 'باز کردن منبع';

  @override
  String get sourceGone =>
      'هایلایت یا یادداشتی که این کار از آن ساخته شده دیگر وجود ندارد.';

  @override
  String get statusTodo => 'در انتظار';

  @override
  String get statusDoing => 'در حال انجام';

  @override
  String get statusDone => 'انجام‌شده';

  @override
  String get listView => 'فهرست';

  @override
  String get boardView => 'تخته';

  @override
  String get makeTask => 'ساخت کار';

  @override
  String get taskAdded => 'به کارها اضافه شد.';

  @override
  String get markDone => 'انجام شد';

  @override
  String get markNotDone => 'انجام نشده';

  @override
  String get previousMonth => 'ماه قبل';

  @override
  String get nextMonth => 'ماه بعد';

  @override
  String get addCard => 'افزودن کارت';

  @override
  String get cardTitleHint => 'عنوان کارت، بعد Enter';

  @override
  String get addList => 'افزودن فهرست';

  @override
  String get listName => 'نام فهرست';

  @override
  String get deleteList => 'حذف فهرست';

  @override
  String get labels => 'برچسب‌ها';

  @override
  String get list => 'فهرست';

  @override
  String get labelGreen => 'سبز';

  @override
  String get labelYellow => 'زرد';

  @override
  String get labelOrange => 'نارنجی';

  @override
  String get labelRed => 'قرمز';

  @override
  String get labelPurple => 'بنفش';

  @override
  String get labelBlue => 'آبی';

  @override
  String get sync => 'همگام‌سازی';

  @override
  String get syncMethod => 'روش همگام‌سازی';

  @override
  String get syncOff => 'خاموش';

  @override
  String get syncFolder => 'پوشهٔ مشترک';

  @override
  String get folder => 'پوشه';

  @override
  String get chooseFolder => 'انتخاب…';

  @override
  String get noFolder => 'انتخاب نشده';

  @override
  String get syncFolderHint =>
      'پوشه‌ای را انتخاب کن که بین دستگاه‌هایت مشترک است، مثلاً داخل Google Drive، OneDrive یا Syncthing. هر دستگاه یک فایل کوچک آنجا نگه می‌دارد.';

  @override
  String get syncBookFiles => 'فایل کتاب‌ها هم همگام شود';

  @override
  String get syncNow => 'همگام‌سازی';

  @override
  String get syncing => 'در حال همگام‌سازی…';

  @override
  String lastSynced(String when) {
    return 'آخرین همگام‌سازی: $when';
  }

  @override
  String get neverSynced => 'هنوز همگام نشده';

  @override
  String get syncFailed =>
      'همگام‌سازی انجام نشد. مطمئن شو پوشه وجود دارد و قابل نوشتن است.';

  @override
  String get thisDevice => 'این دستگاه';

  @override
  String continueFrom(String page, String device) {
    return 'ادامه از صفحهٔ $page، جایی که روی $device بودی؟';
  }

  @override
  String continueFromUnknown(String page) {
    return 'ادامه از صفحهٔ $page، جایی که روی دستگاه دیگر بودی؟';
  }

  @override
  String get go => 'برو';

  @override
  String get dismiss => 'بستن';

  @override
  String sectionOf(String section, String count) {
    return 'بخش $section از $count';
  }

  @override
  String get contents => 'فهرست مطالب';

  @override
  String sectionN(String section) {
    return 'بخش $section';
  }

  @override
  String get textSettings => 'متن';

  @override
  String get fontSize => 'اندازه';

  @override
  String get lineSpacing => 'فاصلهٔ خطوط';

  @override
  String get columnWidth => 'عرض متن';

  @override
  String get previousSection => 'بخش قبلی';

  @override
  String get nextSection => 'بخش بعدی';

  @override
  String get focusMode => 'حالت تمرکز';

  @override
  String get exitFocus => 'خروج از حالت تمرکز (Esc)';

  @override
  String get bookUnreadable => 'این کتاب باز نشد. شاید فایلش خراب باشد.';

  @override
  String get pen => 'قلم';

  @override
  String get handwriting => 'دست‌نوشته';

  @override
  String get mdHeading => 'تیتر';

  @override
  String get mdBold => 'پررنگ';

  @override
  String get mdItalic => 'کج';

  @override
  String get mdStrike => 'خط‌خورده';

  @override
  String get mdBullets => 'فهرست نقطه‌ای';

  @override
  String get mdNumbers => 'فهرست شماره‌دار';

  @override
  String get mdChecklist => 'چک‌لیست';

  @override
  String get mdQuote => 'نقل‌قول';

  @override
  String get mdCode => 'کد';

  @override
  String get mdLink => 'پیوند';

  @override
  String get mdDivider => 'خط جداکننده';

  @override
  String get mdTable => 'جدول';

  @override
  String get goToPage => 'رفتن به صفحه';

  @override
  String pageNumberHint(String count) {
    return '۱ تا $count';
  }

  @override
  String get drawTools => 'ابزار نوشتن و رسم';

  @override
  String get toolPen => 'روان‌نویس';

  @override
  String get toolPencil => 'مداد';

  @override
  String get toolMarker => 'ماژیک';

  @override
  String get toolEraser => 'پاک‌کن';

  @override
  String get toolShapes => 'شکل‌ها';

  @override
  String get shapeLine => 'خط';

  @override
  String get shapeArrow => 'فلش';

  @override
  String get shapeRect => 'مستطیل';

  @override
  String get shapeEllipse => 'بیضی';

  @override
  String get toolText => 'متن';

  @override
  String get toolSticky => 'استیکی‌نوت';

  @override
  String get toolPage => 'چسباندن صفحه';

  @override
  String get undo => 'واگرد';

  @override
  String get redo => 'ازنو';

  @override
  String get thickness => 'ضخامت';

  @override
  String get notebooks => 'دفترها';

  @override
  String get newNotebook => 'دفتر تازه';

  @override
  String get notebookName => 'نام دفتر';

  @override
  String get newPage => 'صفحهٔ تازه';

  @override
  String get deletePage => 'حذف صفحه';

  @override
  String get deleteNotebook => 'حذف دفتر';

  @override
  String deleteNotebookBody(String name) {
    return '«$name» و همهٔ صفحه‌هایش حذف می‌شود.';
  }

  @override
  String get paper => 'کاغذ';

  @override
  String get paperBlank => 'ساده';

  @override
  String get paperLined => 'خط‌دار';

  @override
  String get paperGrid => 'شطرنجی';

  @override
  String get paperDots => 'نقطه‌ای';

  @override
  String get noNotebooksTitle => 'هنوز دفتری نیست';

  @override
  String get noNotebooksBody =>
      'یک دفتر بساز و در صفحه‌هایش بنویس، تایپ کن و رسم کن.';

  @override
  String get emptyNotebookBody => 'این دفتر هنوز صفحه‌ای ندارد.';

  @override
  String get stickyNote => 'استیکی‌نوت';

  @override
  String get stickyHint => 'روی برگه بنویس…';

  @override
  String get attachedPage => 'صفحهٔ پیوست';

  @override
  String get pageGone => 'صفحهٔ پیوست دیگر وجود ندارد.';

  @override
  String get textHint => 'اینجا تایپ کن';

  @override
  String get add => 'افزودن';

  @override
  String get selectNotebook =>
      'یک دفتر را از فهرست انتخاب کن یا دفتر تازه بساز.';

  @override
  String get toolFountain => 'خودنویس';

  @override
  String get toolBrush => 'قلم‌مو';

  @override
  String get reading => 'خواندن';

  @override
  String get scrollSpeed => 'سرعت اسکرول با ماوس';

  @override
  String get smoothScrolling => 'اسکرول نرم در PDF';

  @override
  String get slower => 'کندتر';

  @override
  String get faster => 'تندتر';

  @override
  String get syncGoogle => 'Google Drive';

  @override
  String get syncMicrosoft => 'OneDrive';

  @override
  String get clientId => 'Client ID';

  @override
  String get clientSecret => 'Client secret';

  @override
  String get ownKeysHint =>
      'ورق کلیدی از خودش ندارد. یک‌بار و رایگان، برنامه‌ای نزد سرویس‌دهنده ثبت می‌کنی و کلیدش را اینجا می‌گذاری. بعد از آن داده‌هایت فقط به حساب خودت می‌رود.';

  @override
  String get howToGetKeys => 'راهنمای گرفتن کلید';

  @override
  String get signInWithBrowser => 'ورود با مرورگر';

  @override
  String get waitingForBrowser => 'در انتظار مرورگر…';

  @override
  String get signedIn => 'وارد شده';

  @override
  String get signOut => 'خروج';

  @override
  String get signInFailed =>
      'ورود کامل نشد. کلیدها را بررسی کن و دوباره امتحان کن.';

  @override
  String get signInDonePage =>
      'ورود انجام شد. می‌توانی این پنجره را ببندی و به ورق برگردی.';

  @override
  String get syncFailedCloud =>
      'همگام‌سازی انجام نشد. اتصال اینترنت را بررسی کن یا دوباره وارد شو.';

  @override
  String get close => 'بستن';

  @override
  String get googleGuide =>
      '۱. به console.cloud.google.com برو و یک پروژهٔ تازه بساز.\n۲. در «APIs & Services» ← «Library»، سرویس «Google Drive API» را پیدا کن و Enable را بزن.\n۳. «OAuth consent screen» را باز کن. نوع External را انتخاب کن، اسم برنامه و ایمیلت را بنویس و در بخش Test users ایمیل گوگل خودت را اضافه کن.\n۴. در «Credentials» ← «Create credentials» ← «OAuth client ID»، نوع «Desktop app» را انتخاب کن.\n۵. Client ID و Client secret را کپی کن و اینجا بگذار.\n۶. «ورود با مرورگر» را بزن و اجازه بده.\n\nتا وقتی برنامه در حالت Testing است، گوگل هر ۷ روز دوباره ورود می‌خواهد. با زدن «Publish app» در همان صفحه این محدودیت برداشته می‌شود.';

  @override
  String get microsoftGuide =>
      '۱. به portal.azure.com برو ← «App registrations» ← «New registration».\n۲. یک اسم بنویس. در Supported account types گزینه‌ای را انتخاب کن که حساب شخصی مایکروسافت را هم شامل شود.\n۳. در Redirect URI نوع «Public client/native (mobile & desktop)» را انتخاب کن و بنویس http://localhost\n۴. Register را بزن. بعد «Authentication» را باز کن و «Allow public client flows» را روشن کن.\n۵. «Application (client) ID» را از صفحهٔ Overview کپی کن و اینجا بگذار. این یکی secret ندارد.\n۶. «ورود با مرورگر» را بزن و اجازه بده.\n\nاگر پنل گفت دایرکتوری لازم است، ساختن حساب رایگان Azure آن را می‌دهد.';
}
