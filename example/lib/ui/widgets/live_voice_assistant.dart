import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:example/config/ia/app_agents/live_assistant_agent.dart';
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
  late LiveAssistantAgent _agent;
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

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  // UI State
  Color _statusColor = Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _initializeAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializar el agente con el AppState del contexto
    final appState = Provider.of<AppState>(context, listen: false);
    _agent = LiveAssistantAgent(
      appState: appState,
      onDataChanged: widget.onDataChanged,
    );
    _liveModel = _agent.createLiveModel();
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
      await _agent.handleToolCalls(message, _session);
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

  void _updateStatus(String message, Color color) {
    setState(() {
      _statusColor = color;
    });
  }
}
