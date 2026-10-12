// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Zanzibarr';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get appSectionTitle => 'App';

  @override
  String get appSectionSubtitle =>
      'Sprach- und Darstellungseinstellungen werden auf diesem Gerät gespeichert.';

  @override
  String get languageLabel => 'Sprache';

  @override
  String get themeLabel => 'Darstellung';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get advancedSettings => 'Erweiterte Einstellungen';

  @override
  String get play => 'Abspielen';

  @override
  String get pause => 'Pause';

  @override
  String get selectNzbAndPlay => 'NZB auswählen und abspielen';

  @override
  String get selectNzbHint => 'Eine .nzb-Datei aus dem Dateisystem öffnen';

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
  String get engineStarting => 'Lokale Wiedergabe-Engine wird vorbereitet…';

  @override
  String get engineStartFailed =>
      'Die lokale Wiedergabe-Engine konnte nicht gestartet werden';

  @override
  String get engineStartFailedHint =>
      'Überprüfen Sie die Engine-Dateien und die App-Installation und versuchen Sie es erneut.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String errorOpenNzb(String error) {
    return 'Die NZB-Datei konnte nicht geöffnet werden: $error';
  }

  @override
  String get providerSettingsTooltip => 'Anbieter-Einstellungen';

  @override
  String get backTooltip => 'Zurück';

  @override
  String get providerTitle => 'Anbieter';

  @override
  String get nntpSectionTitle => 'NNTP-Verbindung';

  @override
  String get nntpSectionSubtitle =>
      'Die Daten werden nur im sicheren Schlüsselbund dieses Geräts gespeichert.';

  @override
  String get serverAddressLabel => 'Serveradresse';

  @override
  String get portLabel => 'Port';

  @override
  String get connectionLimitLabel => 'Verbindungslimit';

  @override
  String get connectionLimitHint => 'Tariflimit';

  @override
  String get usernameLabel => 'Benutzername';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get passwordShowTooltip => 'Passwort anzeigen';

  @override
  String get passwordHideTooltip => 'Passwort ausblenden';

  @override
  String get saveSecurelyLabel => 'Sicher speichern';

  @override
  String get savingLabel => 'Speichern…';

  @override
  String get settingsSaved => 'Einstellungen wurden sicher gespeichert.';

  @override
  String settingsSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get secureStorageUnavailable =>
      'Auf den sicheren Speicher konnte nicht zugegriffen werden';

  @override
  String get connectionLimitWarning =>
      'Ein Verbindungslimit über dem Tarif Ihres Anbieters kann zu einem Fehler „Zu viele Verbindungen“ führen.';

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
    return '$field ist erforderlich';
  }

  @override
  String validationIntegerRange(String field, int min, int max) {
    return '$field muss zwischen $min und $max liegen';
  }

  @override
  String get validationHostNoProtocol =>
      'Nur den Servernamen eingeben, ohne Protokoll oder Port';

  @override
  String get validationHostInvalid =>
      'Geben Sie einen gültigen Servernamen ein';

  @override
  String get closePlayer => 'Player schließen';

  @override
  String get fullscreen => 'Vollbild';

  @override
  String get subtitleControlsTooltip => 'Bildschirm-Steuerung für Untertitel';

  @override
  String get miniPlayer => 'Mini-Player';

  @override
  String get exitMiniPlayer => 'Mini-Player beenden';

  @override
  String get previousFrame => 'Vorheriges Bild';

  @override
  String get nextFrame => 'Nächstes Bild';

  @override
  String get playbackSpeedTooltip => 'Wiedergabegeschwindigkeit';

  @override
  String get audioTrack => 'Audiospur';

  @override
  String get subtitleTrack => 'Untertitelspur';

  @override
  String get muteTooltip => 'Stumm';

  @override
  String get unmuteTooltip => 'Stummschaltung aufheben';

  @override
  String get loadFromFile => 'Aus Datei laden…';

  @override
  String get auto => 'Automatisch';

  @override
  String get off => 'Aus';

  @override
  String get subtitleDecreaseTooltip => 'Untertitelgröße verkleinern';

  @override
  String get continueWatching => 'Weiter ansehen';

  @override
  String get upNext => 'Up next';

  @override
  String upNextEpisode(int season, int episode) {
    return 'Season $season, Episode $episode';
  }

  @override
  String get upNextFind => 'Find';

  @override
  String get videoFitCover => 'Bildschirm füllen';

  @override
  String get videoFitContain => 'An Bildschirm anpassen';

  @override
  String get updateAvailable => 'Update verfügbar';

  @override
  String get updateNow => 'Jetzt aktualisieren';

  @override
  String get updateLater => 'Später';

  @override
  String get updateSkip => 'Diese Version überspringen';

  @override
  String get updateDownloading => 'Update wird heruntergeladen…';

  @override
  String get updateOpenPage => 'Download-Seite öffnen';

  @override
  String updateFailed(String error) {
    return 'Update fehlgeschlagen: $error';
  }

  @override
  String get historyRemoveTooltip => 'Aus Verlauf entfernen';

  @override
  String historyRemaining(String time) {
    return 'Noch $time';
  }

  @override
  String get subtitleColor => 'Untertitelfarbe';

  @override
  String get subtitleIncreaseTooltip => 'Untertitelgröße vergrößern';

  @override
  String get subtitleMoveUpTooltip => 'Untertitel nach oben verschieben';

  @override
  String get subtitleMoveDownTooltip => 'Untertitel nach unten verschieben';

  @override
  String get subtitleEarlierTooltip =>
      'Untertitel um 0,1 Sekunden früher anzeigen';

  @override
  String get subtitleLaterTooltip => 'Untertitel um 0,1 Sekunden verzögern';

  @override
  String get closeSubtitleControlsTooltip => 'Untertitel-Steuerung schließen';

  @override
  String get smartCanvasAreaLabel => 'Smart Canvas-Zuschneidebereich';

  @override
  String get smartCanvasSemanticsHint =>
      'Zum Anwenden doppeltippen. Zum Abbrechen Escape drücken.';

  @override
  String get smartCanvasHintText => 'Doppeltippen: anwenden · Esc: abbrechen';

  @override
  String get cropHandleTopLeft => 'Zuschneidegriff oben links';

  @override
  String get cropHandleTopRight => 'Zuschneidegriff oben rechts';

  @override
  String get cropHandleBottomLeft => 'Zuschneidegriff unten links';

  @override
  String get cropHandleBottomRight => 'Zuschneidegriff unten rechts';

  @override
  String get statusPreparing => 'Vorbereiten…';

  @override
  String get engineBadgePreparing => 'Native libmpv wird vorbereitet…';

  @override
  String get errorProviderSettingsMissing =>
      'Die Anbieter-Einstellungen sind unvollständig. Geben Sie zuerst Ihre Daten im Einstellungsbildschirm ein.';

  @override
  String get statusConnecting =>
      'Verbindung wird hergestellt und erstes Segment abgerufen (Layout wird erkannt)…';

  @override
  String statusReadingVideoStructure(String filename) {
    return 'Videostruktur wird gelesen: $filename';
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
    return 'Puffern: $filename';
  }

  @override
  String statusPlaying(String filename) {
    return 'Wiedergabe: $filename';
  }

  @override
  String statusWaitingTracks(String filename) {
    return 'Warten auf Videospuren: $filename';
  }

  @override
  String bufferingPercent(String percent) {
    return ' $percent %';
  }

  @override
  String statusStartingVideo(String progress, String filename) {
    return 'Video wird gestartet$progress: $filename';
  }

  @override
  String errorStreamStartTimeout(int seconds) {
    return 'Der Usenet-Stream konnte nicht innerhalb von $seconds Sekunden gestartet werden. Die Anbieteverbindung, das erste Segment oder der NZB-Inhalt reagiert möglicherweise nicht.';
  }

  @override
  String errorVideoDetectTimeout(int seconds) {
    return 'Das Video konnte nicht innerhalb von $seconds Sekunden erkannt werden. Das NZB enthält möglicherweise ein mehrteiliges Archiv/PAR2 statt eines direkten Videos, ein Segment fehlt oder der Stream ist nicht lesbar.';
  }

  @override
  String get engineBadgeDiskCacheOff => 'Disk-Cache aus';

  @override
  String get engineBadgeSdrSafePath => 'SDR-Sicherheitspfad';

  @override
  String errorControlFailed(String error) {
    return 'Die Steuerung konnte nicht angewendet werden: $error';
  }

  @override
  String errorZoomFailed(String error) {
    return 'Zoom konnte nicht angewendet werden: $error';
  }

  @override
  String get errorPipUnavailable =>
      'Picture-in-Picture ist auf dieser Plattform nicht verfügbar.';

  @override
  String get fileTypeSubtitles => 'Untertitel';

  @override
  String get fileTypeAudioFiles => 'Audiodateien';

  @override
  String seekBackSeconds(int seconds) {
    return '$seconds Sekunden zurück';
  }

  @override
  String seekForwardSeconds(int seconds) {
    return '$seconds Sekunden vor';
  }

  @override
  String get cancelCanvasEditing => 'Canvas-Bearbeitung abbrechen';

  @override
  String get resetCanvas => 'Canvas zurücksetzen';

  @override
  String get subtitleControls => 'Untertitel-Steuerung';

  @override
  String get loopSetA => 'Punkt A setzen';

  @override
  String get loopSetB => 'Punkt B setzen';

  @override
  String get loopClear => 'A–B-Schleife aufheben';

  @override
  String get tuningMenuItem => 'Video- und Audioeinstellungen…';

  @override
  String get tuningDialogTitle => 'Video und Audio';

  @override
  String get closeTooltip => 'Schließen';

  @override
  String get videoPresetLabel => 'Video-Voreinstellung';

  @override
  String get presetNatural => 'Natürlich';

  @override
  String get presetCinema => 'Kino';

  @override
  String get presetVivid => 'Lebendig';

  @override
  String get gpuScalingLabel => 'GPU-Skalierung';

  @override
  String get presetLowPower => 'Energiesparend';

  @override
  String get presetBalanced => 'Ausgewogen';

  @override
  String get presetQuality => 'Qualität';

  @override
  String get audioPresetLabel => 'Audio-Voreinstellung';

  @override
  String get presetDialogue => 'Dialog';

  @override
  String get presetNight => 'Nacht';

  @override
  String get seekStepLabel => 'Sprungweite';

  @override
  String get periodicInfoLabel => 'Periodische Info';

  @override
  String get secondsUnitShort => 's';

  @override
  String get audioSyncLabel => 'Audio-Synchronisation';

  @override
  String get audioEarlierTooltip => 'Audio um 0,1 s früher';

  @override
  String get audioLaterTooltip => 'Audio um 0,1 s verzögern';

  @override
  String get decodingLabel => 'Decodierung';

  @override
  String get decodingHardware => 'Hardware';

  @override
  String get decodingSoftware => 'Software';

  @override
  String get dynamicRangeLabel => 'Dynamikumfang';

  @override
  String get hdrInfoText =>
      'Es können nur die vom Inhalt unterstützten Formate ausgewählt werden; die anderen sind deaktiviert. Bei Auswahl von SDR werden HDR-Inhalte per Tone Mapping auf bt.709 abgebildet (BT.2390 + Peak Detect). HDR10+ ist deaktiviert, da libmpv seine dynamischen Metadaten nicht erkennen kann; Dolby Vision wird bei Profilen mit HDR10-Basisebene unterstützt.';

  @override
  String get doneLabel => 'Fertig';

  @override
  String get videoPreparing => 'Video wird vorbereitet…';

  @override
  String get dvReshapeApplying => 'Dolby-Vision-Farbkorrektur wird angewendet…';

  @override
  String get dvReshapeActiveHw =>
      'Dolby-Vision-Farbkorrektur aktiv (Hardware-Dekodierung)';

  @override
  String get dvReshapeActiveSw =>
      'Dolby-Vision-Farbkorrektur aktiv (Software-Dekodierung)';

  @override
  String get dvReshapeFailed =>
      'Die Dolby-Vision-Farbkorrektur konnte auf diesem Gerät nicht gestartet werden. Tippe für Details.';

  @override
  String get dvReshapeFailedShort =>
      'Dolby-Vision-Farbkorrektur konnte nicht gestartet werden — Details in den erweiterten Einstellungen.';

  @override
  String get dvReshapeDiagnosticsTitle => 'DV-Korrektur-Diagnose';

  @override
  String get dvReshapeDiagnosticsEmpty =>
      'Keine Engine-Logzeilen für den Filter erfasst.';

  @override
  String get errFormatNotRecognized =>
      'Das Medienformat wurde nicht erkannt. Das NZB enthält möglicherweise ein Archiv oder PAR2-Wiederherstellungsdaten statt eines direkten Videos.';

  @override
  String get errLocalStreamUnreadable =>
      'Der lokale Videostream konnte nicht gelesen werden. Möglicherweise fehlt ein Usenet-Segment oder die Verbindung wurde unterbrochen.';

  @override
  String get errDecoderFailed =>
      'Der Video- oder Audio-Decoder konnte den Stream nicht öffnen.';

  @override
  String get errPlayerGeneric => 'Der Player konnte den Stream nicht öffnen.';

  @override
  String get errNoMpvDetail => 'libmpv lieferte keine Details.';

  @override
  String get errNoEngineDetail =>
      'Die Streaming-Engine lieferte keine Details.';

  @override
  String technicalDetail(String detail) {
    return 'Technisches Detail: $detail';
  }

  @override
  String get errProviderConnectionLimit =>
      'Das Limit für gleichzeitige Verbindungen des Usenet-Anbieters wurde erreicht. Schließe andere aktive Sitzungen oder warte kurz und versuche es erneut. Wenn es weiterhin auftritt, senke die Verbindungsanzahl in der App auf das Limit deines Tarifs.';

  @override
  String get errAuthFailed =>
      'Usenet-Authentifizierung fehlgeschlagen. Prüfe Benutzername und Passwort in den Anbieter-Einstellungen.';

  @override
  String get errRarEncrypted =>
      'Das RAR-Archiv ist verschlüsselt. Passwortgeschützte RAR-Releases werden nicht unterstützt; wähle ein unverschlüsselt gepacktes Release (STORE).';

  @override
  String get err7zPassword =>
      'Das Passwort des 7z-Archivs fehlt oder ist ungültig. Wähle das NZB, das das Passwort in seinen Metadaten trägt.';

  @override
  String get errArchiveCompressed =>
      'Dieses Archiv ist komprimiert. Sofortige Wiedergabe erfordert ein unkomprimiert gepacktes Release (COPY/STORE, 7z/RAR).';

  @override
  String get errArchiveSolid =>
      'Dieses Archiv ist solid. Zufälliges Springen erfordert ein als nicht-solid STORE gepacktes Release.';

  @override
  String get errRar4 =>
      'Dieses RAR-Archiv nutzt das alte RAR4-Format (oder älter). Nur RAR5-STORE-Releases sind abspielbar.';

  @override
  String get errSplitArchiveBroken =>
      'Das mehrteilige Archiv (7z/RAR) ist unvollständig oder beschädigt. Wähle ein vollständiges NZB mit allen Volumes und Segmenten.';

  @override
  String get errMissingSegments =>
      'Das NZB ist unvollständig oder beschädigt: nicht alle benötigten Usenet-Segmente können gefunden werden. Wähle ein anderes, vollständiges NZB für dieses Release.';

  @override
  String get errConnectionFailed =>
      'Verbindung zum Usenet-Anbieter fehlgeschlagen. Prüfe deine Internetverbindung, die Serveradresse, den Port und die Erreichbarkeit des Anbieters.';

  @override
  String get errNzbUnreadable =>
      'Die NZB-Datei konnte nicht gelesen werden oder ist beschädigt. Wähle eine gültige, vollständige NZB-Datei.';

  @override
  String get errArchiveNotPlayable =>
      'Das Archiv (7z/RAR) im NZB ist nicht abspielbar oder seine Struktur ist beschädigt. Wähle ein vollständiges STORE-Release.';

  @override
  String get errNoPlayableMedia =>
      'Im NZB wurde kein unterstützter Videostream gefunden. Wähle ein Release mit direkten Medien oder einem unterstützten STORE-Archiv.';

  @override
  String get errStreamStartupGeneric =>
      'Der Stream konnte nicht gestartet werden. Prüfe den NZB-Inhalt und die Anbieterverbindung.';

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
