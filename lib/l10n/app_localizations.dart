import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Varagh'**
  String get appName;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addBook.
  ///
  /// In en, this message translates to:
  /// **'Add book'**
  String get addBook;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @allBooks.
  ///
  /// In en, this message translates to:
  /// **'All books'**
  String get allBooks;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'No books yet'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Add a PDF, EPUB, Markdown, HTML or text file. It opens right where you left off, every time.'**
  String get emptyLibraryBody;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String pageOf(String page, String count);

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get notStarted;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get remove;

  /// No description provided for @removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this book?'**
  String get removeTitle;

  /// No description provided for @removeBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” and its reading position are deleted from this device. The original file you imported stays where it is.'**
  String removeBody(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get importing;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add “{name}”. Check that the file is readable and one of: PDF, EPUB, Markdown, HTML, text.'**
  String importFailed(String name);

  /// No description provided for @alreadyInLibrary.
  ///
  /// In en, this message translates to:
  /// **'“{title}” is already in your library.'**
  String alreadyInLibrary(String title);

  /// No description provided for @bookFileMissing.
  ///
  /// In en, this message translates to:
  /// **'This book\'s file is missing from the device. Remove it and add it again.'**
  String get bookFileMissing;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @lookLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lookLight;

  /// No description provided for @lookPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get lookPaper;

  /// No description provided for @lookDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get lookDark;

  /// No description provided for @lookBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get lookBlack;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// No description provided for @pageColor.
  ///
  /// In en, this message translates to:
  /// **'Page color'**
  String get pageColor;

  /// No description provided for @pageColorHint.
  ///
  /// In en, this message translates to:
  /// **'Saved for this book.'**
  String get pageColorHint;

  /// No description provided for @paperOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get paperOriginal;

  /// No description provided for @paperPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paperPaper;

  /// No description provided for @paperSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get paperSepia;

  /// No description provided for @paperGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get paperGreen;

  /// No description provided for @paperGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get paperGray;

  /// No description provided for @paperDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get paperDark;

  /// No description provided for @paperBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get paperBlack;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search books, highlights and notes'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search everything'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Type a word to find book titles, highlighted passages and your notes.'**
  String get searchEmptyBody;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{query}”.'**
  String noResults(String query);

  /// No description provided for @books.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get books;

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recently read'**
  String get recent;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @noNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotesTitle;

  /// No description provided for @noNotesBody.
  ///
  /// In en, this message translates to:
  /// **'Write down a thought. The first line becomes the title, and Markdown works.'**
  String get noNotesBody;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Title on the first line, then your note…'**
  String get noteHint;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// No description provided for @deleteNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get deleteNoteTitle;

  /// No description provided for @deleteNoteBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” is removed from this device.'**
  String deleteNoteBody(String title);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @selectNote.
  ///
  /// In en, this message translates to:
  /// **'Pick a note from the list, or start a new one.'**
  String get selectNote;

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlight;

  /// No description provided for @highlightColor.
  ///
  /// In en, this message translates to:
  /// **'Highlight color'**
  String get highlightColor;

  /// No description provided for @highlightHint.
  ///
  /// In en, this message translates to:
  /// **'Select text on the page first, then highlight it.'**
  String get highlightHint;

  /// No description provided for @noHighlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet'**
  String get noHighlightsTitle;

  /// No description provided for @noHighlightsBody.
  ///
  /// In en, this message translates to:
  /// **'Select a sentence and press the highlighter. It shows up here with its page.'**
  String get noHighlightsBody;

  /// No description provided for @highlightNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note to this highlight…'**
  String get highlightNoteHint;

  /// No description provided for @deleteHighlight.
  ///
  /// In en, this message translates to:
  /// **'Delete highlight'**
  String get deleteHighlight;

  /// No description provided for @pageN.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageN(String page);

  /// No description provided for @findInBook.
  ///
  /// In en, this message translates to:
  /// **'Find in book'**
  String get findInBook;

  /// No description provided for @findHint.
  ///
  /// In en, this message translates to:
  /// **'Find in this book'**
  String get findHint;

  /// No description provided for @matchOf.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String matchOf(String index, String count);

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get accentPurple;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// No description provided for @accentRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get accentRed;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get accentGraphite;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @storedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Everything is stored on this device first; sync is optional.'**
  String get storedOnDevice;

  /// No description provided for @textWeight.
  ///
  /// In en, this message translates to:
  /// **'Text weight'**
  String get textWeight;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get nextWeek;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @allTasks.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTasks;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectName;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @deleteProject.
  ///
  /// In en, this message translates to:
  /// **'Delete project'**
  String get deleteProject;

  /// No description provided for @deleteProjectBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is deleted. Its tasks stay, without a project.'**
  String deleteProjectBody(String name);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @newTaskHint.
  ///
  /// In en, this message translates to:
  /// **'New task, then Enter'**
  String get newTaskHint;

  /// No description provided for @noTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get noTasksTitle;

  /// No description provided for @noTasksBody.
  ///
  /// In en, this message translates to:
  /// **'Type a task in the field above and press Enter.'**
  String get noTasksBody;

  /// No description provided for @nothingTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today'**
  String get nothingTodayTitle;

  /// No description provided for @nothingTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Tasks due today or overdue show up here.'**
  String get nothingTodayBody;

  /// No description provided for @noCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Finished tasks are kept here.'**
  String get noCompletedBody;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskTitleHint;

  /// No description provided for @taskNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get taskNotesHint;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @noProject.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noProject;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @noDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get noDate;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priorityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get priorityNone;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatNeedsDate.
  ///
  /// In en, this message translates to:
  /// **'Repeating needs a due date.'**
  String get repeatNeedsDate;

  /// No description provided for @subtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get subtasks;

  /// No description provided for @addSubtask.
  ///
  /// In en, this message translates to:
  /// **'Add a subtask, then Enter'**
  String get addSubtask;

  /// No description provided for @subtaskProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {count}'**
  String subtaskProgress(String done, String count);

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get deleteTask;

  /// No description provided for @openSource.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get openSource;

  /// No description provided for @sourceGone.
  ///
  /// In en, this message translates to:
  /// **'The highlight or note this task came from no longer exists.'**
  String get sourceGone;

  /// No description provided for @statusTodo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get statusTodo;

  /// No description provided for @statusDoing.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusDoing;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listView;

  /// No description provided for @boardView.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardView;

  /// No description provided for @makeTask.
  ///
  /// In en, this message translates to:
  /// **'Make a task'**
  String get makeTask;

  /// No description provided for @taskAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to Tasks.'**
  String get taskAdded;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markDone;

  /// No description provided for @markNotDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as not done'**
  String get markNotDone;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add a card'**
  String get addCard;

  /// No description provided for @cardTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Card title, then Enter'**
  String get cardTitleHint;

  /// No description provided for @addList.
  ///
  /// In en, this message translates to:
  /// **'Add a list'**
  String get addList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get listName;

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get deleteList;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @labelGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get labelGreen;

  /// No description provided for @labelYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get labelYellow;

  /// No description provided for @labelOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get labelOrange;

  /// No description provided for @labelRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get labelRed;

  /// No description provided for @labelPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get labelPurple;

  /// No description provided for @labelBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get labelBlue;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @syncMethod.
  ///
  /// In en, this message translates to:
  /// **'Sync through'**
  String get syncMethod;

  /// No description provided for @syncOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get syncOff;

  /// No description provided for @syncFolder.
  ///
  /// In en, this message translates to:
  /// **'A shared folder'**
  String get syncFolder;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @chooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get chooseFolder;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get noFolder;

  /// No description provided for @syncFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder your devices share, such as one inside Google Drive, OneDrive or Syncthing. Each device keeps one small file there.'**
  String get syncFolderHint;

  /// No description provided for @syncBookFiles.
  ///
  /// In en, this message translates to:
  /// **'Sync book files too'**
  String get syncBookFiles;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {when}'**
  String lastSynced(String when);

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get neverSynced;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Check that the folder exists and can be written to.'**
  String get syncFailed;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @continueFrom.
  ///
  /// In en, this message translates to:
  /// **'Continue from page {page}, where you left off on {device}?'**
  String continueFrom(String page, String device);

  /// No description provided for @continueFromUnknown.
  ///
  /// In en, this message translates to:
  /// **'Continue from page {page}, where you left off on another device?'**
  String continueFromUnknown(String page);

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @sectionOf.
  ///
  /// In en, this message translates to:
  /// **'Section {section} of {count}'**
  String sectionOf(String section, String count);

  /// No description provided for @contents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get contents;

  /// No description provided for @sectionN.
  ///
  /// In en, this message translates to:
  /// **'Section {section}'**
  String sectionN(String section);

  /// No description provided for @textSettings.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textSettings;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fontSize;

  /// No description provided for @lineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineSpacing;

  /// No description provided for @columnWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get columnWidth;

  /// No description provided for @previousSection.
  ///
  /// In en, this message translates to:
  /// **'Previous section'**
  String get previousSection;

  /// No description provided for @nextSection.
  ///
  /// In en, this message translates to:
  /// **'Next section'**
  String get nextSection;

  /// No description provided for @focusMode.
  ///
  /// In en, this message translates to:
  /// **'Focus mode'**
  String get focusMode;

  /// No description provided for @exitFocus.
  ///
  /// In en, this message translates to:
  /// **'Leave focus mode (Esc)'**
  String get exitFocus;

  /// No description provided for @bookUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This book couldn\'t be opened. Its file may be damaged.'**
  String get bookUnreadable;

  /// No description provided for @pen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get pen;

  /// No description provided for @handwriting.
  ///
  /// In en, this message translates to:
  /// **'Handwriting'**
  String get handwriting;

  /// No description provided for @mdHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get mdHeading;

  /// No description provided for @mdBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get mdBold;

  /// No description provided for @mdItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get mdItalic;

  /// No description provided for @mdStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get mdStrike;

  /// No description provided for @mdBullets.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get mdBullets;

  /// No description provided for @mdNumbers.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get mdNumbers;

  /// No description provided for @mdChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get mdChecklist;

  /// No description provided for @mdQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get mdQuote;

  /// No description provided for @mdCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get mdCode;

  /// No description provided for @mdLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get mdLink;

  /// No description provided for @mdDivider.
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get mdDivider;

  /// No description provided for @mdTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get mdTable;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @pageNumberHint.
  ///
  /// In en, this message translates to:
  /// **'1 to {count}'**
  String pageNumberHint(String count);

  /// No description provided for @drawTools.
  ///
  /// In en, this message translates to:
  /// **'Drawing tools'**
  String get drawTools;

  /// No description provided for @toolPen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get toolPen;

  /// No description provided for @toolPencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get toolPencil;

  /// No description provided for @toolMarker.
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get toolMarker;

  /// No description provided for @toolEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get toolEraser;

  /// No description provided for @toolShapes.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get toolShapes;

  /// No description provided for @shapeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get shapeLine;

  /// No description provided for @shapeArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get shapeArrow;

  /// No description provided for @shapeRect.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get shapeRect;

  /// No description provided for @shapeEllipse.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get shapeEllipse;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get toolText;

  /// No description provided for @toolSticky.
  ///
  /// In en, this message translates to:
  /// **'Sticky note'**
  String get toolSticky;

  /// No description provided for @toolPage.
  ///
  /// In en, this message translates to:
  /// **'Attach a page'**
  String get toolPage;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @thickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get thickness;

  /// No description provided for @notebooks.
  ///
  /// In en, this message translates to:
  /// **'Notebooks'**
  String get notebooks;

  /// No description provided for @newNotebook.
  ///
  /// In en, this message translates to:
  /// **'New notebook'**
  String get newNotebook;

  /// No description provided for @notebookName.
  ///
  /// In en, this message translates to:
  /// **'Notebook name'**
  String get notebookName;

  /// No description provided for @newPage.
  ///
  /// In en, this message translates to:
  /// **'New page'**
  String get newPage;

  /// No description provided for @deletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get deletePage;

  /// No description provided for @deleteNotebook.
  ///
  /// In en, this message translates to:
  /// **'Delete notebook'**
  String get deleteNotebook;

  /// No description provided for @deleteNotebookBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}” and all of its pages are deleted.'**
  String deleteNotebookBody(String name);

  /// No description provided for @paper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paper;

  /// No description provided for @paperBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank'**
  String get paperBlank;

  /// No description provided for @paperLined.
  ///
  /// In en, this message translates to:
  /// **'Lined'**
  String get paperLined;

  /// No description provided for @paperGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get paperGrid;

  /// No description provided for @paperDots.
  ///
  /// In en, this message translates to:
  /// **'Dotted'**
  String get paperDots;

  /// No description provided for @noNotebooksTitle.
  ///
  /// In en, this message translates to:
  /// **'No notebooks yet'**
  String get noNotebooksTitle;

  /// No description provided for @noNotebooksBody.
  ///
  /// In en, this message translates to:
  /// **'Make a notebook to write, type and draw on its pages.'**
  String get noNotebooksBody;

  /// No description provided for @emptyNotebookBody.
  ///
  /// In en, this message translates to:
  /// **'This notebook has no pages yet.'**
  String get emptyNotebookBody;

  /// No description provided for @stickyNote.
  ///
  /// In en, this message translates to:
  /// **'Sticky note'**
  String get stickyNote;

  /// No description provided for @stickyHint.
  ///
  /// In en, this message translates to:
  /// **'Write on the note…'**
  String get stickyHint;

  /// No description provided for @attachedPage.
  ///
  /// In en, this message translates to:
  /// **'Attached page'**
  String get attachedPage;

  /// No description provided for @pageGone.
  ///
  /// In en, this message translates to:
  /// **'The attached page no longer exists.'**
  String get pageGone;

  /// No description provided for @textHint.
  ///
  /// In en, this message translates to:
  /// **'Type here'**
  String get textHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @selectNotebook.
  ///
  /// In en, this message translates to:
  /// **'Pick a notebook from the list, or make a new one.'**
  String get selectNotebook;

  /// No description provided for @toolFountain.
  ///
  /// In en, this message translates to:
  /// **'Fountain pen'**
  String get toolFountain;

  /// No description provided for @toolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get toolBrush;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @scrollSpeed.
  ///
  /// In en, this message translates to:
  /// **'Mouse wheel speed'**
  String get scrollSpeed;

  /// No description provided for @smoothScrolling.
  ///
  /// In en, this message translates to:
  /// **'Smooth scrolling in PDFs'**
  String get smoothScrolling;

  /// No description provided for @slower.
  ///
  /// In en, this message translates to:
  /// **'Slower'**
  String get slower;

  /// No description provided for @faster.
  ///
  /// In en, this message translates to:
  /// **'Faster'**
  String get faster;

  /// No description provided for @syncGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get syncGoogle;

  /// No description provided for @syncMicrosoft.
  ///
  /// In en, this message translates to:
  /// **'OneDrive'**
  String get syncMicrosoft;

  /// No description provided for @clientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get clientId;

  /// No description provided for @clientSecret.
  ///
  /// In en, this message translates to:
  /// **'Client secret'**
  String get clientSecret;

  /// No description provided for @ownKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Varagh ships without keys of its own. You register an app with the provider once, for free, and paste its keys here. Your data then goes only to your own account.'**
  String get ownKeysHint;

  /// No description provided for @howToGetKeys.
  ///
  /// In en, this message translates to:
  /// **'How to get the keys'**
  String get howToGetKeys;

  /// No description provided for @signInWithBrowser.
  ///
  /// In en, this message translates to:
  /// **'Sign in with browser'**
  String get signInWithBrowser;

  /// No description provided for @waitingForBrowser.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the browser…'**
  String get waitingForBrowser;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn\'t complete. Check the keys and try again.'**
  String get signInFailed;

  /// No description provided for @signInDonePage.
  ///
  /// In en, this message translates to:
  /// **'Signed in. You can close this window and return to Varagh.'**
  String get signInDonePage;

  /// No description provided for @syncFailedCloud.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Check your connection, or sign in again.'**
  String get syncFailedCloud;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @googleGuide.
  ///
  /// In en, this message translates to:
  /// **'1. Open console.cloud.google.com and create a new project.\n2. In “APIs & Services” → “Library”, find “Google Drive API” and press Enable.\n3. Open “OAuth consent screen”. Choose External, enter an app name and your email, and add your own Google address under Test users.\n4. In “Credentials” → “Create credentials” → “OAuth client ID”, choose the type “Desktop app”.\n5. Copy the Client ID and Client secret it shows and paste them here.\n6. Press “Sign in with browser” and approve.\n\nWhile the app is in Testing, Google asks you to sign in again every 7 days. Pressing “Publish app” on the consent screen removes that.'**
  String get googleGuide;

  /// No description provided for @microsoftGuide.
  ///
  /// In en, this message translates to:
  /// **'1. Open portal.azure.com and go to “App registrations” → “New registration”.\n2. Enter a name. Under Supported account types choose one that includes personal Microsoft accounts.\n3. Under Redirect URI choose “Public client/native (mobile & desktop)” and enter http://localhost\n4. Press Register. Then open “Authentication” and turn on “Allow public client flows”.\n5. Copy the “Application (client) ID” from the Overview page and paste it here. There is no secret.\n6. Press “Sign in with browser” and approve.\n\nIf the portal says you need a directory, creating a free Azure account gives you one.'**
  String get microsoftGuide;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @exportPdfHint.
  ///
  /// In en, this message translates to:
  /// **'Choose what is put onto the pages. The book\'s own text stays selectable.'**
  String get exportPdfHint;

  /// No description provided for @shapes.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get shapes;

  /// No description provided for @typedText.
  ///
  /// In en, this message translates to:
  /// **'Typed text'**
  String get typedText;

  /// No description provided for @stickyNotes.
  ///
  /// In en, this message translates to:
  /// **'Sticky notes'**
  String get stickyNotes;

  /// No description provided for @annotatedPagesOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the pages with something on them'**
  String get annotatedPagesOnly;

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been marked on this book yet.'**
  String get nothingToExport;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exporting;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get exportSaved;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The export couldn\'t be made.'**
  String get exportFailed;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @exportBook.
  ///
  /// In en, this message translates to:
  /// **'Export for another device'**
  String get exportBook;

  /// No description provided for @exportLibrary.
  ///
  /// In en, this message translates to:
  /// **'Export everything'**
  String get exportLibrary;

  /// No description provided for @exportLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'One file with every book and its highlights, plus your notes, notebooks and tasks.'**
  String get exportLibraryHint;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import a backup file'**
  String get importBackup;

  /// No description provided for @importBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Adds what the file holds to this device. Nothing here is deleted; where both have the same item, the more recently edited one is kept.'**
  String get importBackupHint;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get chooseFile;

  /// No description provided for @importingBackup.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importingBackup;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported. Books added: {count}'**
  String importDone(String count);

  /// No description provided for @importNotBackup.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Varagh backup file.'**
  String get importNotBackup;

  /// No description provided for @importFailedBackup.
  ///
  /// In en, this message translates to:
  /// **'The file couldn\'t be imported.'**
  String get importFailedBackup;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
