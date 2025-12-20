import 'dart:developer';
import 'package:example/config/data/diary_repository.dart';
import 'package:example/config/ia/models/ia_models.dart';
import 'package:example/config/state/app_state.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

/// Agente para Gemini Live API - Asistente de voz en tiempo real
class LiveAssistantAgent {
  final AppState appState;
  final VoidCallback? onDataChanged;
  final DiaryRepository _repository = DiaryRepository();

  LiveAssistantAgent({required this.appState, this.onDataChanged});

  /// Crea y configura el modelo de Gemini Live
  LiveGenerativeModel createLiveModel() {
    return FirebaseAI.vertexAI().liveGenerativeModel(
      systemInstruction: Content.text(_getSystemInstruction()),
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

  /// Instrucciones del sistema para el asistente
  String _getSystemInstruction() {
    return '''
Eres un asistente personal inteligente para una aplicación de diario.
Hablas español de forma natural, amigable y conversacional.

CAPACIDADES:
1. Cambiar el color/tema de la aplicación (usa setAppColor)
   - Acepta cualquier descripción de color del usuario
   - Ejemplos: "azul", "color alegre", "algo profesional", "tono oscuro", "como el atardecer"
   
2. Responder preguntas sobre cualquier tema (responde directamente)
3. Crear resúmenes de las entradas del diario (usa getDiarySummary)
4. Eliminar entradas (usa deleteEntry con confirmación del usuario)

INSTRUCCIONES IMPORTANTES:
- Responde de forma concisa (máximo 3 oraciones)
- Sé amigable y empático
- Para colores, acepta CUALQUIER descripción: colores específicos, emociones, tonos, estilos
- Interpreta creativamente las descripciones de color del usuario
- Antes de eliminar algo, SIEMPRE pide confirmación explícita
- Para resúmenes, sé breve pero informativo

EJEMPLOS DE USO DE HERRAMIENTAS:
- Usuario: "Cambia el color a morado" → Llamar setAppColor con "morado"
- Usuario: "Pon un color alegre" → Llamar setAppColor con "alegre"
- Usuario: "Quiero algo profesional" → Llamar setAppColor con "profesional"
- Usuario: "Como el océano" → Llamar setAppColor con "como el océano"
- Usuario: "¿Qué tiempo hace?" → Responder directamente (sin tool)
- Usuario: "Resume mi semana" → Llamar getDiarySummary con timeRange "week"
- Usuario: "Elimina la última entrada" → Llamar deleteEntry y pedir confirmación
      ''';
  }

  /// Maneja las llamadas a herramientas (tool calls) desde Gemini
  Future<void> handleToolCalls(
    LiveServerToolCall toolCall,
    LiveSession session,
  ) async {
    final functionCalls = toolCall.functionCalls;
    if (functionCalls == null || functionCalls.isEmpty) return;

    for (var call in functionCalls) {
      log('Tool call: ${call.name}');

      switch (call.name) {
        case 'setAppColor':
          await _handleColorChange(call, session);
          break;
        case 'getDiarySummary':
          await _handleGetSummary(call, session);
          break;
        case 'deleteEntry':
          await _handleDeleteEntry(call, session);
          break;
      }
    }
  }

  // ========== MANEJO DE HERRAMIENTAS ==========

  Future<void> _handleColorChange(
    FunctionCall call,
    LiveSession session,
  ) async {
    final colorDescription =
        call.args['colorDescription']?.toString() ?? 'azul';

    log('Interpretando descripción de color: $colorDescription');

    try {
      // Pedir a la IA que interprete la descripción y elija el mejor color
      final color = await _interpretColorDescription(colorDescription);
      final colorName = _getColorNameFromMaterial(color);

      log('Color seleccionado: $colorName (${color.toString()})');

      appState.setAppColor(color);
      log('Color cambiado en AppState exitosamente');

      await session.send(
        input: Content.text(
          'Perfecto, he cambiado el color a $colorName basándome en "$colorDescription". Confirma al usuario de forma natural en español.',
        ),
      );
    } catch (e) {
      log('Error al cambiar color: $e');
      await session.send(
        input: Content.text(
          'Hubo un error al cambiar el color. Informa al usuario en español.',
        ),
      );
    }
  }

  Future<void> _handleGetSummary(FunctionCall call, LiveSession session) async {
    final timeRange = call.args['timeRange']?.toString() ?? 'all';

    final entries = await _repository.getEntries(limit: 100);
    if (entries.isEmpty) {
      await session.send(
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
      await session.send(
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

    await session.send(
      input: Content.text('''
Crea un resumen breve (2-3 oraciones) de estas ${filtered.length} entradas del diario:

$summaryText

Resume los temas principales y el estado emocional general en español.
      '''),
    );
  }

  Future<void> _handleDeleteEntry(
    FunctionCall call,
    LiveSession session,
  ) async {
    final target = call.args['target']?.toString() ?? 'last';

    final entries = await _repository.getEntries(limit: 10);
    if (entries.isEmpty) {
      await session.send(
        input: Content.text(
          'No hay entradas para eliminar. Informa al usuario.',
        ),
      );
      return;
    }

    final entryToDelete = target == 'first' ? entries.last : entries.first;

    // Solicitar confirmación verbal
    await session.send(
      input: Content.text('''
Pregunta al usuario si está seguro de eliminar la entrada:
"${entryToDelete.title.isNotEmpty ? entryToDelete.title : entryToDelete.contentPreview}"

Espera su confirmación verbal (sí/no) antes de proceder.
      '''),
    );

    // TODO: Implementar lógica de confirmación con siguiente mensaje del usuario
    // Por ahora, eliminamos directamente
    await _repository.deleteEntry(entryToDelete.id);
    onDataChanged?.call();

    await session.send(
      input: Content.text('Entrada eliminada. Confirma al usuario en español.'),
    );
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
    log('Mapeando nombre de color: $colorName');

    MaterialColor color;
    switch (colorName) {
      case 'red':
      case 'rojo':
        color = Colors.red;
        break;
      case 'pink':
      case 'rosa':
        color = Colors.pink;
        break;
      case 'purple':
      case 'morado':
      case 'púrpura':
        color = Colors.purple;
        break;
      case 'deeppurple':
      case 'purpleprofundo':
        color = Colors.deepPurple;
        break;
      case 'indigo':
      case 'índigo':
        color = Colors.indigo;
        break;
      case 'blue':
      case 'azul':
        color = Colors.blue;
        break;
      case 'lightblue':
      case 'azulclaro':
        color = Colors.lightBlue;
        break;
      case 'cyan':
      case 'cian':
        color = Colors.cyan;
        break;
      case 'teal':
      case 'turquesa':
      case 'verdeazulado':
        color = Colors.teal;
        break;
      case 'green':
      case 'verde':
        color = Colors.green;
        break;
      case 'lightgreen':
      case 'verdeclaro':
        color = Colors.lightGreen;
        break;
      case 'lime':
      case 'lima':
        color = Colors.lime;
        break;
      case 'yellow':
      case 'amarillo':
        color = Colors.yellow;
        break;
      case 'amber':
      case 'ámbar':
      case 'ambar':
        color = Colors.amber;
        break;
      case 'orange':
      case 'naranja':
        color = Colors.orange;
        break;
      case 'deeporange':
      case 'naranjaprofundo':
        color = Colors.deepOrange;
        break;
      case 'brown':
      case 'café':
      case 'marrón':
      case 'marron':
        color = Colors.brown;
        break;
      case 'grey':
      case 'gray':
      case 'gris':
        color = Colors.grey;
        break;
      case 'bluegrey':
      case 'blueGrey':
      case 'grisazulado':
        color = Colors.blueGrey;
        break;
      default:
        log('Color no reconocido: $colorName, usando azul por defecto');
        color = Colors.blue;
    }

    log('Color seleccionado: ${color.toString()}');
    return color;
  }
}
