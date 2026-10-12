// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'Zanzibarr';

  @override
  String get settingsTitle => 'تنظیمات';

  @override
  String get appSectionTitle => 'برنامه';

  @override
  String get appSectionSubtitle =>
      'ترجیحات زبان و ظاهر در همین دستگاه ذخیره می‌شود.';

  @override
  String get languageLabel => 'زبان';

  @override
  String get themeLabel => 'ظاهر';

  @override
  String get themeDark => 'تیره';

  @override
  String get themeLight => 'روشن';

  @override
  String get advancedSettings => 'تنظیمات پیشرفته';

  @override
  String get play => 'پخش';

  @override
  String get pause => 'مکث';

  @override
  String get selectNzbAndPlay => 'انتخاب NZB و پخش';

  @override
  String get selectNzbHint => 'باز کردن یک فایل .nzb از سیستم فایل';

  @override
  String get searchIndexerCard => 'Search the indexer';

  @override
  String get searchIndexerCardHint => 'Find releases on a Newznab indexer';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Release name…';

  @override
  String get searchTooltip => 'Search';

  @override
  String get searchClearTooltip => 'Clear';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchEmptyHint => 'Type a release name to search your indexer.';

  @override
  String searchResultsTotal(int count) {
    return '$count results';
  }

  @override
  String searchDownloadFailed(String error) {
    return 'Could not download the NZB: $error';
  }

  @override
  String get indexerMissingHint =>
      'Set up the indexer URL and API key in settings first.';

  @override
  String get goToIndexerSettings => 'Open settings';

  @override
  String get engineStarting => 'در حال آماده‌سازی موتور پخش محلی…';

  @override
  String get engineStartFailed => 'موتور پخش محلی راه‌اندازی نشد';

  @override
  String get engineStartFailedHint =>
      'فایل‌های موتور و نصب برنامه را بررسی کنید و دوباره تلاش کنید.';

  @override
  String get retry => 'تلاش دوباره';

  @override
  String errorOpenNzb(String error) {
    return 'فایل NZB باز نشد: $error';
  }

  @override
  String get providerSettingsTooltip => 'تنظیمات ارائه‌دهنده';

  @override
  String get backTooltip => 'بازگشت';

  @override
  String get providerTitle => 'ارائه‌دهنده';

  @override
  String get nntpSectionTitle => 'اتصال NNTP';

  @override
  String get nntpSectionSubtitle =>
      'جزئیات فقط در کیف‌کلید امن همین دستگاه ذخیره می‌شود.';

  @override
  String get serverAddressLabel => 'آدرس سرور';

  @override
  String get portLabel => 'پورت';

  @override
  String get connectionLimitLabel => 'محدودیت اتصال';

  @override
  String get connectionLimitHint => 'محدودیت طرح';

  @override
  String get usernameLabel => 'نام کاربری';

  @override
  String get passwordLabel => 'رمز عبور';

  @override
  String get passwordShowTooltip => 'نمایش رمز عبور';

  @override
  String get passwordHideTooltip => 'پنهان کردن رمز عبور';

  @override
  String get saveSecurelyLabel => 'ذخیره امن';

  @override
  String get savingLabel => 'در حال ذخیره…';

  @override
  String get settingsSaved => 'تنظیمات در حافظه امن ذخیره شد.';

  @override
  String settingsSaveFailed(String error) {
    return 'ذخیره نشد: $error';
  }

  @override
  String get secureStorageUnavailable => 'دسترسی به حافظه امن ممکن نشد';

  @override
  String get connectionLimitWarning =>
      'تنظیم محدودیت اتصال بالاتر از طرح ارائه‌دهنده شما ممکن است خطای «اتصالات بیش از حد» ایجاد کند.';

  @override
  String get indexerSectionTitle => 'Indexer (Newznab)';

  @override
  String get indexerSectionSubtitle =>
      'Search one or more Newznab-compatible indexers at once; each API key is stored in this device\'s secure keychain. Disabled indexers are skipped but kept configured.';

  @override
  String get indexerUrlLabel => 'Indexer URL';

  @override
  String get indexerUrlInvalid =>
      'Enter a valid URL starting with http:// or https://';

  @override
  String get indexerApiKeyLabel => 'API key';

  @override
  String get indexerSaveLabel => 'Save indexer';

  @override
  String get indexerTestButton => 'Test connection';

  @override
  String indexerTestSuccess(String name) {
    return 'Connected: $name';
  }

  @override
  String indexerTestFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get indexerAddButton => 'Add indexer';

  @override
  String get indexerAddTitle => 'Add indexer';

  @override
  String get indexerEditTitle => 'Edit indexer';

  @override
  String get indexerNicknameLabel => 'Name';

  @override
  String get indexerNicknameHint => 'e.g. NZBFinder';

  @override
  String get indexerCustomOption => 'Custom';

  @override
  String get indexerEnabledLabel => 'Enabled';

  @override
  String get indexerDeleteButton => 'Delete';

  @override
  String get indexerDeleteConfirmTitle => 'Delete indexer?';

  @override
  String indexerDeleteConfirmHint(String name) {
    return '$name will be removed from your search.';
  }

  @override
  String indexerPartialFailureHint(int failed, int total) {
    return '$failed of $total indexers didn\'t respond; showing results from the rest.';
  }

  @override
  String validationRequired(String field) {
    return '$field الزامی است';
  }

  @override
  String validationIntegerRange(String field, int min, int max) {
    return '$field باید بین $min و $max باشد';
  }

  @override
  String get validationHostNoProtocol =>
      'فقط نام سرور را وارد کنید، بدون پروتکل یا پورت';

  @override
  String get validationHostInvalid => 'یک نام سرور معتبر وارد کنید';

  @override
  String get closePlayer => 'بستن پخش‌کننده';

  @override
  String get fullscreen => 'تمام‌صفحه';

  @override
  String get subtitleControlsTooltip => 'کنترل‌های زیرنویس روی صفحه';

  @override
  String get miniPlayer => 'پخش‌کننده کوچک';

  @override
  String get exitMiniPlayer => 'خروج از پخش‌کننده کوچک';

  @override
  String get previousFrame => 'فریم قبلی';

  @override
  String get nextFrame => 'فریم بعدی';

  @override
  String get playbackSpeedTooltip => 'سرعت پخش';

  @override
  String get audioTrack => 'تراک صوتی';

  @override
  String get subtitleTrack => 'تراک زیرنویس';

  @override
  String get muteTooltip => 'بی‌صدا کردن';

  @override
  String get unmuteTooltip => 'صدادار کردن';

  @override
  String get loadFromFile => 'بارگذاری از فایل…';

  @override
  String get auto => 'خودکار';

  @override
  String get off => 'خاموش';

  @override
  String get subtitleDecreaseTooltip => 'کوچک‌تر کردن زیرنویس';

  @override
  String get continueWatching => 'ادامه تماشا';

  @override
  String get upNext => 'Up next';

  @override
  String upNextEpisode(int season, int episode) {
    return 'Season $season, Episode $episode';
  }

  @override
  String get upNextFind => 'Find';

  @override
  String get trackShow => 'Track this show';

  @override
  String get untrackShow => 'Stop tracking';

  @override
  String get watchlistTitle => 'Tracked shows';

  @override
  String get watchlistCheckNow => 'Check for new episodes';

  @override
  String get watchlistRemoveTooltip => 'Stop tracking';

  @override
  String get watchlistNewEpisodesHint => 'It\'s been a while — check now?';

  @override
  String get watchlistLoadFailed => 'Couldn\'t load tracked shows.';

  @override
  String get watchlistRemoveFailed => 'Couldn\'t stop tracking this show.';

  @override
  String get watchlistUpdateFailed =>
      'Couldn\'t update tracking for this show.';

  @override
  String get videoFitCover => 'پر کردن صفحه';

  @override
  String get videoFitContain => 'متناسب با صفحه';

  @override
  String get updateAvailable => 'به‌روزرسانی موجود است';

  @override
  String get updateNow => 'همین حالا به‌روزرسانی کن';

  @override
  String get updateLater => 'بعداً';

  @override
  String get updateSkip => 'رد کردن این نسخه';

  @override
  String get updateDownloading => 'در حال دانلود به‌روزرسانی…';

  @override
  String get updateOpenPage => 'باز کردن صفحه دانلود';

  @override
  String updateFailed(String error) {
    return 'به‌روزرسانی ناموفق: $error';
  }

  @override
  String get historyRemoveTooltip => 'حذف از تاریخچه';

  @override
  String historyRemaining(String time) {
    return '$time باقی مانده';
  }

  @override
  String get subtitleColor => 'رنگ زیرنویس';

  @override
  String get subtitleIncreaseTooltip => 'بزرگ‌تر کردن زیرنویس';

  @override
  String get subtitleMoveUpTooltip => 'انتقال زیرنویس به بالا';

  @override
  String get subtitleMoveDownTooltip => 'انتقال زیرنویس به پایین';

  @override
  String get subtitleEarlierTooltip => 'زیرنویس 0.1 ثانیه زودتر';

  @override
  String get subtitleLaterTooltip => 'زیرنویس 0.1 ثانیه دیرتر';

  @override
  String get closeSubtitleControlsTooltip => 'بستن کنترل‌های زیرنویس';

  @override
  String get smartCanvasAreaLabel => 'ناحیه برش Smart Canvas';

  @override
  String get smartCanvasSemanticsHint =>
      'برای اعمال دوبار ضربه بزنید. برای لغو کلید Escape را فشار دهید.';

  @override
  String get smartCanvasHintText => 'دوبار ضربه: اعمال · Esc: لغو';

  @override
  String get cropHandleTopLeft => 'دستگیره برش بالا-چپ';

  @override
  String get cropHandleTopRight => 'دستگیره برش بالا-راست';

  @override
  String get cropHandleBottomLeft => 'دستگیره برش پایین-چپ';

  @override
  String get cropHandleBottomRight => 'دستگیره برش پایین-راست';

  @override
  String get statusPreparing => 'در حال آماده‌سازی…';

  @override
  String get engineBadgePreparing => 'در حال آماده‌سازی libmpv بومی…';

  @override
  String get errorProviderSettingsMissing =>
      'تنظیمات ارائه‌دهنده ناقص است. ابتدا اطلاعات خود را در صفحه تنظیمات وارد کنید.';

  @override
  String get statusConnecting =>
      'در حال اتصال و دریافت اولین قطعه (یادگیری ساختار)…';

  @override
  String statusReadingVideoStructure(String filename) {
    return 'در حال خواندن ساختار ویدیو: $filename';
  }

  @override
  String get statusPreparingCompressed =>
      'Compressed archive — decoding sequentially, the first open may take a while…';

  @override
  String get repairButton => 'Repair with PAR2';

  @override
  String get repairCancelButton => 'Cancel repair';

  @override
  String get repairPhaseLoading => 'Loading PAR2 index…';

  @override
  String get repairPhaseVerifying =>
      'Verifying slices (full pass over the set)…';

  @override
  String get repairPhaseSolving => 'Solving the recovery matrix…';

  @override
  String get repairPhaseRepairing => 'Rebuilding damaged slices…';

  @override
  String get repairPhaseWriting => 'Writing the repair overlay…';

  @override
  String get repairPhaseDone => 'Repair complete';

  @override
  String repairSuccess(int count) {
    return 'Repair complete: $count slices rebuilt. Reopening…';
  }

  @override
  String get repairClean =>
      'Verification finished — no damage found in this release.';

  @override
  String repairFailed(String error) {
    return 'Repair failed: $error';
  }

  @override
  String statusBuffering(String filename) {
    return 'در حال بافر کردن: $filename';
  }

  @override
  String statusPlaying(String filename) {
    return 'در حال پخش: $filename';
  }

  @override
  String statusWaitingTracks(String filename) {
    return 'در انتظار تراک‌های ویدیو: $filename';
  }

  @override
  String bufferingPercent(String percent) {
    return ' $percent%';
  }

  @override
  String statusStartingVideo(String progress, String filename) {
    return 'شروع ویدیو$progress: $filename';
  }

  @override
  String errorStreamStartTimeout(int seconds) {
    return 'استریم Usenet ظرف $seconds ثانیه شروع نشد. ممکن است اتصال ارائه‌دهنده، اولین قطعه یا محتوای NZB پاسخ ندهد.';
  }

  @override
  String errorVideoDetectTimeout(int seconds) {
    return 'ویدیو ظرف $seconds ثانیه شناسایی نشد. ممکن است NZB به‌جای ویدیوی مستقیم حاوی آرشیو چندبخشی/PAR2 باشد، یک قطعه گم شده باشد یا استریم خوانا نباشد.';
  }

  @override
  String get engineBadgeDiskCacheOff => 'کش دیسک خاموش';

  @override
  String get engineBadgeSdrSafePath => 'مسیر امن SDR';

  @override
  String errorControlFailed(String error) {
    return 'کنترل اعمال نشد: $error';
  }

  @override
  String errorZoomFailed(String error) {
    return 'زوم اعمال نشد: $error';
  }

  @override
  String get errorPipUnavailable =>
      'تصویر در تصویر (PiP) در این پلتفرم در دسترس نیست.';

  @override
  String get fileTypeSubtitles => 'زیرنویس‌ها';

  @override
  String get fileTypeAudioFiles => 'فایل‌های صوتی';

  @override
  String seekBackSeconds(int seconds) {
    return '$seconds ثانیه به عقب';
  }

  @override
  String seekForwardSeconds(int seconds) {
    return '$seconds ثانیه به جلو';
  }

  @override
  String get cancelCanvasEditing => 'لغو ویرایش بوم';

  @override
  String get resetCanvas => 'بازنشانی بوم';

  @override
  String get subtitleControls => 'کنترل‌های زیرنویس';

  @override
  String get loopSetA => 'تنظیم نقطه A';

  @override
  String get loopSetB => 'تنظیم نقطه B';

  @override
  String get loopClear => 'پاک کردن حلقه A–B';

  @override
  String get tuningMenuItem => 'تنظیمات ویدیو و صدا…';

  @override
  String get tuningDialogTitle => 'ویدیو و صدا';

  @override
  String get closeTooltip => 'بستن';

  @override
  String get videoPresetLabel => 'پیش‌تنظیم ویدیو';

  @override
  String get presetNatural => 'طبیعی';

  @override
  String get presetCinema => 'سینمایی';

  @override
  String get presetVivid => 'زنده';

  @override
  String get gpuScalingLabel => 'مقیاس‌بندی GPU';

  @override
  String get presetLowPower => 'مصرف کم';

  @override
  String get presetBalanced => 'متعادل';

  @override
  String get presetQuality => 'کیفیت';

  @override
  String get audioPresetLabel => 'پیش‌تنظیم صدا';

  @override
  String get presetDialogue => 'دیالوگ';

  @override
  String get presetNight => 'شب';

  @override
  String get seekStepLabel => 'گام جستجو';

  @override
  String get periodicInfoLabel => 'اطلاعات دوره‌ای';

  @override
  String get secondsUnitShort => 'ث';

  @override
  String get audioSyncLabel => 'همگام‌سازی صدا';

  @override
  String get audioEarlierTooltip => 'صدا 0.1 ثانیه زودتر';

  @override
  String get audioLaterTooltip => 'صدا 0.1 ثانیه دیرتر';

  @override
  String get decodingLabel => 'رمزگشایی';

  @override
  String get decodingHardware => 'سخت‌افزاری';

  @override
  String get decodingSoftware => 'نرم‌افزاری';

  @override
  String get dynamicRangeLabel => 'محدوده دینامیک';

  @override
  String get hdrInfoText =>
      'فقط قالب‌هایی که توسط محتوا ارائه می‌شوند قابل انتخاب هستند؛ بقیه غیرفعال‌اند. هنگام انتخاب SDR، محتوای HDR به bt.709 تون-مپ می‌شود (BT.2390 + تشخیص پیک). HDR10+ غیرفعال است زیرا libmpv نمی‌تواند متادیتای دینامیک آن را تشخیص دهد؛ Dolby Vision در پروفایل‌هایی پشتیبانی می‌شود که شامل لایه پایه HDR10 باشند.';

  @override
  String get doneLabel => 'انجام شد';

  @override
  String get videoPreparing => 'در حال آماده‌سازی ویدیو…';

  @override
  String get dvReshapeApplying => 'در حال اعمال تصحیح رنگ Dolby Vision…';

  @override
  String get dvReshapeActiveHw =>
      'تصحیح رنگ Dolby Vision فعال است (رمزگشایی سخت‌افزاری)';

  @override
  String get dvReshapeActiveSw =>
      'تصحیح رنگ Dolby Vision فعال است (رمزگشایی نرم‌افزاری)';

  @override
  String get dvReshapeFailed =>
      'تصحیح رنگ Dolby Vision روی این دستگاه آغاز نشد. برای جزئیات ضربه بزنید.';

  @override
  String get dvReshapeFailedShort =>
      'تصحیح رنگ Dolby Vision آغاز نشد — جزئیات در تنظیمات پیشرفته است.';

  @override
  String get dvReshapeDiagnosticsTitle => 'عیب‌یابی تصحیح DV';

  @override
  String get dvReshapeDiagnosticsEmpty =>
      'هیچ خط گزارشی از موتور برای فیلتر ثبت نشد.';

  @override
  String get errFormatNotRecognized =>
      'قالب رسانه شناسایی نشد. ممکن است NZB به‌جای ویدیوی مستقیم، آرشیو یا دادهٔ بازیابی PAR2 در بر داشته باشد.';

  @override
  String get errLocalStreamUnreadable =>
      'جریان ویدیوی محلی خوانده نشد. ممکن است یک بخش Usenet گم باشد یا اتصال قطع شده باشد.';

  @override
  String get errDecoderFailed =>
      'رمزگشای ویدیو یا صوت نتوانست جریان را باز کند.';

  @override
  String get errPlayerGeneric => 'پخش‌کننده نتوانست جریان را باز کند.';

  @override
  String get errNoMpvDetail => 'libmpv هیچ جزئیاتی ارائه نداد.';

  @override
  String get errNoEngineDetail => 'موتور پخش جریانی هیچ جزئیاتی ارائه نداد.';

  @override
  String technicalDetail(String detail) {
    return 'جزئیات فنی: $detail';
  }

  @override
  String get errProviderConnectionLimit =>
      'به حد اتصال‌های هم‌زمان ارائه‌دهندهٔ Usenet رسیدید. سایر جلسات فعال را ببندید یا کمی بعد دوباره تلاش کنید. اگر ادامه یافت، تعداد اتصال‌ها را در برنامه تا حد بسته‌تان کم کنید.';

  @override
  String get errAuthFailed =>
      'احراز هویت Usenet ناموفق بود. نام کاربری و رمز عبور را در تنظیمات ارائه‌دهنده بررسی کنید.';

  @override
  String get errRarEncrypted =>
      'آرشیو RAR رمزنگاری‌شده است. انتشارهای RAR محافظت‌شده با رمز پشتیبانی نمی‌شوند؛ انتشاری را انتخاب کنید که بدون رمزنگاری بسته‌بندی شده باشد (STORE).';

  @override
  String get err7zPassword =>
      'رمز آرشیو 7z وجود ندارد یا نامعتبر است. NZB‌ای را انتخاب کنید که رمز را در فراداده‌های خود دارد.';

  @override
  String get errArchiveCompressed =>
      'این آرشیو فشرده است. پخش فوری به انتشاری نیاز دارد که بدون فشرده‌سازی (COPY/STORE، 7z/RAR) بسته‌بندی شده باشد.';

  @override
  String get errArchiveSolid =>
      'این آرشیو ساختار solid دارد. جابه‌جایی تصادفی به انتشاری با بسته‌بندی STORE غیر-solid نیاز دارد.';

  @override
  String get errRar4 =>
      'این آرشیو RAR از قالب قدیمی (RAR4 یا قدیمی‌تر) استفاده می‌کند. فقط انتشارهای RAR5 STORE قابل پخش‌اند.';

  @override
  String get errSplitArchiveBroken =>
      'آرشیو چندبخشی (7z/RAR) ناقص یا خراب است. NZB کاملی را انتخاب کنید که همهٔ مجلدها و بخش‌ها را داشته باشد.';

  @override
  String get errMissingSegments =>
      'NZB ناقص یا خراب است: همهٔ بخش‌های لازم Usenet یافت نمی‌شوند. برای این انتشار یک NZB کامل دیگر انتخاب کنید.';

  @override
  String get errConnectionFailed =>
      'اتصال به ارائه‌دهندهٔ Usenet ممکن نشد. اتصال اینترنت، نشانی سرور، درگاه و دسترس‌پذیری ارائه‌دهنده را بررسی کنید.';

  @override
  String get errNzbUnreadable =>
      'فایل NZB خوانده نشد یا خراب است. یک فایل NZB معتبر و کامل انتخاب کنید.';

  @override
  String get errArchiveNotPlayable =>
      'آرشیو (7z/RAR) داخل NZB قابل پخش نیست یا ساختارش خراب است. یک انتشار STORE کامل انتخاب کنید.';

  @override
  String get errNoPlayableMedia =>
      'هیچ جریان ویدیویی پشتیبانی‌شده‌ای در NZB یافت نشد. انتشاری با رسانهٔ مستقیم یا آرشیو STORE پشتیبانی‌شده انتخاب کنید.';

  @override
  String get errStreamStartupGeneric =>
      'جریان آغاز نشد. محتوای NZB و اتصال ارائه‌دهنده را بررسی کنید.';

  @override
  String get castTooltip => 'Cast to TV';

  @override
  String get castDialogTitle => 'Cast to device';

  @override
  String get castSearching => 'Searching for devices…';

  @override
  String get castNoDevices => 'No cast devices found on your network.';

  @override
  String get castUnavailable => 'Casting is unavailable for this stream';

  @override
  String get castConnecting => 'Connecting…';

  @override
  String castPlayingOn(String device) {
    return 'Playing on $device';
  }

  @override
  String get castDisconnect => 'Disconnect';

  @override
  String castFailed(String error) {
    return 'Casting failed: $error';
  }

  @override
  String get subtitleFont => 'Subtitle font';

  @override
  String get entryPickerTitle => 'Choose what to play';

  @override
  String get entryPickerSubtitle =>
      'This NZB contains multiple videos — pick one to start streaming.';

  @override
  String get entryKindDirect => 'Video';

  @override
  String get entryKindArchive => 'Archive';

  @override
  String entryParts(int count) {
    return '$count parts';
  }

  @override
  String get providerSetupTitle => 'Set up Usenet provider';

  @override
  String get providerSetupHint =>
      'A Usenet provider is required to play NZBs. An indexer is optional and lets you search for releases. Save your provider details to continue.';

  @override
  String get providerTestButton => 'Test provider connection';

  @override
  String get providerTestSuccess =>
      'Connection and authentication succeeded. Save any changes to keep them.';

  @override
  String get providerTestFailed =>
      'Could not connect. Check the server, port, username, password, and your internet connection.';

  @override
  String get unsavedTitle => 'Unsaved changes';

  @override
  String get unsavedHint =>
      'Save your provider and indexer changes before leaving?';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get appearanceSavedHint =>
      'Language and appearance changes are saved automatically.';

  @override
  String get loadMore => 'Load more results';

  @override
  String get loadingMore => 'Loading more results…';

  @override
  String get searchPageFailed => 'More results could not be loaded. Try again.';

  @override
  String get searchFailedHint =>
      'Search failed. Check your internet connection and indexer settings, then try again.';

  @override
  String get searchDownloadHint =>
      'The NZB could not be downloaded. Check your connection and indexer settings, then try again.';

  @override
  String showingResults(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String get releaseDetails => 'Release details';

  @override
  String get moreControls => 'More playback controls';

  @override
  String get historyLoadFailed => 'Continue watching could not be loaded.';

  @override
  String get historyRemoveFailed =>
      'This item could not be removed. Try again.';

  @override
  String get historyUpdateFailed =>
      'This item could not be updated. Try again.';

  @override
  String get historyMarkWatchedTooltip => 'Mark as watched';

  @override
  String get historyMarkUnwatchedTooltip => 'Mark as unwatched';

  @override
  String get favoriteAddTooltip => 'Add to favorites';

  @override
  String get favoriteRemoveTooltip => 'Remove from favorites';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get recentlyWatchedTitle => 'Recently watched';

  @override
  String get historyRemoved => 'Removed from continue watching';

  @override
  String get historyFileMissing =>
      'This file is no longer available and can\'t be re-downloaded.';

  @override
  String get historyFileMissingIndexerGone =>
      'This file is no longer available; its original indexer isn\'t configured anymore.';

  @override
  String get historyFileMissingRedownloadFailed =>
      'This file is no longer available and could not be re-downloaded.';

  @override
  String get technicalDetailsLabel => 'Technical details';

  @override
  String get settingsLoadHint =>
      'Settings could not be loaded. Try again to access your saved details.';

  @override
  String get settingsWriteHint =>
      'Changes could not be saved. Keep this screen open and try again.';

  @override
  String get indexerMoveUp => 'Move indexer up';

  @override
  String get indexerMoveDown => 'Move indexer down';

  @override
  String get metadataSetupHint =>
      'Add your personal OMDb key to look up titles, summaries and available ratings. Test the key before saving if you want to check access.';

  @override
  String get metadataGetKey => 'Get an OMDb API key';

  @override
  String get metadataKeyFormat =>
      'Paste the API key only (letters and numbers), not a URL.';

  @override
  String get metadataKeyRequired => 'Enter an API key to test.';

  @override
  String get metadataTestKey => 'Test API key';

  @override
  String get metadataTesting => 'Testing API key…';

  @override
  String get metadataTestSuccess =>
      'Connected to OMDb. This API key works. Save changes to use it.';

  @override
  String get metadataTestFailed =>
      'Could not reach OMDb or read its response. Check your connection and try again.';

  @override
  String get metadataLinkFailed =>
      'The website could not be opened. Check that a browser is available.';

  @override
  String get metadataBrowseTitle => 'Movie and TV info';

  @override
  String get metadataConfigure => 'OMDb settings';

  @override
  String get metadataPrivacyHint =>
      'Look up a title or IMDb ID, then choose the correct year and type. Searches go to OMDb only when you request them.';

  @override
  String get metadataType => 'Type';

  @override
  String get metadataMovie => 'Movie';

  @override
  String get metadataSeries => 'TV series';

  @override
  String get metadataTitleLabel => 'Title for fallback search';

  @override
  String get metadataTitleRequired =>
      'Enter a title for indexers that need text search.';

  @override
  String get metadataImdbId => 'IMDb ID (optional)';

  @override
  String get metadataTvdbId => 'TVDB ID (optional)';

  @override
  String get metadataYear => 'Year (optional)';

  @override
  String get metadataSeason => 'Season (optional)';

  @override
  String get metadataEpisode => 'Episode (optional)';

  @override
  String get metadataInvalidId => 'Enter a valid ID.';

  @override
  String get metadataInvalidNumber => 'Enter a valid number.';

  @override
  String get metadataEpisodeNeedsSeason => 'Enter a season before an episode.';

  @override
  String get metadataFindReleases => 'Find releases';

  @override
  String get metadataQueryHint => 'Title or IMDb ID (tt...)';

  @override
  String get metadataKeyHint =>
      'Optional: add your personal OMDb API key for title lookup, plots, and available IMDb, Rotten Tomatoes, and Metacritic ratings. Release search works without it.';

  @override
  String get metadataApiKey => 'OMDb API key';

  @override
  String get metadataRemoveKeyHint =>
      'The key is saved securely. Clear this field and save to remove it.';

  @override
  String get metadataKeyFailed =>
      'OMDb rejected the API key. Check OMDb settings.';

  @override
  String get metadataLimit => 'OMDb request limit reached. Try again later.';

  @override
  String get metadataFailed =>
      'Movie information could not be loaded. Try again; release search is still available.';

  @override
  String get metadataNoRatings => 'No ratings available for this title.';

  @override
  String get metadataAttribution =>
      'Information and ratings via OMDb. Scores retain their original source and scale; availability varies.';

  @override
  String get structuredSearchTitle => 'Precise release search';

  @override
  String get structuredSearchHint =>
      'Use an IMDb or TVDB ID when supported. Other indexers use the title, year, and season/episode below.';

  @override
  String get structuredSearchActive =>
      'Selected title: ID search where supported; title search otherwise.';
}
