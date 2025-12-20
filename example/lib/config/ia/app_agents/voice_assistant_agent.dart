import 'dart:developer';
import 'package:example/config/data/diary_repository.dart';
import 'package:example/config/ia/models/ia_models.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

/// Agente de asistente de voz para comandos interactivos usando Function Declarations
class VoiceAssistantAgent {
  static final VoiceAssistantAgent _instance = VoiceAssistantAgent._internal();
  factory VoiceAssistantAgent() => _instance;
  VoiceAssistantAgent._internal();

  final _repository = DiaryRepository();

  /// Crea el modelo de Gemini con Function Declarations
  GenerativeModel _createModelWithTools() {
    return FirebaseAI.vertexAI().generativeModel(
      model: IAModels.chatModelGemini,
      tools: [
        Tool.functionDeclarations([
          _buildChangeColorTool(),
          _buildGetSummaryTool(),
          _buildDeleteEntryTool(),
        ]),
      ],
      systemInstruction: Content.text(_getSystemInstruction()),
    );
  }

  String _getSystemInstruction() {
    return '''
Eres un asistente personal inteligente para una aplicación de diario.
Hablas español de forma natural, amigable y conversacional.

CAPACIDADES:
1. Cambiar el color/tema de la aplicación (usa setAppColor)
   - Acepta cualquier descripción de color del usuario
   - Ejemplos: "azul", "color alegre", "algo profesional", "tono oscuro", "como el atardecer"
   
2. Responder preguntas sobre cualquier tema (responde directamente)
   - Proporciona información útil y concisa
   
3. Crear resúmenes de las entradas del diario (usa getDiarySummary)
   - Resúmenes del día, semana, mes o todas las entradas
   
4. Eliminar entradas (usa deleteEntry con confirmación)
   - Siempre pide confirmación antes de eliminar

INSTRUCCIONES:
- Responde de forma concisa y amigable (máximo 3 oraciones)
- Para colores, acepta CUALQUIER descripción: colores específicos, emociones, tonos, estilos
- Interpreta creativamente las descripciones de color del usuario
- Antes de eliminar, SIEMPRE pide confirmación explícita
- Para resúmenes, sé breve pero informativo

EJEMPLOS DE CAMBIO DE COLOR:
- "cambia a azul" → usa setAppColor con "azul"
- "quiero un color alegre" → usa setAppColor con "alegre"
- "algo profesional y serio" → usa setAppColor con "profesional y serio"
- "como el mar" → usa setAppColor con "como el mar"
- "tono oscuro" → usa setAppColor con "tono oscuro"
''';
  }

  /// Procesa un comando de voz usando Function Declarations
  Future<VoiceCommandResult> processCommand(String transcription) async {
    try {
      final model = _createModelWithTools();

      // Enviar el comando al modelo
      final chat = model.startChat();
      final response = await chat.sendMessage(Content.text(transcription));

      // Verificar si hay function calls
      final functionCalls = response.functionCalls;
      if (functionCalls.isNotEmpty) {
        return await _handleFunctionCalls(functionCalls, chat);
      }

      // Si no hay function calls, es una respuesta directa
      final text = response.text?.trim() ?? 'No pude procesar el comando';
      return VoiceCommandResult(
        type: VoiceCommandType.answerQuestion,
        message: text,
        success: true,
      );
    } catch (e) {
      log('Error en processCommand: $e');
      return VoiceCommandResult(
        type: VoiceCommandType.unknown,
        message: 'Error al procesar comando: $e',
        success: false,
      );
    }
  }

  /// Maneja las llamadas a funciones desde Gemini
  Future<VoiceCommandResult> _handleFunctionCalls(
    Iterable<FunctionCall> functionCalls,
    ChatSession chat,
  ) async {
    for (var call in functionCalls) {
      log('Function call: ${call.name}');

      switch (call.name) {
        case 'setAppColor':
          return await _handleColorChange(call, chat);
        case 'getDiarySummary':
          return await _handleGetSummary(call, chat);
        case 'deleteEntry':
          return await _handleDeleteEntry(call, chat);
      }
    }

    return VoiceCommandResult(
      type: VoiceCommandType.unknown,
      message: 'Función no reconocida',
      success: false,
    );
  }

  // ========== MANEJO DE HERRAMIENTAS ==========

  /// Maneja el cambio de color de la aplicación
  Future<VoiceCommandResult> _handleColorChange(
    FunctionCall call,
    ChatSession chat,
  ) async {
    try {
      final colorDescription =
          call.args['colorDescription']?.toString() ?? 'azul';

      log('Interpretando descripción de color: $colorDescription');

      // Pedir a la IA que interprete la descripción y elija el mejor color
      final color = await _interpretColorDescription(colorDescription);
      final colorName = _getColorNameFromMaterial(color);

      log('Color seleccionado: $colorName');

      // Enviar respuesta al modelo para que confirme al usuario
      await chat.sendMessage(
        Content.text(
          'Perfecto, he cambiado el color a $colorName basándome en "$colorDescription". Confirma esto al usuario de forma natural.',
        ),
      );

      return VoiceCommandResult(
        type: VoiceCommandType.changeColor,
        message: 'Color cambiado a ${_getColorSpanishName(colorName)}',
        success: true,
        data: {'color': color, 'colorName': colorName},
      );
    } catch (e) {
      log('Error en _handleColorChange: $e');
      return VoiceCommandResult(
        type: VoiceCommandType.changeColor,
        message: 'No pude cambiar el color',
        success: false,
      );
    }
  }

  /// Maneja la generación de resúmenes
  Future<VoiceCommandResult> _handleGetSummary(
    FunctionCall call,
    ChatSession chat,
  ) async {
    try {
      final timeRange = call.args['timeRange']?.toString() ?? 'all';

      final entries = await _repository.getEntries(limit: 100);
      if (entries.isEmpty) {
        await chat.sendMessage(Content.text('No hay entradas en el diario'));
        return VoiceCommandResult(
          type: VoiceCommandType.summarize,
          message: 'No tienes entradas para resumir',
          success: false,
        );
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
        await chat.sendMessage(Content.text('No hay entradas en ese período'));
        return VoiceCommandResult(
          type: VoiceCommandType.summarize,
          message: 'No tienes entradas en ese período',
          success: false,
        );
      }

      // Crear resumen para que el modelo lo procese
      final summaryText = filtered
          .take(10)
          .map((e) {
            return '${e.formattedDate}: ${e.contentPreview}';
          })
          .join('\n');

      final response = await chat.sendMessage(
        Content.text('''
Encontré ${filtered.length} entradas. Aquí está un resumen:

$summaryText

Resume esto de forma natural y amigable en 2-3 oraciones.
'''),
      );

      final summary = response.text?.trim() ?? 'No pude crear el resumen';

      return VoiceCommandResult(
        type: VoiceCommandType.summarize,
        message: summary,
        success: true,
        data: {'entries': filtered},
      );
    } catch (e) {
      log('Error en _handleGetSummary: $e');
      return VoiceCommandResult(
        type: VoiceCommandType.summarize,
        message: 'No pude crear el resumen',
        success: false,
      );
    }
  }

  /// Maneja la eliminación de entradas
  Future<VoiceCommandResult> _handleDeleteEntry(
    FunctionCall call,
    ChatSession chat,
  ) async {
    try {
      final target = call.args['target']?.toString() ?? 'last';

      final entries = await _repository.getEntries(limit: 10);
      if (entries.isEmpty) {
        await chat.sendMessage(Content.text('No hay entradas para eliminar'));
        return VoiceCommandResult(
          type: VoiceCommandType.deleteEntry,
          message: 'No hay entradas para eliminar',
          success: false,
        );
      }

      final entryToDelete = target == 'first' ? entries.last : entries.first;

      return VoiceCommandResult(
        type: VoiceCommandType.deleteEntry,
        message:
            '¿Estás seguro de eliminar "${entryToDelete.title.isNotEmpty ? entryToDelete.title : entryToDelete.contentPreview}"?',
        success: true,
        data: {'entry': entryToDelete},
        requiresConfirmation: true,
      );
    } catch (e) {
      log('Error en _handleDeleteEntry: $e');
      return VoiceCommandResult(
        type: VoiceCommandType.deleteEntry,
        message: 'No pude procesar la eliminación',
        success: false,
      );
    }
  }

  // ========== DECLARACIONES DE HERRAMIENTAS ==========

  FunctionDeclaration _buildChangeColorTool() {
    return FunctionDeclaration(
      'setAppColor',
      'Cambia el color primario de la aplicación basándose en la descripción del usuario',
      parameters: {
        'colorDescription': Schema.string(
          description:
              'Descripción del color que el usuario quiere. Puede ser un color específico (azul, rojo), un tono (oscuro, claro, pastel), una emoción (alegre, serio, relajante), o cualquier descripción creativa. Interpreta la descripción y elige el color de Material Design que mejor coincida.',
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

  // ========== UTILIDADES ==========

  /// Interpreta una descripción de color y retorna el MaterialColor más apropiado
  Future<MaterialColor> _interpretColorDescription(String description) async {
    try {
      // Crear un modelo temporal para interpretación de color
      final model = FirebaseAI.vertexAI().generativeModel(
        model: IAModels.chatModelGemini,
      );

      final prompt =
          '''
Interpreta esta descripción de color y elige EL MEJOR MaterialColor de Flutter que coincida.

Descripción del usuario: "$description"

COLORES DISPONIBLES DE MATERIAL DESIGN:
- red: Rojo vibrante, energético, apasionado
- pink: Rosa, dulce, romántico, suave
- purple: Morado/púrpura, creativo, místico, elegante
- deepPurple: Púrpura profundo, sofisticado, nocturno
- indigo: Índigo, profesional, tecnológico, moderno
- blue: Azul, confiable, calmante, clásico
- lightBlue: Azul claro, fresco, aireado, suave
- cyan: Cian, digital, fresco, vibrante
- teal: Verde azulado/turquesa, equilibrado, natural
- green: Verde, naturaleza, crecimiento, armonía
- lightGreen: Verde claro, primaveral, fresco
- lime: Lima, brillante, juvenil, energético
- yellow: Amarillo, alegre, soleado, optimista
- amber: Ámbar, cálido, acogedor, dorado
- orange: Naranja, enérgico, entusiasta, cálido
- deepOrange: Naranja profundo, intenso, atardecer
- brown: Café/marrón, terroso, cálido, natural
- grey: Gris, neutral, profesional, minimalista
- blueGrey: Gris azulado, moderno, sofisticado, corporativo

INSTRUCCIONES:
- Considera el significado emocional y visual de la descripción
- Si mencionan un color específico, úsalo
- Si describen una emoción, elige el color que mejor la represente
- Si piden algo "oscuro" o "claro", considera las variantes (deep, light)
- Si piden algo "profesional" o "serio", considera blue, blueGrey, indigo
- Si piden algo "alegre" o "divertido", considera yellow, orange, lime
- Si piden algo "relajante" o "calmante", considera blue, teal, green
- Si piden algo "energético" o "vibrante", considera red, orange, pink

Responde SOLO con el nombre exacto del color en inglés (sin explicación).
Ejemplo: "blue" o "deepPurple" o "lightGreen"
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final colorName = response.text?.trim().toLowerCase() ?? 'blue';

      log('IA interpretó "$description" como: $colorName');

      return _getColorFromName(colorName);
    } catch (e) {
      log('Error interpretando color: $e');
      return Colors.blue; // Color por defecto
    }
  }

  /// Obtiene el nombre en inglés de un MaterialColor
  String _getColorNameFromMaterial(MaterialColor color) {
    if (color == Colors.red) return 'red';
    if (color == Colors.pink) return 'pink';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.deepPurple) return 'deepPurple';
    if (color == Colors.indigo) return 'indigo';
    if (color == Colors.blue) return 'blue';
    if (color == Colors.lightBlue) return 'lightBlue';
    if (color == Colors.cyan) return 'cyan';
    if (color == Colors.teal) return 'teal';
    if (color == Colors.green) return 'green';
    if (color == Colors.lightGreen) return 'lightGreen';
    if (color == Colors.lime) return 'lime';
    if (color == Colors.yellow) return 'yellow';
    if (color == Colors.amber) return 'amber';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.deepOrange) return 'deepOrange';
    if (color == Colors.brown) return 'brown';
    if (color == Colors.grey) return 'grey';
    if (color == Colors.blueGrey) return 'blueGrey';
    return 'blue';
  }

  MaterialColor _getColorFromName(String name) {
    final colorName = name.toLowerCase().replaceAll(' ', '');
    switch (colorName) {
      case 'red':
      case 'rojo':
        return Colors.red;
      case 'pink':
      case 'rosa':
        return Colors.pink;
      case 'purple':
      case 'morado':
      case 'púrpura':
        return Colors.purple;
      case 'deeppurple':
      case 'purpleprofundo':
        return Colors.deepPurple;
      case 'indigo':
      case 'índigo':
        return Colors.indigo;
      case 'blue':
      case 'azul':
        return Colors.blue;
      case 'lightblue':
      case 'azulclaro':
        return Colors.lightBlue;
      case 'cyan':
      case 'cian':
        return Colors.cyan;
      case 'teal':
      case 'turquesa':
      case 'verdeazulado':
        return Colors.teal;
      case 'green':
      case 'verde':
        return Colors.green;
      case 'lightgreen':
      case 'verdeclaro':
        return Colors.lightGreen;
      case 'lime':
      case 'lima':
        return Colors.lime;
      case 'yellow':
      case 'amarillo':
        return Colors.yellow;
      case 'amber':
      case 'ámbar':
      case 'ambar':
        return Colors.amber;
      case 'orange':
      case 'naranja':
        return Colors.orange;
      case 'deeporange':
      case 'naranjaprofundo':
        return Colors.deepOrange;
      case 'brown':
      case 'café':
      case 'marrón':
      case 'marron':
        return Colors.brown;
      case 'grey':
      case 'gray':
      case 'gris':
        return Colors.grey;
      case 'bluegrey':
      case 'blueGrey':
      case 'grisazulado':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }

  String _getColorSpanishName(String name) {
    final colorName = name.toLowerCase().replaceAll(' ', '');
    switch (colorName) {
      case 'red':
        return 'rojo';
      case 'pink':
        return 'rosa';
      case 'purple':
        return 'morado';
      case 'deeppurple':
        return 'púrpura profundo';
      case 'indigo':
        return 'índigo';
      case 'blue':
        return 'azul';
      case 'lightblue':
        return 'azul claro';
      case 'cyan':
        return 'cian';
      case 'teal':
        return 'turquesa';
      case 'green':
        return 'verde';
      case 'lightgreen':
        return 'verde claro';
      case 'lime':
        return 'lima';
      case 'yellow':
        return 'amarillo';
      case 'amber':
        return 'ámbar';
      case 'orange':
        return 'naranja';
      case 'deeporange':
        return 'naranja profundo';
      case 'brown':
        return 'café';
      case 'grey':
      case 'gray':
        return 'gris';
      case 'bluegrey':
        return 'gris azulado';
      default:
        return name;
    }
  }
}

/// Tipos de comandos de voz
enum VoiceCommandType {
  changeColor,
  answerQuestion,
  summarize,
  deleteEntry,
  unknown,
}

/// Resultado de un comando de voz
class VoiceCommandResult {
  final VoiceCommandType type;
  final String message;
  final bool success;
  final Map<String, dynamic>? data;
  final bool requiresConfirmation;

  VoiceCommandResult({
    required this.type,
    required this.message,
    required this.success,
    this.data,
    this.requiresConfirmation = false,
  });
}
