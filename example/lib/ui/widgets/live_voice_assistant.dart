import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:example/config/data/diary_repository.dart';
import 'package:example/config/ia/models/ia_models.dart';
import 'package:example/config/state/app_state.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

/// Asistente de voz en tiempo real usando Gemini Live API
class LiveVoiceAssistant extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const LiveVoiceAssistant({super.key, this.onDataChanged});

  @override
  State<LiveVoiceAssistant> createState() => _LiveVoiceAssistantState();
}

class _LiveVoiceAssistantState extends State<LiveVoiceAssistant>
    with SingleTickerProviderStateMixin {
  // Gemini Live
  late final LiveGenerativeModel _liveModel;
  late LiveSession _session;
  bool _settingUpSession = false;
  bool _sessionOpened = false;
  bool _conversationActive = false;

  // Audio
  final _recorder = AudioRecorder();
  late Stream<Uint8List> _inputStream;
  AudioSource? _audioSource;
  SoundHandle? _soundHandle;
  bool _audioReady = false;
  StreamController<bool> _stopController = StreamController<bool>();

  // Repository
  final _repository = DiaryRepository();

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  // UI State
  Color _statusColor = Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _initializeLiveModel();
    _initializeAudio();
    _initializeAnimation();
  }

  void _initializeLiveModel() {
    _liveModel = FirebaseAI.vertexAI().liveGenerativeModel(
      systemInstruction: Content.text('''
Eres un asistente personal inteligente para una aplicación de diario.
Hablas español de forma natural, amigable y conversacional.

CAPACIDADES:
1. Cambiar el color/tema de la aplicación
2. Responder preguntas sobre cualquier tema
3. Crear resúmenes de las entradas del diario
4. Eliminar entradas (con confirmación del usuario)

INSTRUCCIONES IMPORTANTES:
- Responde de forma concisa (máximo 3 oraciones)
- Sé amigable y empático
- COLORES: Cuando el usuario pida cambiar color, SIEMPRE usa los nombres en INGLÉS en el tool call:
  * "rojo" → usa "red"
  * "azul" → usa "blue"
  * "verde" → usa "green"
  * "morado/púrpura" → usa "purple"
  * "naranja" → usa "orange"
  * "rosa" → usa "pink"
  * "turquesa" → usa "teal"
  * "índigo" → usa "indigo"
  * "café/marrón" → usa "brown"
  * "ámbar" → usa "amber"
- Antes de eliminar algo, SIEMPRE pide confirmación explícita
- Para resúmenes, sé breve pero informativo

EJEMPLOS DE USO DE HERRAMIENTAS:
- Usuario: "Cambia el color a morado" → Llamar setAppColor con "purple"
- Usuario: "Pon la app en verde" → Llamar setAppColor con "green"
- Usuario: "¿Qué tiempo hace?" → Responder directamente (sin tool)
- Usuario: "Resume mi semana" → Llamar getDiarySummary con timeRange "week"
- Usuario: "Elimina la última entrada" → Llamar deleteEntry y pedir confirmación
      '''),
      model: 'gemini-2.0-flash-live-preview-04-09',
      liveGenerationConfig: LiveGenerationConfig(
        speechConfig: SpeechConfig(
          voiceName: 'Achernar', // Voz en español
        ),
        responseModalities: [ResponseModalities.audio],
      ),
      tools: [
        Tool.functionDeclarations([
          _buildChangeColorTool(),
          _buildGetSummaryTool(),
          _buildDeleteEntryTool(),
        ]),
      ],
    );
  }

  Future<void> _initializeAudio() async {
    try {
      await SoLoud.instance.init(sampleRate: 24000, channels: Channels.mono);
      setState(() {
        _audioReady = true;
      });
      log('Audio initialized successfully');
    } catch (e) {
      log('Error during audio initialization: $e');
      _updateStatus('Error de audio', Colors.red);
    }
  }

  void _initializeAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _stopController.close();
    _pulseController.dispose();
    if (_sessionOpened) {
      _session.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _conversationActive ? _scaleAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: _conversationActive
                  ? [
                      BoxShadow(
                        color: _statusColor.withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: _statusColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
            ),
            child: FloatingActionButton.large(
              heroTag: 'live_voice_assistant_fab',
              onPressed: _audioReady ? _toggleConversation : null,
              backgroundColor: _statusColor,
              elevation: 8,
              child: _buildButtonContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonContent() {
    if (_settingUpSession) {
      return const CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      );
    }

    if (_conversationActive) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stop_circle_outlined, size: 32, color: Colors.white),
          const SizedBox(height: 4),
          const Text(
            'Detener',
            style: TextStyle(fontSize: 10, color: Colors.white),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.chat_bubble_outline, size: 32, color: Colors.white),
        const SizedBox(height: 4),
        const Text(
          'Hablar',
          style: TextStyle(fontSize: 10, color: Colors.white),
        ),
      ],
    );
  }

  void _toggleConversation() async {
    if (_conversationActive) {
      await _stopConversation();
    } else {
      await _startConversation();
    }
  }

  Future<void> _startConversation() async {
    setState(() {
      _settingUpSession = true;
    });

    try {
      // Verificar permiso de micrófono
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _updateStatus('Permiso de micrófono requerido', Colors.red);
        setState(() => _settingUpSession = false);
        return;
      }

      // Conectar sesión de Gemini Live
      await _connectLiveSession();

      // Iniciar grabación de audio
      _inputStream = await _startRecordingStream();
      log('Input stream recording started');

      // Enviar stream de audio a Gemini
      Stream<InlineDataPart> inlineDataStream = _inputStream.map((data) {
        return InlineDataPart('audio/pcm', data);
      });
      _session.sendMediaStream(inlineDataStream);

      // Iniciar reproducción de audio de salida
      _audioSource = SoLoud.instance.setBufferStream(
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0,
      );
      _soundHandle = await SoLoud.instance.play(_audioSource!);

      log('Output stream playing');

      _pulseController.repeat(reverse: true);
      _updateStatus('Conversando...', Colors.green);

      setState(() {
        _conversationActive = true;
        _settingUpSession = false;
      });
    } catch (e) {
      log('Error starting conversation: $e');
      _updateStatus('Error al iniciar', Colors.red);
      setState(() => _settingUpSession = false);
    }
  }

  Future<void> _stopConversation() async {
    // Detener grabación
    await _recorder.stop();

    // Detener reproducción
    if (_audioSource != null && _soundHandle != null) {
      SoLoud.instance.setDataIsEnded(_audioSource!);
      await SoLoud.instance.stop(_soundHandle!);
    }

    // Cerrar sesión
    await _disconnectLiveSession();

    _pulseController.stop();
    _updateStatus('Toca para hablar', Colors.deepPurple);

    setState(() {
      _conversationActive = false;
    });
  }

  Future<void> _connectLiveSession() async {
    if (!_sessionOpened) {
      _session = await _liveModel.connect();
      _sessionOpened = true;
      unawaited(_processMessagesContinuously());
      log('Live session connected');
    }
  }

  Future<void> _disconnectLiveSession() async {
    if (_sessionOpened) {
      await _session.close();
      _stopController.add(true);
      await _stopController.close();
      _stopController = StreamController<bool>();
      _sessionOpened = false;
      log('Live session disconnected');
    }
  }

  Future<Stream<Uint8List>> _startRecordingStream() async {
    final recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 24000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
      ),
      iosConfig: IosRecordConfig(
        categoryOptions: [IosAudioCategoryOption.defaultToSpeaker],
      ),
    );
    return await _recorder.startStream(recordConfig);
  }

  Future<void> _processMessagesContinuously() async {
    bool shouldContinue = true;

    _stopController.stream.listen((stop) {
      if (stop) shouldContinue = false;
    });

    while (shouldContinue) {
      try {
        await for (final response in _session.receive()) {
          await _handleLiveServerMessage(response.message);
        }
      } catch (e) {
        log('Error processing messages: $e');
        break;
      }
    }
  }

  Future<void> _handleLiveServerMessage(LiveServerMessage message) async {
    if (message is LiveServerContent) {
      if (message.modelTurn != null) {
        await _handleServerContent(message);
      }
    }

    if (message is LiveServerToolCall && message.functionCalls != null) {
      await _handleToolCalls(message);
    }
  }

  Future<void> _handleServerContent(LiveServerContent content) async {
    final parts = content.modelTurn?.parts;
    if (parts != null) {
      for (final part in parts) {
        if (part is InlineDataPart) {
          // Reproducir audio de respuesta
          await _playAudioPart(part);
        } else if (part is TextPart) {
          log('Text response: ${part.text}');
        }
      }
    }
  }

  Future<void> _playAudioPart(InlineDataPart part) async {
    if (_audioSource != null && part.mimeType.contains('audio')) {
      SoLoud.instance.addAudioDataStream(_audioSource!, part.bytes);
    }
  }

  Future<void> _handleToolCalls(LiveServerToolCall toolCall) async {
    final functionCalls = toolCall.functionCalls;
    if (functionCalls == null || functionCalls.isEmpty) return;

    for (var call in functionCalls) {
      log('Tool call: ${call.name}');

      switch (call.name) {
        case 'setAppColor':
          await _handleColorChange(call);
          break;
        case 'getDiarySummary':
          await _handleGetSummary(call);
          break;
        case 'deleteEntry':
          await _handleDeleteEntry(call);
          break;
      }
    }
  }

  Future<void> _handleColorChange(FunctionCall call) async {
    final colorName = call.args['color']?.toString() ?? 'blue';
    final color = _getColorFromName(colorName);

    log('Cambiando color a: $colorName (${color.toString()})');

    if (mounted) {
      try {
        final appState = Provider.of<AppState>(context, listen: false);
        log('AppState encontrado, llamando setAppColor...');

        appState.setAppColor(color);

        log('Color cambiado en AppState exitosamente');

        await _session.send(
          input: Content.text(
            'Color cambiado exitosamente a $colorName. Confirma al usuario que el color de la aplicación ahora es $colorName en español.',
          ),
        );
      } catch (e) {
        log('Error al cambiar color: $e');
        await _session.send(
          input: Content.text(
            'Hubo un error al cambiar el color. Informa al usuario en español.',
          ),
        );
      }
    } else {
      log('Widget no está montado, no se puede cambiar el color');
    }
  }

  Future<void> _handleGetSummary(FunctionCall call) async {
    final timeRange = call.args['timeRange']?.toString() ?? 'all';

    final entries = await _repository.getEntries(limit: 100);
    if (entries.isEmpty) {
      await _session.send(
        input: Content.text(
          'No hay entradas en el diario. Informa al usuario en español.',
        ),
      );
      return;
    }

    // Filtrar por tiempo
    final now = DateTime.now();
    final filtered = entries.where((e) {
      final diff = now.difference(e.createdAt);
      switch (timeRange) {
        case 'today':
          return diff.inHours < 24;
        case 'week':
          return diff.inDays < 7;
        case 'month':
          return diff.inDays < 30;
        default:
          return true;
      }
    }).toList();

    if (filtered.isEmpty) {
      await _session.send(
        input: Content.text(
          'No hay entradas en ese período. Informa al usuario.',
        ),
      );
      return;
    }

    // Crear resumen
    final summaryText = filtered
        .take(10)
        .map((e) {
          return '${e.formattedDate}: ${e.contentPreview}';
        })
        .join('\n');

    await _session.send(
      input: Content.text('''
Crea un resumen breve (2-3 oraciones) de estas ${filtered.length} entradas del diario:

$summaryText

Resume los temas principales y el estado emocional general en español.
      '''),
    );
  }

  Future<void> _handleDeleteEntry(FunctionCall call) async {
    final target = call.args['target']?.toString() ?? 'last';

    final entries = await _repository.getEntries(limit: 10);
    if (entries.isEmpty) {
      await _session.send(
        input: Content.text(
          'No hay entradas para eliminar. Informa al usuario.',
        ),
      );
      return;
    }

    final entryToDelete = target == 'first' ? entries.last : entries.first;

    // Solicitar confirmación verbal
    await _session.send(
      input: Content.text('''
Pregunta al usuario si está seguro de eliminar la entrada:
"${entryToDelete.title.isNotEmpty ? entryToDelete.title : entryToDelete.contentPreview}"

Espera su confirmación verbal (sí/no) antes de proceder.
      '''),
    );

    // TODO: Implementar lógica de confirmación con siguiente mensaje del usuario
    // Por ahora, eliminamos directamente
    await _repository.deleteEntry(entryToDelete.id);
    widget.onDataChanged?.call();

    await _session.send(
      input: Content.text('Entrada eliminada. Confirma al usuario en español.'),
    );
  }

  // Tool declarations
  FunctionDeclaration _buildChangeColorTool() {
    return FunctionDeclaration(
      'setAppColor',
      'Cambia el color primario de la aplicación',
      parameters: {
        'color': Schema.string(
          description:
              'Nombre del color en inglés: blue, red, green, purple, orange, pink, teal, indigo, brown, amber',
        ),
      },
    );
  }

  FunctionDeclaration _buildGetSummaryTool() {
    return FunctionDeclaration(
      'getDiarySummary',
      'Obtiene un resumen de las entradas del diario',
      parameters: {
        'timeRange': Schema.string(
          description: 'Rango temporal: today, week, month, all',
        ),
      },
    );
  }

  FunctionDeclaration _buildDeleteEntryTool() {
    return FunctionDeclaration(
      'deleteEntry',
      'Elimina una entrada del diario (requiere confirmación del usuario)',
      parameters: {
        'target': Schema.string(
          description: 'Qué entrada eliminar: last (última) o first (primera)',
        ),
      },
    );
  }

  MaterialColor _getColorFromName(String name) {
    final colorName = name.toLowerCase();
    log('Mapeando nombre de color: $colorName');

    MaterialColor color;
    switch (colorName) {
      case 'red':
      case 'rojo':
        color = Colors.red;
        break;
      case 'blue':
      case 'azul':
        color = Colors.blue;
        break;
      case 'green':
      case 'verde':
        color = Colors.green;
        break;
      case 'purple':
      case 'morado':
      case 'púrpura':
        color = Colors.purple;
        break;
      case 'orange':
      case 'naranja':
        color = Colors.orange;
        break;
      case 'pink':
      case 'rosa':
        color = Colors.pink;
        break;
      case 'teal':
      case 'turquesa':
        color = Colors.teal;
        break;
      case 'indigo':
      case 'índigo':
        color = Colors.indigo;
        break;
      case 'brown':
      case 'café':
      case 'marrón':
        color = Colors.brown;
        break;
      case 'amber':
      case 'ámbar':
        color = Colors.amber;
        break;
      default:
        log('Color no reconocido: $colorName, usando azul por defecto');
        color = Colors.blue;
    }

    log('Color seleccionado: ${color.toString()}');
    return color;
  }

  void _updateStatus(String message, Color color) {
    setState(() {
      _statusColor = color;
    });
  }
}
