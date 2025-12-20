import 'package:flutter/material.dart';

/// Clase de ayuda para manejar traducciones sin usar AppLocalizations generado
class L10n {
  final Locale locale;

  L10n(this.locale);

  static L10n of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return L10n(locale);
  }

  bool get isEs => locale.languageCode == 'es';
  bool get isEn => locale.languageCode == 'en';

  // App
  String get appTitle => isEs ? 'Diario de Voz' : 'Voice Diary';
  String get myDiary => isEs ? 'Mi Diario' : 'My Diary';

  // Navigation
  String get voiceCommands => isEs ? 'Comandos de voz' : 'Voice Commands';
  String get statistics => isEs ? 'Estadísticas' : 'Statistics';
  String get search => isEs ? 'Buscar' : 'Search';
  String get settings => isEs ? 'Configuración' : 'Settings';

  // Empty state
  String get startYourJourney =>
      isEs ? 'Comienza tu viaje' : 'Start Your Journey';
  String get captureYourThoughts => isEs
      ? 'Captura tus pensamientos, momentos\ny emociones con IA'
      : 'Capture your thoughts, moments\nand emotions with AI';
  String get firstEntry => isEs ? 'Primera Entrada' : 'First Entry';

  // Actions
  String get newEntry => isEs ? 'Nueva Entrada' : 'New Entry';
  String get save => isEs ? 'Guardar' : 'Save';
  String get cancel => isEs ? 'Cancelar' : 'Cancel';
  String get delete => isEs ? 'Eliminar' : 'Delete';
  String get edit => isEs ? 'Editar' : 'Edit';
  String get close => isEs ? 'Cerrar' : 'Close';

  // Entry form
  String get title => isEs ? 'Título' : 'Title';
  String get titleHint =>
      isEs ? 'Título de la entrada (opcional)' : 'Entry title (optional)';
  String get content => isEs ? 'Contenido' : 'Content';
  String get contentHint => isEs
      ? 'Escribe sobre tu día, tus pensamientos, tus sentimientos...'
      : 'Write about your day, your thoughts, your feelings...';
  String get contentCannotBeEmpty =>
      isEs ? 'El contenido no puede estar vacío' : 'Content cannot be empty';

  // Images
  String get addImage => isEs ? 'Agregar Imagen' : 'Add Image';
  String get takePhoto => isEs ? 'Tomar Foto' : 'Take Photo';
  String get chooseFromGallery =>
      isEs ? 'Elegir de Galería' : 'Choose from Gallery';
  String get generatingImage =>
      isEs ? 'Generando imagen con IA...' : 'Generating image with AI...';
  String get image => isEs ? 'Imagen' : 'Image';
  String get downloadImage => isEs ? 'Descargar' : 'Download';

  // Status messages
  String get analyzing => isEs ? 'Analizando...' : 'Analyzing...';
  String get savingEntry => isEs ? 'Guardando entrada...' : 'Saving entry...';
  String get entrySaved =>
      isEs ? 'Entrada guardada exitosamente' : 'Entry saved successfully';
  String get entryDeleted => isEs ? 'Entrada eliminada' : 'Entry deleted';
  String get errorSaving =>
      isEs ? 'Error al guardar entrada' : 'Error saving entry';
  String get errorDeleting => isEs ? 'Error al eliminar' : 'Error deleting';
  String get loadingEntries =>
      isEs ? 'Cargando entradas...' : 'Loading entries...';
  String get errorLoadingEntries =>
      isEs ? 'Error al cargar entradas' : 'Error loading entries';
  String get noEntries => isEs ? 'Aún no hay entradas' : 'No entries yet';

  // Dialogs
  String get confirmDelete => isEs ? 'Confirmar Eliminación' : 'Confirm Delete';
  String get confirmDeleteMessage => isEs
      ? '¿Estás seguro de que quieres eliminar esta entrada?'
      : 'Are you sure you want to delete this entry?';
  String get yes => isEs ? 'Sí' : 'Yes';
  String get no => isEs ? 'No' : 'No';

  // Time
  String get today => isEs ? 'Hoy' : 'Today';
  String get yesterday => isEs ? 'Ayer' : 'Yesterday';

  // Sentiments
  String get veryHappy => isEs ? 'Muy Feliz' : 'Very Happy';
  String get happy => isEs ? 'Feliz' : 'Happy';
  String get neutral => isEs ? 'Neutral' : 'Neutral';
  String get sad => isEs ? 'Triste' : 'Sad';
  String get verySad => isEs ? 'Muy Triste' : 'Very Sad';
  String get mixed => isEs ? 'Mixto' : 'Mixed';

  // User Profile
  String get userProfile => isEs ? 'Perfil de Usuario' : 'User Profile';
  String get name => isEs ? 'Nombre' : 'Name';
  String get nameHint => isEs ? 'Ingresa tu nombre' : 'Enter your name';
  String get gender => isEs ? 'Género' : 'Gender';
  String get genderHelp => isEs
      ? 'Esto ayuda a personalizar las imágenes generadas por IA'
      : 'This helps personalize AI-generated images';
  String get male => isEs ? 'Masculino' : 'Male';
  String get female => isEs ? 'Femenino' : 'Female';
  String get nonBinary => isEs ? 'No binario' : 'Non-binary';
  String get preferNotToSay => isEs ? 'Prefiero no decir' : 'Prefer not to say';
  String get age => isEs ? 'Edad' : 'Age';
  String get ageHint => isEs ? 'Ingresa tu edad' : 'Enter your age';
  String get saveProfile => isEs ? 'Guardar Perfil' : 'Save Profile';
  String get profileSaved =>
      isEs ? 'Perfil guardado exitosamente' : 'Profile saved successfully';
  String get optional => isEs ? 'opcional' : 'optional';

  // Voice Assistant
  String get voiceAssistantHelp =>
      isEs ? 'Ayuda del Asistente de Voz' : 'Voice Assistant Help';
  String get voiceAssistantDescription => isEs
      ? 'Puedes usar tu voz para interactuar con el diario. Estas son algunas cosas que puedes hacer:'
      : 'You can use your voice to interact with the diary. Here are some things you can do:';
  String get changeColor => isEs ? 'Cambiar Color' : 'Change Color';
  String get changeColorExample => isEs
      ? '"Cambia el color de la app a azul"'
      : '"Change the app color to blue"';
  String get askQuestions => isEs ? 'Hacer Preguntas' : 'Ask Questions';
  String get askQuestionsExample =>
      isEs ? '"¿Qué tiempo hace?"' : '"What\'s the weather like?"';
  String get getDiarySummary =>
      isEs ? 'Obtener Resumen del Diario' : 'Get Diary Summary';
  String get getDiarySummaryExample =>
      isEs ? '"Resume mi semana"' : '"Summarize my week"';
  String get deleteEntry => isEs ? 'Eliminar Entrada' : 'Delete Entry';
  String get deleteEntryExample =>
      isEs ? '"Elimina mi última entrada"' : '"Delete my last entry"';

  // Voice recording
  String get recording => isEs ? 'Grabando...' : 'Recording...';
  String get processing => isEs ? 'Procesando...' : 'Processing...';
  String get tapToSpeak => isEs ? 'Toca para hablar' : 'Tap to speak';
  String get listeningLive =>
      isEs ? 'Escuchando (modo en vivo)...' : 'Listening (Live mode)...';

  // Image errors
  String get errorSelectingImage =>
      isEs ? 'Error al seleccionar imagen' : 'Error selecting image';
  String get errorTakingPhoto =>
      isEs ? 'Error al tomar foto' : 'Error taking photo';
  String get imageDownloaded =>
      isEs ? 'Imagen guardada en la galería' : 'Image saved to gallery';
  String get errorDownloadingImage =>
      isEs ? 'Error al descargar imagen' : 'Error downloading image';

  // Permissions
  String get permissionDenied =>
      isEs ? 'Permiso Denegado' : 'Permission Denied';
  String get needsStoragePermission => isEs
      ? 'Esta aplicación necesita permiso de almacenamiento para guardar imágenes.'
      : 'This app needs storage permission to save images.';
  String get openSettings => isEs ? 'Abrir Configuración' : 'Open Settings';

  // Months
  List<String> get months => isEs
      ? [
          'Ene',
          'Feb',
          'Mar',
          'Abr',
          'May',
          'Jun',
          'Jul',
          'Ago',
          'Sep',
          'Oct',
          'Nov',
          'Dic',
        ]
      : [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];

  String getMonth(int month) {
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }
}
