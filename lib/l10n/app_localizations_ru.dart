// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Zanzibarr';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get appSectionTitle => 'Приложение';

  @override
  String get appSectionSubtitle =>
      'Настройки языка и внешнего вида хранятся на этом устройстве.';

  @override
  String get languageLabel => 'Язык';

  @override
  String get themeLabel => 'Внешний вид';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get advancedSettings => 'Расширенные настройки';

  @override
  String get play => 'Воспроизвести';

  @override
  String get pause => 'Пауза';

  @override
  String get selectNzbAndPlay => 'Выбрать NZB и воспроизвести';

  @override
  String get selectNzbHint => 'Откройте файл .nzb из файловой системы';

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
  String get engineStarting => 'Подготовка локального движка воспроизведения…';

  @override
  String get engineStartFailed =>
      'Не удалось запустить локальный движок воспроизведения';

  @override
  String get engineStartFailedHint =>
      'Проверьте файлы движка и установку приложения, затем повторите попытку.';

  @override
  String get retry => 'Повторить';

  @override
  String errorOpenNzb(String error) {
    return 'Не удалось открыть файл NZB: $error';
  }

  @override
  String get providerSettingsTooltip => 'Настройки провайдера';

  @override
  String get backTooltip => 'Назад';

  @override
  String get providerTitle => 'Провайдер';

  @override
  String get nntpSectionTitle => 'Подключение NNTP';

  @override
  String get nntpSectionSubtitle =>
      'Данные хранятся только в защищённой связке ключей этого устройства.';

  @override
  String get serverAddressLabel => 'Адрес сервера';

  @override
  String get portLabel => 'Порт';

  @override
  String get connectionLimitLabel => 'Лимит соединений';

  @override
  String get connectionLimitHint => 'Лимит тарифа';

  @override
  String get usernameLabel => 'Имя пользователя';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get passwordShowTooltip => 'Показать пароль';

  @override
  String get passwordHideTooltip => 'Скрыть пароль';

  @override
  String get saveSecurelyLabel => 'Сохранить безопасно';

  @override
  String get savingLabel => 'Сохранение…';

  @override
  String get settingsSaved => 'Настройки сохранены в защищённом хранилище.';

  @override
  String settingsSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get secureStorageUnavailable => 'Нет доступа к защищённому хранилищу';

  @override
  String get connectionLimitWarning =>
      'Установка лимита соединений выше тарифа вашего провайдера может вызвать ошибку «слишком много соединений».';

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
    return 'Заполните поле «$field»';
  }

  @override
  String validationIntegerRange(String field, int min, int max) {
    return '«$field»: введите целое число от $min до $max';
  }

  @override
  String get validationHostNoProtocol =>
      'Укажите только имя сервера, без протокола и порта';

  @override
  String get validationHostInvalid => 'Введите допустимое имя сервера';

  @override
  String get closePlayer => 'Закрыть плеер';

  @override
  String get fullscreen => 'Во весь экран';

  @override
  String get subtitleControlsTooltip =>
      'Экранные элементы управления субтитрами';

  @override
  String get miniPlayer => 'Мини-плеер';

  @override
  String get exitMiniPlayer => 'Выйти из мини-плеера';

  @override
  String get previousFrame => 'Предыдущий кадр';

  @override
  String get nextFrame => 'Следующий кадр';

  @override
  String get playbackSpeedTooltip => 'Скорость воспроизведения';

  @override
  String get audioTrack => 'Аудиодорожка';

  @override
  String get subtitleTrack => 'Дорожка субтитров';

  @override
  String get muteTooltip => 'Выключить звук';

  @override
  String get unmuteTooltip => 'Включить звук';

  @override
  String get loadFromFile => 'Загрузить из файла…';

  @override
  String get auto => 'Авто';

  @override
  String get off => 'Выкл.';

  @override
  String get subtitleDecreaseTooltip => 'Уменьшить размер субтитров';

  @override
  String get continueWatching => 'Продолжить просмотр';

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
  String get videoFitCover => 'Заполнить экран';

  @override
  String get videoFitContain => 'Вписать в экран';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateSkip => 'Пропустить эту версию';

  @override
  String get updateDownloading => 'Загрузка обновления…';

  @override
  String get updateOpenPage => 'Открыть страницу загрузки';

  @override
  String updateFailed(String error) {
    return 'Ошибка обновления: $error';
  }

  @override
  String get historyRemoveTooltip => 'Удалить из истории';

  @override
  String historyRemaining(String time) {
    return 'Осталось $time';
  }

  @override
  String get subtitleColor => 'Цвет субтитров';

  @override
  String get subtitleIncreaseTooltip => 'Увеличить размер субтитров';

  @override
  String get subtitleMoveUpTooltip => 'Поднять субтитры выше';

  @override
  String get subtitleMoveDownTooltip => 'Опустить субтитры ниже';

  @override
  String get subtitleEarlierTooltip => 'Сдвинуть субтитры на 0,1 с раньше';

  @override
  String get subtitleLaterTooltip => 'Задержать субтитры на 0,1 с';

  @override
  String get closeSubtitleControlsTooltip =>
      'Закрыть элементы управления субтитрами';

  @override
  String get smartCanvasAreaLabel => 'Область кадрирования Smart Canvas';

  @override
  String get smartCanvasSemanticsHint =>
      'Дважды коснитесь, чтобы применить. Нажмите Escape для отмены.';

  @override
  String get smartCanvasHintText => 'Двойное касание: применить · Esc: отмена';

  @override
  String get cropHandleTopLeft => 'Верхний левый маркер кадрирования';

  @override
  String get cropHandleTopRight => 'Верхний правый маркер кадрирования';

  @override
  String get cropHandleBottomLeft => 'Нижний левый маркер кадрирования';

  @override
  String get cropHandleBottomRight => 'Нижний правый маркер кадрирования';

  @override
  String get statusPreparing => 'Подготовка…';

  @override
  String get engineBadgePreparing => 'Подготовка нативного libmpv…';

  @override
  String get errorProviderSettingsMissing =>
      'Настройки провайдера не заполнены. Сначала введите данные на экране настроек.';

  @override
  String get statusConnecting =>
      'Подключение и получение первого сегмента (изучение структуры)…';

  @override
  String statusReadingVideoStructure(String filename) {
    return 'Чтение структуры видео: $filename';
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
    return 'Буферизация: $filename';
  }

  @override
  String statusPlaying(String filename) {
    return 'Воспроизведение: $filename';
  }

  @override
  String statusWaitingTracks(String filename) {
    return 'Ожидание видеодорожек: $filename';
  }

  @override
  String bufferingPercent(String percent) {
    return ' $percent%';
  }

  @override
  String statusStartingVideo(String progress, String filename) {
    return 'Запуск видео$progress: $filename';
  }

  @override
  String errorStreamStartTimeout(int seconds) {
    return 'Поток Usenet не удалось запустить за $seconds сек. Соединение с провайдером, первый сегмент или содержимое NZB могут не отвечать.';
  }

  @override
  String errorVideoDetectTimeout(int seconds) {
    return 'Не удалось распознать видео за $seconds сек. Возможно, NZB содержит многотомный архив/PAR2 вместо видео, отсутствует сегмент или поток не читается.';
  }

  @override
  String get engineBadgeDiskCacheOff => 'кэш на диске выкл.';

  @override
  String get engineBadgeSdrSafePath => 'безопасный путь SDR';

  @override
  String errorControlFailed(String error) {
    return 'Не удалось применить действие: $error';
  }

  @override
  String errorZoomFailed(String error) {
    return 'Не удалось применить масштабирование: $error';
  }

  @override
  String get errorPipUnavailable =>
      'Picture-in-Picture недоступен на этой платформе.';

  @override
  String get fileTypeSubtitles => 'Субтитры';

  @override
  String get fileTypeAudioFiles => 'Аудиофайлы';

  @override
  String seekBackSeconds(int seconds) {
    return 'Назад на $seconds с';
  }

  @override
  String seekForwardSeconds(int seconds) {
    return 'Вперёд на $seconds с';
  }

  @override
  String get cancelCanvasEditing => 'Отменить редактирование холста';

  @override
  String get resetCanvas => 'Сбросить холст';

  @override
  String get subtitleControls => 'Управление субтитрами';

  @override
  String get loopSetA => 'Установить точку A';

  @override
  String get loopSetB => 'Установить точку B';

  @override
  String get loopClear => 'Сбросить цикл A–B';

  @override
  String get tuningMenuItem => 'Настройки видео и аудио…';

  @override
  String get tuningDialogTitle => 'Видео и аудио';

  @override
  String get closeTooltip => 'Закрыть';

  @override
  String get videoPresetLabel => 'Пресет видео';

  @override
  String get presetNatural => 'Естественный';

  @override
  String get presetCinema => 'Кино';

  @override
  String get presetVivid => 'Яркий';

  @override
  String get gpuScalingLabel => 'Масштабирование GPU';

  @override
  String get presetLowPower => 'Энергосбережение';

  @override
  String get presetBalanced => 'Сбалансированный';

  @override
  String get presetQuality => 'Качество';

  @override
  String get audioPresetLabel => 'Пресет аудио';

  @override
  String get presetDialogue => 'Диалоги';

  @override
  String get presetNight => 'Ночной';

  @override
  String get seekStepLabel => 'Шаг перемотки';

  @override
  String get periodicInfoLabel => 'Периодическая информация';

  @override
  String get secondsUnitShort => 'с';

  @override
  String get audioSyncLabel => 'Синхронизация аудио';

  @override
  String get audioEarlierTooltip => 'Сдвинуть аудио на 0,1 с раньше';

  @override
  String get audioLaterTooltip => 'Задержать аудио на 0,1 с';

  @override
  String get decodingLabel => 'Декодирование';

  @override
  String get decodingHardware => 'Аппаратное';

  @override
  String get decodingSoftware => 'Программное';

  @override
  String get dynamicRangeLabel => 'Динамический диапазон';

  @override
  String get hdrInfoText =>
      'Можно выбрать только форматы, присутствующие в контенте; остальные недоступны. При выборе SDR HDR-контент тонально отображается в bt.709 (BT.2390 + peak detect). HDR10+ отключён, так как libmpv не может определить его динамические метаданные; Dolby Vision поддерживается в профилях с базовым слоем HDR10.';

  @override
  String get doneLabel => 'Готово';

  @override
  String get videoPreparing => 'Подготовка видео…';

  @override
  String get dvReshapeApplying => 'Применяется цветокоррекция Dolby Vision…';

  @override
  String get dvReshapeActiveHw =>
      'Цветокоррекция Dolby Vision активна (аппаратное декодирование)';

  @override
  String get dvReshapeActiveSw =>
      'Цветокоррекция Dolby Vision активна (программное декодирование)';

  @override
  String get dvReshapeFailed =>
      'Не удалось запустить цветокоррекцию Dolby Vision на этом устройстве. Нажмите для подробностей.';

  @override
  String get dvReshapeFailedShort =>
      'Не удалось запустить цветокоррекцию Dolby Vision — подробности в расширенных настройках.';

  @override
  String get dvReshapeDiagnosticsTitle => 'Диагностика коррекции DV';

  @override
  String get dvReshapeDiagnosticsEmpty =>
      'Строки журнала движка для фильтра не зафиксированы.';

  @override
  String get errFormatNotRecognized =>
      'Не удалось распознать формат медиа. Возможно, NZB содержит архив или данные восстановления PAR2 вместо прямого видео.';

  @override
  String get errLocalStreamUnreadable =>
      'Не удалось прочитать локальный видеопоток. Возможно, отсутствует сегмент Usenet или соединение прервалось.';

  @override
  String get errDecoderFailed =>
      'Видео- или аудиодекодер не смог открыть поток.';

  @override
  String get errPlayerGeneric => 'Плеер не смог открыть поток.';

  @override
  String get errNoMpvDetail => 'libmpv не дал подробностей.';

  @override
  String get errNoEngineDetail => 'Потоковый движок не дал подробностей.';

  @override
  String technicalDetail(String detail) {
    return 'Техническая деталь: $detail';
  }

  @override
  String get errProviderConnectionLimit =>
      'Достигнут лимит одновременных подключений провайдера Usenet. Закройте другие активные сессии или подождите и повторите. Если не поможет, уменьшите число подключений в приложении до лимита вашего тарифа.';

  @override
  String get errAuthFailed =>
      'Ошибка аутентификации Usenet. Проверьте имя пользователя и пароль в настройках провайдера.';

  @override
  String get errRarEncrypted =>
      'RAR-архив зашифрован. Защищённые паролем RAR-релизы не поддерживаются; выберите релиз, упакованный без шифрования (STORE).';

  @override
  String get err7zPassword =>
      'Пароль 7z-архива отсутствует или неверен. Выберите NZB, который несёт пароль в своих метаданных.';

  @override
  String get errArchiveCompressed =>
      'Этот архив сжат. Для мгновенного воспроизведения нужен релиз, упакованный без сжатия (COPY/STORE, 7z/RAR).';

  @override
  String get errArchiveSolid =>
      'Этот архив сплошной (solid). Для произвольного перематывания нужен релиз, упакованный как non-solid STORE.';

  @override
  String get errRar4 =>
      'Этот RAR-архив использует устаревший формат RAR4 (или старше). Воспроизводятся только релизы RAR5 STORE.';

  @override
  String get errSplitArchiveBroken =>
      'Многотомный архив (7z/RAR) неполный или повреждён. Выберите полный NZB, включающий все тома и сегменты.';

  @override
  String get errMissingSegments =>
      'NZB неполный или повреждён: не удаётся найти все нужные сегменты Usenet. Выберите другой, полный NZB для этого релиза.';

  @override
  String get errConnectionFailed =>
      'Не удалось подключиться к провайдеру Usenet. Проверьте интернет-соединение, адрес сервера, порт и доступность провайдера.';

  @override
  String get errNzbUnreadable =>
      'Файл NZB не удалось прочитать или он повреждён. Выберите действительный, полный файл NZB.';

  @override
  String get errArchiveNotPlayable =>
      'Архив (7z/RAR) в NZB не воспроизводится или его структура повреждена. Выберите полный STORE-релиз.';

  @override
  String get errNoPlayableMedia =>
      'В NZB не найден поддерживаемый видеопоток. Выберите релиз с прямым видео или поддерживаемым STORE-архивом.';

  @override
  String get errStreamStartupGeneric =>
      'Не удалось запустить поток. Проверьте содержимое NZB и подключение провайдера.';

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
  String get historyRemoved => 'Removed from continue watching';

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
