// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Zanzibarr';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get appSectionTitle => 'Aplicativo';

  @override
  String get appSectionSubtitle =>
      'As preferências de idioma e aparência são armazenadas neste dispositivo.';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get themeLabel => 'Aparência';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get advancedSettings => 'Configurações avançadas';

  @override
  String get play => 'Reproduzir';

  @override
  String get pause => 'Pausar';

  @override
  String get selectNzbAndPlay => 'Selecionar NZB e reproduzir';

  @override
  String get selectNzbHint => 'Abrir um .nzb do sistema de arquivos';

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
  String get engineStarting => 'Preparando o mecanismo de reprodução local…';

  @override
  String get engineStartFailed =>
      'Não foi possível iniciar o mecanismo de reprodução local';

  @override
  String get engineStartFailedHint =>
      'Verifique os arquivos do mecanismo e a instalação do aplicativo e tente novamente.';

  @override
  String get retry => 'Tentar novamente';

  @override
  String errorOpenNzb(String error) {
    return 'Não foi possível abrir o arquivo NZB: $error';
  }

  @override
  String get providerSettingsTooltip => 'Configurações do provedor';

  @override
  String get backTooltip => 'Voltar';

  @override
  String get providerTitle => 'Provedor';

  @override
  String get nntpSectionTitle => 'Conexão NNTP';

  @override
  String get nntpSectionSubtitle =>
      'Os dados são armazenados apenas no chaveiro seguro deste dispositivo.';

  @override
  String get serverAddressLabel => 'Endereço do servidor';

  @override
  String get portLabel => 'Porta';

  @override
  String get connectionLimitLabel => 'Limite de conexões';

  @override
  String get connectionLimitHint => 'Limite do plano';

  @override
  String get usernameLabel => 'Nome de usuário';

  @override
  String get passwordLabel => 'Senha';

  @override
  String get passwordShowTooltip => 'Mostrar senha';

  @override
  String get passwordHideTooltip => 'Ocultar senha';

  @override
  String get saveSecurelyLabel => 'Salvar com segurança';

  @override
  String get savingLabel => 'Salvando…';

  @override
  String get settingsSaved => 'Configurações salvas no armazenamento seguro.';

  @override
  String settingsSaveFailed(String error) {
    return 'Não foi possível salvar: $error';
  }

  @override
  String get secureStorageUnavailable =>
      'Não foi possível acessar o armazenamento seguro';

  @override
  String get connectionLimitWarning =>
      'Definir o limite de conexões acima do plano do seu provedor pode causar um erro de “conexões em excesso”.';

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
    return '$field é obrigatório';
  }

  @override
  String validationIntegerRange(String field, int min, int max) {
    return '$field deve estar entre $min e $max';
  }

  @override
  String get validationHostNoProtocol =>
      'Digite apenas o nome do servidor, sem protocolo nem porta';

  @override
  String get validationHostInvalid => 'Digite um nome de servidor válido';

  @override
  String get closePlayer => 'Fechar player';

  @override
  String get fullscreen => 'Tela cheia';

  @override
  String get subtitleControlsTooltip => 'Controles de legenda na tela';

  @override
  String get miniPlayer => 'Miniplayer';

  @override
  String get exitMiniPlayer => 'Sair do miniplayer';

  @override
  String get previousFrame => 'Quadro anterior';

  @override
  String get nextFrame => 'Próximo quadro';

  @override
  String get playbackSpeedTooltip => 'Velocidade de reprodução';

  @override
  String get audioTrack => 'Faixa de áudio';

  @override
  String get subtitleTrack => 'Faixa de legenda';

  @override
  String get muteTooltip => 'Silenciar';

  @override
  String get unmuteTooltip => 'Ativar som';

  @override
  String get loadFromFile => 'Carregar de arquivo…';

  @override
  String get auto => 'Automático';

  @override
  String get off => 'Desativado';

  @override
  String get subtitleDecreaseTooltip => 'Diminuir tamanho da legenda';

  @override
  String get continueWatching => 'Continuar a ver';

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
  String get videoFitCover => 'Preencher ecrã';

  @override
  String get videoFitContain => 'Ajustar ao ecrã';

  @override
  String get updateAvailable => 'Atualização disponível';

  @override
  String get updateNow => 'Atualizar agora';

  @override
  String get updateLater => 'Mais tarde';

  @override
  String get updateSkip => 'Ignorar esta versão';

  @override
  String get updateDownloading => 'A transferir a atualização…';

  @override
  String get updateOpenPage => 'Abrir página de transferência';

  @override
  String updateFailed(String error) {
    return 'Falha na atualização: $error';
  }

  @override
  String get historyRemoveTooltip => 'Remover do histórico';

  @override
  String historyRemaining(String time) {
    return 'Faltam $time';
  }

  @override
  String get subtitleColor => 'Cor das legendas';

  @override
  String get subtitleIncreaseTooltip => 'Aumentar tamanho da legenda';

  @override
  String get subtitleMoveUpTooltip => 'Mover legenda para cima';

  @override
  String get subtitleMoveDownTooltip => 'Mover legenda para baixo';

  @override
  String get subtitleEarlierTooltip => 'Adiantar legenda em 0,1 segundos';

  @override
  String get subtitleLaterTooltip => 'Atrasar legenda em 0,1 segundos';

  @override
  String get closeSubtitleControlsTooltip => 'Fechar controles de legenda';

  @override
  String get smartCanvasAreaLabel => 'Área de corte do Smart Canvas';

  @override
  String get smartCanvasSemanticsHint =>
      'Toque duas vezes para aplicar. Pressione Esc para cancelar.';

  @override
  String get smartCanvasHintText => 'Toque duplo: aplicar · Esc: cancelar';

  @override
  String get cropHandleTopLeft => 'Alça de corte superior esquerda';

  @override
  String get cropHandleTopRight => 'Alça de corte superior direita';

  @override
  String get cropHandleBottomLeft => 'Alça de corte inferior esquerda';

  @override
  String get cropHandleBottomRight => 'Alça de corte inferior direita';

  @override
  String get statusPreparing => 'Preparando…';

  @override
  String get engineBadgePreparing => 'Preparando libmpv nativo…';

  @override
  String get errorProviderSettingsMissing =>
      'As configurações do provedor estão incompletas. Insira seus dados primeiro na tela de configurações.';

  @override
  String get statusConnecting =>
      'Conectando e buscando o primeiro segmento (aprendendo o layout)…';

  @override
  String statusReadingVideoStructure(String filename) {
    return 'Lendo a estrutura do vídeo: $filename';
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
    return 'Armazenando em buffer: $filename';
  }

  @override
  String statusPlaying(String filename) {
    return 'Reproduzindo: $filename';
  }

  @override
  String statusWaitingTracks(String filename) {
    return 'Aguardando as faixas de vídeo: $filename';
  }

  @override
  String bufferingPercent(String percent) {
    return ' $percent%';
  }

  @override
  String statusStartingVideo(String progress, String filename) {
    return 'Iniciando o vídeo$progress: $filename';
  }

  @override
  String errorStreamStartTimeout(int seconds) {
    return 'O stream do Usenet não pôde ser iniciado em $seconds segundos. A conexão com o provedor, o primeiro segmento ou o conteúdo do NZB pode não estar respondendo.';
  }

  @override
  String errorVideoDetectTimeout(int seconds) {
    return 'O vídeo não pôde ser reconhecido em $seconds segundos. O NZB pode conter um arquivo/PAR2 multipartes em vez de um vídeo direto, um segmento pode estar faltando ou o stream pode estar ilegível.';
  }

  @override
  String get engineBadgeDiskCacheOff => 'cache de disco desativado';

  @override
  String get engineBadgeSdrSafePath => 'caminho seguro SDR';

  @override
  String errorControlFailed(String error) {
    return 'Não foi possível aplicar o controle: $error';
  }

  @override
  String errorZoomFailed(String error) {
    return 'Não foi possível aplicar o zoom: $error';
  }

  @override
  String get errorPipUnavailable =>
      'Picture-in-Picture não está disponível nesta plataforma.';

  @override
  String get fileTypeSubtitles => 'Legendas';

  @override
  String get fileTypeAudioFiles => 'Arquivos de áudio';

  @override
  String seekBackSeconds(int seconds) {
    return 'Voltar $seconds segundos';
  }

  @override
  String seekForwardSeconds(int seconds) {
    return 'Avançar $seconds segundos';
  }

  @override
  String get cancelCanvasEditing => 'Cancelar edição do canvas';

  @override
  String get resetCanvas => 'Redefinir canvas';

  @override
  String get subtitleControls => 'Controles de legenda';

  @override
  String get loopSetA => 'Definir ponto A';

  @override
  String get loopSetB => 'Definir ponto B';

  @override
  String get loopClear => 'Limpar loop A–B';

  @override
  String get tuningMenuItem => 'Configurações de vídeo e áudio…';

  @override
  String get tuningDialogTitle => 'Vídeo e áudio';

  @override
  String get closeTooltip => 'Fechar';

  @override
  String get videoPresetLabel => 'Predefinição de vídeo';

  @override
  String get presetNatural => 'Natural';

  @override
  String get presetCinema => 'Cinema';

  @override
  String get presetVivid => 'Vívido';

  @override
  String get gpuScalingLabel => 'Escalonamento de GPU';

  @override
  String get presetLowPower => 'Baixo consumo';

  @override
  String get presetBalanced => 'Equilibrado';

  @override
  String get presetQuality => 'Qualidade';

  @override
  String get audioPresetLabel => 'Predefinição de áudio';

  @override
  String get presetDialogue => 'Diálogo';

  @override
  String get presetNight => 'Noite';

  @override
  String get seekStepLabel => 'Passo de busca';

  @override
  String get periodicInfoLabel => 'Informações periódicas';

  @override
  String get secondsUnitShort => 's';

  @override
  String get audioSyncLabel => 'Sincronização de áudio';

  @override
  String get audioEarlierTooltip => 'Adiantar áudio em 0,1 s';

  @override
  String get audioLaterTooltip => 'Atrasar áudio em 0,1 s';

  @override
  String get decodingLabel => 'Decodificação';

  @override
  String get decodingHardware => 'Hardware';

  @override
  String get decodingSoftware => 'Software';

  @override
  String get dynamicRangeLabel => 'Faixa dinâmica';

  @override
  String get hdrInfoText =>
      'Somente os formatos presentes no conteúdo podem ser selecionados; os demais ficam desativados. Quando SDR está selecionado, o conteúdo HDR é mapeado em tom para bt.709 (BT.2390 + peak detect). HDR10+ está desativado porque o libmpv não consegue detectar seus metadados dinâmicos; Dolby Vision é suportado em perfis que incluem uma camada base HDR10.';

  @override
  String get doneLabel => 'Concluído';

  @override
  String get videoPreparing => 'Preparando o vídeo…';

  @override
  String get dvReshapeApplying => 'Aplicando a correção de cor Dolby Vision…';

  @override
  String get dvReshapeActiveHw =>
      'Correção de cor Dolby Vision ativa (decodificação por hardware)';

  @override
  String get dvReshapeActiveSw =>
      'Correção de cor Dolby Vision ativa (decodificação por software)';

  @override
  String get dvReshapeFailed =>
      'Não foi possível iniciar a correção de cor Dolby Vision neste dispositivo. Toque para ver detalhes.';

  @override
  String get dvReshapeFailedShort =>
      'A correção de cor Dolby Vision não pôde ser iniciada — detalhes nas configurações avançadas.';

  @override
  String get dvReshapeDiagnosticsTitle => 'Diagnóstico da correção DV';

  @override
  String get dvReshapeDiagnosticsEmpty =>
      'Nenhuma linha de log do motor capturada para o filtro.';

  @override
  String get errFormatNotRecognized =>
      'Não foi possível reconhecer o formato da mídia. O NZB pode conter um arquivo ou dados de recuperação PAR2 em vez de um vídeo direto.';

  @override
  String get errLocalStreamUnreadable =>
      'Não foi possível ler a transmissão de vídeo local. Um segmento da Usenet pode estar faltando ou a conexão caiu.';

  @override
  String get errDecoderFailed =>
      'O decodificador de vídeo ou áudio não conseguiu abrir a transmissão.';

  @override
  String get errPlayerGeneric =>
      'O reprodutor não conseguiu abrir a transmissão.';

  @override
  String get errNoMpvDetail => 'O libmpv não forneceu detalhes.';

  @override
  String get errNoEngineDetail =>
      'O motor de transmissão não forneceu detalhes.';

  @override
  String technicalDetail(String detail) {
    return 'Detalhe técnico: $detail';
  }

  @override
  String get errProviderConnectionLimit =>
      'O limite de conexões simultâneas do provedor Usenet foi atingido. Feche outras sessões ativas ou aguarde um momento e tente novamente. Se persistir, reduza o número de conexões no aplicativo para o limite do seu plano.';

  @override
  String get errAuthFailed =>
      'Falha na autenticação da Usenet. Verifique o nome de usuário e a senha nas configurações do provedor.';

  @override
  String get errRarEncrypted =>
      'O arquivo RAR está criptografado. Lançamentos RAR protegidos por senha não são suportados; escolha um lançamento empacotado sem criptografia (STORE).';

  @override
  String get err7zPassword =>
      'A senha do arquivo 7z está faltando ou é inválida. Escolha o NZB que carrega a senha em seus metadados.';

  @override
  String get errArchiveCompressed =>
      'Este arquivo está comprimido. A reprodução instantânea requer um lançamento empacotado sem compressão (COPY/STORE, 7z/RAR).';

  @override
  String get errArchiveSolid =>
      'Este arquivo é sólido. A navegação aleatória requer um lançamento empacotado como STORE não sólido.';

  @override
  String get errRar4 =>
      'Este arquivo RAR usa o formato antigo RAR4 (ou anterior). Apenas lançamentos RAR5 STORE podem ser reproduzidos.';

  @override
  String get errSplitArchiveBroken =>
      'O arquivo multiparte (7z/RAR) está incompleto ou corrompido. Escolha um NZB completo que inclua todos os volumes e segmentos.';

  @override
  String get errMissingSegments =>
      'O NZB está incompleto ou corrompido: nem todos os segmentos Usenet necessários podem ser encontrados. Escolha outro NZB completo para este lançamento.';

  @override
  String get errConnectionFailed =>
      'Não foi possível conectar ao provedor Usenet. Verifique sua conexão com a internet, o endereço do servidor, a porta e a acessibilidade do provedor.';

  @override
  String get errNzbUnreadable =>
      'O arquivo NZB não pôde ser lido ou está corrompido. Escolha um arquivo NZB válido e completo.';

  @override
  String get errArchiveNotPlayable =>
      'O arquivo (7z/RAR) dentro do NZB não é reproduzível ou sua estrutura está corrompida. Escolha um lançamento STORE completo.';

  @override
  String get errNoPlayableMedia =>
      'Nenhuma transmissão de vídeo suportada foi encontrada no NZB. Escolha um lançamento com mídia direta ou um arquivo STORE suportado.';

  @override
  String get errStreamStartupGeneric =>
      'Não foi possível iniciar a transmissão. Verifique o conteúdo do NZB e a conexão do provedor.';

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
