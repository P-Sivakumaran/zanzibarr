// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zanzibarr';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appSectionTitle => 'Application';

  @override
  String get appSectionSubtitle =>
      'Language and appearance preferences are stored on this device.';

  @override
  String get languageLabel => 'Language';

  @override
  String get themeLabel => 'Appearance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get selectNzbAndPlay => 'Select NZB and play';

  @override
  String get selectNzbHint => 'Open a .nzb from the file system';

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
  String get engineStarting => 'Preparing the local playback engine…';

  @override
  String get engineStartFailed =>
      'The local playback engine could not be started';

  @override
  String get engineStartFailedHint =>
      'Check the engine files and the app installation, then try again.';

  @override
  String get retry => 'Try again';

  @override
  String errorOpenNzb(String error) {
    return 'Could not open the NZB file: $error';
  }

  @override
  String get providerSettingsTooltip => 'Provider settings';

  @override
  String get backTooltip => 'Back';

  @override
  String get providerTitle => 'Provider';

  @override
  String get nntpSectionTitle => 'NNTP connection';

  @override
  String get nntpSectionSubtitle =>
      'Details are stored only in this device\'s secure keychain.';

  @override
  String get serverAddressLabel => 'Server address';

  @override
  String get portLabel => 'Port';

  @override
  String get connectionLimitLabel => 'Connection limit';

  @override
  String get connectionLimitHint => 'Plan limit';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordShowTooltip => 'Show password';

  @override
  String get passwordHideTooltip => 'Hide password';

  @override
  String get saveSecurelyLabel => 'Save securely';

  @override
  String get savingLabel => 'Saving…';

  @override
  String get settingsSaved => 'Settings saved to secure storage.';

  @override
  String settingsSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get secureStorageUnavailable => 'Secure storage could not be accessed';

  @override
  String get connectionLimitWarning =>
      'Setting the connection limit above your provider\'s plan may cause a “too many connections” error.';

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
    return '$field is required';
  }

  @override
  String validationIntegerRange(String field, int min, int max) {
    return '$field must be between $min and $max';
  }

  @override
  String get validationHostNoProtocol =>
      'Enter only the server name, without protocol or port';

  @override
  String get validationHostInvalid => 'Enter a valid server name';

  @override
  String get closePlayer => 'Close player';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get subtitleControlsTooltip => 'On-screen subtitle controls';

  @override
  String get miniPlayer => 'Mini player';

  @override
  String get exitMiniPlayer => 'Exit mini player';

  @override
  String get previousFrame => 'Previous frame';

  @override
  String get nextFrame => 'Next frame';

  @override
  String get playbackSpeedTooltip => 'Playback speed';

  @override
  String get audioTrack => 'Audio track';

  @override
  String get subtitleTrack => 'Subtitle track';

  @override
  String get muteTooltip => 'Mute';

  @override
  String get unmuteTooltip => 'Unmute';

  @override
  String get loadFromFile => 'Load from file…';

  @override
  String get auto => 'Auto';

  @override
  String get off => 'Off';

  @override
  String get subtitleDecreaseTooltip => 'Decrease subtitle size';

  @override
  String get continueWatching => 'Continue watching';

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
  String get videoFitCover => 'Fill screen';

  @override
  String get videoFitContain => 'Fit to screen';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkip => 'Skip this version';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String get updateOpenPage => 'Open download page';

  @override
  String updateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get historyRemoveTooltip => 'Remove from history';

  @override
  String historyRemaining(String time) {
    return '$time left';
  }

  @override
  String get subtitleColor => 'Subtitle color';

  @override
  String get subtitleIncreaseTooltip => 'Increase subtitle size';

  @override
  String get subtitleMoveUpTooltip => 'Move subtitle up';

  @override
  String get subtitleMoveDownTooltip => 'Move subtitle down';

  @override
  String get subtitleEarlierTooltip => 'Move subtitle 0.1 seconds earlier';

  @override
  String get subtitleLaterTooltip => 'Delay subtitle by 0.1 seconds';

  @override
  String get closeSubtitleControlsTooltip => 'Close subtitle controls';

  @override
  String get smartCanvasAreaLabel => 'Smart Canvas crop area';

  @override
  String get smartCanvasSemanticsHint =>
      'Double-tap to apply. Press Escape to cancel.';

  @override
  String get smartCanvasHintText => 'Double-tap: apply · Esc: cancel';

  @override
  String get cropHandleTopLeft => 'Top-left crop handle';

  @override
  String get cropHandleTopRight => 'Top-right crop handle';

  @override
  String get cropHandleBottomLeft => 'Bottom-left crop handle';

  @override
  String get cropHandleBottomRight => 'Bottom-right crop handle';

  @override
  String get statusPreparing => 'Preparing…';

  @override
  String get engineBadgePreparing => 'Preparing native libmpv…';

  @override
  String get errorProviderSettingsMissing =>
      'Provider settings are incomplete. Enter your details on the settings screen first.';

  @override
  String get statusConnecting =>
      'Connecting and fetching the first segment (learning layout)…';

  @override
  String statusReadingVideoStructure(String filename) {
    return 'Reading video structure: $filename';
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
    return 'Buffering: $filename';
  }

  @override
  String statusPlaying(String filename) {
    return 'Playing: $filename';
  }

  @override
  String statusWaitingTracks(String filename) {
    return 'Waiting for video tracks: $filename';
  }

  @override
  String bufferingPercent(String percent) {
    return ' $percent%';
  }

  @override
  String statusStartingVideo(String progress, String filename) {
    return 'Starting video$progress: $filename';
  }

  @override
  String errorStreamStartTimeout(int seconds) {
    return 'The Usenet stream could not start within $seconds seconds. The provider connection, the first segment, or the NZB content may not be responding.';
  }

  @override
  String errorVideoDetectTimeout(int seconds) {
    return 'The video could not be recognized within $seconds seconds. The NZB may contain a multi-part archive/PAR2 instead of a direct video, a segment may be missing, or the stream may be unreadable.';
  }

  @override
  String get engineBadgeDiskCacheOff => 'disk cache off';

  @override
  String get engineBadgeSdrSafePath => 'SDR safe path';

  @override
  String errorControlFailed(String error) {
    return 'Could not apply the control: $error';
  }

  @override
  String errorZoomFailed(String error) {
    return 'Could not apply zoom: $error';
  }

  @override
  String get errorPipUnavailable =>
      'Picture-in-Picture is not available on this platform.';

  @override
  String get fileTypeSubtitles => 'Subtitles';

  @override
  String get fileTypeAudioFiles => 'Audio files';

  @override
  String seekBackSeconds(int seconds) {
    return 'Back $seconds seconds';
  }

  @override
  String seekForwardSeconds(int seconds) {
    return 'Forward $seconds seconds';
  }

  @override
  String get cancelCanvasEditing => 'Cancel canvas editing';

  @override
  String get resetCanvas => 'Reset canvas';

  @override
  String get subtitleControls => 'Subtitle controls';

  @override
  String get loopSetA => 'Set point A';

  @override
  String get loopSetB => 'Set point B';

  @override
  String get loopClear => 'Clear A–B loop';

  @override
  String get tuningMenuItem => 'Video and audio settings…';

  @override
  String get tuningDialogTitle => 'Video and audio';

  @override
  String get closeTooltip => 'Close';

  @override
  String get videoPresetLabel => 'Video preset';

  @override
  String get presetNatural => 'Natural';

  @override
  String get presetCinema => 'Cinema';

  @override
  String get presetVivid => 'Vivid';

  @override
  String get gpuScalingLabel => 'GPU scaling';

  @override
  String get presetLowPower => 'Low power';

  @override
  String get presetBalanced => 'Balanced';

  @override
  String get presetQuality => 'Quality';

  @override
  String get audioPresetLabel => 'Audio preset';

  @override
  String get presetDialogue => 'Dialogue';

  @override
  String get presetNight => 'Night';

  @override
  String get seekStepLabel => 'Seek step';

  @override
  String get periodicInfoLabel => 'Periodic info';

  @override
  String get secondsUnitShort => 's';

  @override
  String get audioSyncLabel => 'Audio sync';

  @override
  String get audioEarlierTooltip => 'Move audio 0.1 s earlier';

  @override
  String get audioLaterTooltip => 'Delay audio by 0.1 s';

  @override
  String get decodingLabel => 'Decoding';

  @override
  String get decodingHardware => 'Hardware';

  @override
  String get decodingSoftware => 'Software';

  @override
  String get dynamicRangeLabel => 'Dynamic range';

  @override
  String get hdrInfoText =>
      'Only the formats carried by the content can be selected; the others are disabled. When SDR is selected, HDR content is tone-mapped to bt.709 (BT.2390 + peak detect). HDR10+ is disabled because libmpv cannot detect its dynamic metadata; Dolby Vision is supported on profiles that include an HDR10 base layer.';

  @override
  String get doneLabel => 'Done';

  @override
  String get videoPreparing => 'Preparing video…';

  @override
  String get dvReshapeApplying => 'Applying Dolby Vision color correction…';

  @override
  String get dvReshapeActiveHw =>
      'Dolby Vision color correction active (hardware decoding)';

  @override
  String get dvReshapeActiveSw =>
      'Dolby Vision color correction active (software decoding)';

  @override
  String get dvReshapeFailed =>
      'Dolby Vision color correction could not be started on this device. Tap for details.';

  @override
  String get dvReshapeFailedShort =>
      'Dolby Vision color correction could not be started — details in advanced settings.';

  @override
  String get dvReshapeDiagnosticsTitle => 'DV correction diagnostics';

  @override
  String get dvReshapeDiagnosticsEmpty =>
      'No engine log lines were captured for the filter.';

  @override
  String get errFormatNotRecognized =>
      'The media format could not be recognized. The NZB may contain an archive or PAR2 recovery data instead of a direct video.';

  @override
  String get errLocalStreamUnreadable =>
      'The local video stream could not be read. A Usenet segment may be missing or the connection dropped.';

  @override
  String get errDecoderFailed =>
      'The video or audio decoder could not open the stream.';

  @override
  String get errPlayerGeneric => 'The player could not open the stream.';

  @override
  String get errNoMpvDetail => 'libmpv gave no details.';

  @override
  String get errNoEngineDetail => 'The streaming engine gave no details.';

  @override
  String technicalDetail(String detail) {
    return 'Technical detail: $detail';
  }

  @override
  String get errProviderConnectionLimit =>
      'The Usenet provider\'s simultaneous connection limit was reached. Close other active sessions or wait a moment and try again. If it persists, lower the connection count in the app to your plan\'s limit.';

  @override
  String get errAuthFailed =>
      'Usenet authentication failed. Check the username and password in the provider settings.';

  @override
  String get errRarEncrypted =>
      'The RAR archive is encrypted. Password-protected RAR releases are not supported; choose a release packed unencrypted (STORE).';

  @override
  String get err7zPassword =>
      'The 7z archive\'s password is missing or invalid. Choose the NZB that carries the password in its metadata.';

  @override
  String get errArchiveCompressed =>
      'This archive is compressed. Instant playback requires a release packed uncompressed (COPY/STORE, 7z/RAR).';

  @override
  String get errArchiveSolid =>
      'This archive is solid. Random seeking requires a release packed as non-solid STORE.';

  @override
  String get errRar4 =>
      'This RAR archive uses the legacy RAR4 (or older) format. Only RAR5 STORE releases are playable.';

  @override
  String get errSplitArchiveBroken =>
      'The multi-part archive (7z/RAR) is incomplete or corrupt. Choose a complete NZB that includes all volumes and segments.';

  @override
  String get errMissingSegments =>
      'The NZB is incomplete or corrupt: not all required Usenet segments can be found. Choose another, complete NZB for this release.';

  @override
  String get errConnectionFailed =>
      'Could not connect to the Usenet provider. Check your internet connection, the server address, the port and the provider\'s reachability.';

  @override
  String get errNzbUnreadable =>
      'The NZB file could not be read or is corrupt. Choose a valid, complete NZB file.';

  @override
  String get errArchiveNotPlayable =>
      'The archive (7z/RAR) inside the NZB is not playable or its structure is corrupt. Choose a complete STORE release.';

  @override
  String get errNoPlayableMedia =>
      'No supported video stream was found in the NZB. Choose a release with direct media or a supported STORE archive.';

  @override
  String get errStreamStartupGeneric =>
      'The stream could not be started. Check the NZB content and the provider connection.';

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
  String get unsavedHint => 'Save your provider changes before leaving?';

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
