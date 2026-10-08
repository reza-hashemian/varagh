// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Varagh';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get addBook => 'Add book';

  @override
  String get continueReading => 'Continue reading';

  @override
  String get allBooks => 'All books';

  @override
  String get emptyLibraryTitle => 'No books yet';

  @override
  String get emptyLibraryBody =>
      'Add a PDF, EPUB, Markdown, HTML or text file. It opens right where you left off, every time.';

  @override
  String pageOf(String page, String count) {
    return 'Page $page of $count';
  }

  @override
  String get notStarted => 'Not started';

  @override
  String get remove => 'Remove from library';

  @override
  String get removeTitle => 'Remove this book?';

  @override
  String removeBody(String title) {
    return '“$title” and its reading position are deleted from this device. The original file you imported stays where it is.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get importing => 'Adding…';

  @override
  String importFailed(String name) {
    return 'Couldn\'t add “$name”. Check that the file is readable and one of: PDF, EPUB, Markdown, HTML, text.';
  }

  @override
  String alreadyInLibrary(String title) {
    return '“$title” is already in your library.';
  }

  @override
  String get bookFileMissing =>
      'This book\'s file is missing from the device. Remove it and add it again.';

  @override
  String get appearance => 'Appearance';

  @override
  String get lookLight => 'Light';

  @override
  String get lookPaper => 'Paper';

  @override
  String get lookDark => 'Dark';

  @override
  String get lookBlack => 'Black';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get pageColor => 'Page color';

  @override
  String get pageColorHint => 'Saved for this book.';

  @override
  String get paperOriginal => 'Original';

  @override
  String get paperPaper => 'Paper';

  @override
  String get paperSepia => 'Sepia';

  @override
  String get paperGreen => 'Green';

  @override
  String get paperGray => 'Gray';

  @override
  String get paperDark => 'Dark';

  @override
  String get paperBlack => 'Black';

  @override
  String get strength => 'Strength';

  @override
  String get contrast => 'Contrast';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get back => 'Back';

  @override
  String get notes => 'Notes';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search books, highlights and notes';

  @override
  String get searchEmptyTitle => 'Search everything';

  @override
  String get searchEmptyBody =>
      'Type a word to find book titles, highlighted passages and your notes.';

  @override
  String noResults(String query) {
    return 'Nothing found for “$query”.';
  }

  @override
  String get books => 'Books';

  @override
  String get highlights => 'Highlights';

  @override
  String get recent => 'Recently read';

  @override
  String get newNote => 'New note';

  @override
  String get noNotesTitle => 'No notes yet';

  @override
  String get noNotesBody =>
      'Write down a thought. The first line becomes the title, and Markdown works.';

  @override
  String get noteHint => 'Title on the first line, then your note…';

  @override
  String get untitled => 'Untitled';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get deleteNoteTitle => 'Delete this note?';

  @override
  String deleteNoteBody(String title) {
    return '“$title” is removed from this device.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String get preview => 'Preview';

  @override
  String get edit => 'Edit';

  @override
  String get selectNote => 'Pick a note from the list, or start a new one.';

  @override
  String get highlight => 'Highlight';

  @override
  String get highlightHint =>
      'Select text on the page first, then highlight it.';

  @override
  String get noHighlightsTitle => 'No highlights yet';

  @override
  String get noHighlightsBody =>
      'Select a sentence and press the highlighter. It shows up here with its page.';

  @override
  String get highlightNoteHint => 'Add a note to this highlight…';

  @override
  String get deleteHighlight => 'Delete highlight';

  @override
  String pageN(String page) {
    return 'Page $page';
  }

  @override
  String get findInBook => 'Find in book';

  @override
  String get findHint => 'Find in this book';

  @override
  String matchOf(String index, String count) {
    return '$index of $count';
  }

  @override
  String get noMatches => 'No matches';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get accentColor => 'Accent color';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentRed => 'Red';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentGraphite => 'Graphite';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get general => 'General';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get storedOnDevice =>
      'Everything is stored on this device first; sync is optional.';

  @override
  String get textWeight => 'Text weight';

  @override
  String get tasks => 'Tasks';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get nextWeek => 'Next week';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get allTasks => 'All';

  @override
  String get completed => 'Completed';

  @override
  String get projects => 'Projects';

  @override
  String get newProject => 'New project';

  @override
  String get projectName => 'Project name';

  @override
  String get rename => 'Rename';

  @override
  String get deleteProject => 'Delete project';

  @override
  String deleteProjectBody(String name) {
    return '“$name” is deleted. Its tasks stay, without a project.';
  }

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get newTaskHint => 'New task, then Enter';

  @override
  String get noTasksTitle => 'Nothing here';

  @override
  String get noTasksBody => 'Type a task in the field above and press Enter.';

  @override
  String get nothingTodayTitle => 'Nothing due today';

  @override
  String get nothingTodayBody => 'Tasks due today or overdue show up here.';

  @override
  String get noCompletedBody => 'Finished tasks are kept here.';

  @override
  String get taskTitleHint => 'Task';

  @override
  String get taskNotesHint => 'Notes';

  @override
  String get project => 'Project';

  @override
  String get noProject => 'None';

  @override
  String get dueDate => 'Due date';

  @override
  String get noDate => 'No date';

  @override
  String get priority => 'Priority';

  @override
  String get priorityNone => 'None';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatNone => 'Never';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatNeedsDate => 'Repeating needs a due date.';

  @override
  String get subtasks => 'Subtasks';

  @override
  String get addSubtask => 'Add a subtask, then Enter';

  @override
  String subtaskProgress(String done, String count) {
    return '$done of $count';
  }

  @override
  String get deleteTask => 'Delete task';

  @override
  String get openSource => 'Open source';

  @override
  String get sourceGone =>
      'The highlight or note this task came from no longer exists.';

  @override
  String get statusTodo => 'To do';

  @override
  String get statusDoing => 'In progress';

  @override
  String get statusDone => 'Done';

  @override
  String get listView => 'List';

  @override
  String get boardView => 'Board';

  @override
  String get makeTask => 'Make a task';

  @override
  String get taskAdded => 'Added to Tasks.';

  @override
  String get markDone => 'Mark as done';

  @override
  String get markNotDone => 'Mark as not done';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get addCard => 'Add a card';

  @override
  String get cardTitleHint => 'Card title, then Enter';

  @override
  String get addList => 'Add a list';

  @override
  String get listName => 'List name';

  @override
  String get deleteList => 'Delete list';

  @override
  String get labels => 'Labels';

  @override
  String get list => 'List';

  @override
  String get labelGreen => 'Green';

  @override
  String get labelYellow => 'Yellow';

  @override
  String get labelOrange => 'Orange';

  @override
  String get labelRed => 'Red';

  @override
  String get labelPurple => 'Purple';

  @override
  String get labelBlue => 'Blue';

  @override
  String get sync => 'Sync';

  @override
  String get syncMethod => 'Sync through';

  @override
  String get syncOff => 'Off';

  @override
  String get syncFolder => 'A shared folder';

  @override
  String get folder => 'Folder';

  @override
  String get chooseFolder => 'Choose…';

  @override
  String get noFolder => 'Not chosen';

  @override
  String get syncFolderHint =>
      'Pick a folder your devices share, such as one inside Google Drive, OneDrive or Syncthing. Each device keeps one small file there.';

  @override
  String get syncBookFiles => 'Sync book files too';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncing => 'Syncing…';

  @override
  String lastSynced(String when) {
    return 'Last synced $when';
  }

  @override
  String get neverSynced => 'Not synced yet';

  @override
  String get syncFailed =>
      'Sync failed. Check that the folder exists and can be written to.';

  @override
  String get thisDevice => 'This device';

  @override
  String continueFrom(String page, String device) {
    return 'Continue from page $page, where you left off on $device?';
  }

  @override
  String continueFromUnknown(String page) {
    return 'Continue from page $page, where you left off on another device?';
  }

  @override
  String get go => 'Go';

  @override
  String get dismiss => 'Dismiss';

  @override
  String sectionOf(String section, String count) {
    return 'Section $section of $count';
  }

  @override
  String get contents => 'Contents';

  @override
  String sectionN(String section) {
    return 'Section $section';
  }

  @override
  String get textSettings => 'Text';

  @override
  String get fontSize => 'Size';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get columnWidth => 'Width';

  @override
  String get previousSection => 'Previous section';

  @override
  String get nextSection => 'Next section';

  @override
  String get focusMode => 'Focus mode';

  @override
  String get exitFocus => 'Leave focus mode (Esc)';

  @override
  String get bookUnreadable =>
      'This book couldn\'t be opened. Its file may be damaged.';

  @override
  String get pen => 'Pen';

  @override
  String get handwriting => 'Handwriting';

  @override
  String get mdHeading => 'Heading';

  @override
  String get mdBold => 'Bold';

  @override
  String get mdItalic => 'Italic';

  @override
  String get mdStrike => 'Strikethrough';

  @override
  String get mdBullets => 'Bulleted list';

  @override
  String get mdNumbers => 'Numbered list';

  @override
  String get mdChecklist => 'Checklist';

  @override
  String get mdQuote => 'Quote';

  @override
  String get mdCode => 'Code';

  @override
  String get mdLink => 'Link';

  @override
  String get mdDivider => 'Divider';

  @override
  String get mdTable => 'Table';

  @override
  String get goToPage => 'Go to page';

  @override
  String pageNumberHint(String count) {
    return '1 to $count';
  }

  @override
  String get drawTools => 'Drawing tools';

  @override
  String get toolPen => 'Pen';

  @override
  String get toolPencil => 'Pencil';

  @override
  String get toolMarker => 'Highlighter';

  @override
  String get toolEraser => 'Eraser';

  @override
  String get toolShapes => 'Shapes';

  @override
  String get shapeLine => 'Line';

  @override
  String get shapeArrow => 'Arrow';

  @override
  String get shapeRect => 'Rectangle';

  @override
  String get shapeEllipse => 'Ellipse';

  @override
  String get toolText => 'Text';

  @override
  String get toolSticky => 'Sticky note';

  @override
  String get toolPage => 'Attach a page';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get thickness => 'Thickness';

  @override
  String get notebooks => 'Notebooks';

  @override
  String get newNotebook => 'New notebook';

  @override
  String get notebookName => 'Notebook name';

  @override
  String get newPage => 'New page';

  @override
  String get deletePage => 'Delete page';

  @override
  String get deleteNotebook => 'Delete notebook';

  @override
  String deleteNotebookBody(String name) {
    return '“$name” and all of its pages are deleted.';
  }

  @override
  String get paper => 'Paper';

  @override
  String get paperBlank => 'Blank';

  @override
  String get paperLined => 'Lined';

  @override
  String get paperGrid => 'Grid';

  @override
  String get paperDots => 'Dotted';

  @override
  String get noNotebooksTitle => 'No notebooks yet';

  @override
  String get noNotebooksBody =>
      'Make a notebook to write, type and draw on its pages.';

  @override
  String get emptyNotebookBody => 'This notebook has no pages yet.';

  @override
  String get stickyNote => 'Sticky note';

  @override
  String get stickyHint => 'Write on the note…';

  @override
  String get attachedPage => 'Attached page';

  @override
  String get pageGone => 'The attached page no longer exists.';

  @override
  String get textHint => 'Type here';

  @override
  String get add => 'Add';

  @override
  String get selectNotebook =>
      'Pick a notebook from the list, or make a new one.';

  @override
  String get toolFountain => 'Fountain pen';

  @override
  String get toolBrush => 'Brush';

  @override
  String get reading => 'Reading';

  @override
  String get scrollSpeed => 'Mouse wheel speed';

  @override
  String get smoothScrolling => 'Smooth scrolling in PDFs';

  @override
  String get slower => 'Slower';

  @override
  String get faster => 'Faster';

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
      'Varagh ships without keys of its own. You register an app with the provider once, for free, and paste its keys here. Your data then goes only to your own account.';

  @override
  String get howToGetKeys => 'How to get the keys';

  @override
  String get signInWithBrowser => 'Sign in with browser';

  @override
  String get waitingForBrowser => 'Waiting for the browser…';

  @override
  String get signedIn => 'Signed in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInFailed =>
      'Sign-in didn\'t complete. Check the keys and try again.';

  @override
  String get signInDonePage =>
      'Signed in. You can close this window and return to Varagh.';

  @override
  String get syncFailedCloud =>
      'Sync failed. Check your connection, or sign in again.';

  @override
  String get close => 'Close';

  @override
  String get googleGuide =>
      '1. Open console.cloud.google.com and create a new project.\n2. In “APIs & Services” → “Library”, find “Google Drive API” and press Enable.\n3. Open “OAuth consent screen”. Choose External, enter an app name and your email, and add your own Google address under Test users.\n4. In “Credentials” → “Create credentials” → “OAuth client ID”, choose the type “Desktop app”.\n5. Copy the Client ID and Client secret it shows and paste them here.\n6. Press “Sign in with browser” and approve.\n\nWhile the app is in Testing, Google asks you to sign in again every 7 days. Pressing “Publish app” on the consent screen removes that.';

  @override
  String get microsoftGuide =>
      '1. Open portal.azure.com and go to “App registrations” → “New registration”.\n2. Enter a name. Under Supported account types choose one that includes personal Microsoft accounts.\n3. Under Redirect URI choose “Public client/native (mobile & desktop)” and enter http://localhost\n4. Press Register. Then open “Authentication” and turn on “Allow public client flows”.\n5. Copy the “Application (client) ID” from the Overview page and paste it here. There is no secret.\n6. Press “Sign in with browser” and approve.\n\nIf the portal says you need a directory, creating a free Azure account gives you one.';
}
