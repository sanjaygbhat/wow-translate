-- WoW Translate: Spanish
local _, WT = ...
local loc = WT.Locale() if loc ~= "esES" and loc ~= "esMX" then return end
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "T"

-- Modes
L.MODE_QUICK = "Rápido"
L.MODE_QUICK_BADGE = "|cff20ff20GRATIS|r"
L.MODE_QUICK_BODY = "Funciona al instante, dentro del juego. Te da la idea general, frase por frase. No siempre es exacto."
L.MODE_ACCURATE = "Preciso"
L.MODE_ACCURATE_BADGE = "|cffffcc00SERVICIO DE PAGO|r"
L.MODE_ACCURATE_BODY = "Traducciones reales y naturales. Necesita la app gratuita Companion en tu PC y una cuenta de traducción (una cantidad gratis al mes, luego de pago)."

-- Options window
L.SECTION_MODE = "¿Cómo quieres traducir?"
L.SECTION_READING = "Leer el chat"
L.SECTION_WRITING = "Escribir en el chat"
L.SECTION_OTHER = "Otros"

L.OPT_TRANSLATE_INCOMING = "Traducir mensajes de otros jugadores"
L.OPT_TRANSLATE_INCOMING_TIP = "Los mensajes en otros idiomas se traducen en tu ventana de chat."
L.OPT_TRANSLATE_INTO = "Traducir a:"
L.OPT_TRANSLATE_INTO_TIP = "El idioma que quieres leer. Auto usa el idioma de tu juego."
L.AUTO_LANG = "Auto (%s)"
L.OPT_SHOW_ORIGINAL = "Mostrar también el texto original"
L.OPT_SHOW_ORIGINAL_TIP = "Muestra el mensaje original en gris después de la traducción."
L.OPT_LOCALIZE_LINKS = "Objetos y misiones en mi idioma"
L.OPT_LOCALIZE_LINKS_TIP = "Los enlaces de objetos, misiones y hechizos muestran su nombre en tu idioma. Esto viene directo del juego, así que siempre es exacto."
L.OPT_PAUSE_AFK = "Pausar si estoy ausente (AFK)"
L.OPT_PAUSE_AFK_TIP = "No se traduce nada mientras estés marcado como ausente."
L.OPT_MARKER = "Mostrar la etiqueta [T]"
L.OPT_MARKER_TIP = "Una pequeña [T] delante de las líneas traducidas. Pasa el cursor por encima para ver el mensaje original."

L.OPT_TRANSLATE_OUTGOING = "Traducir lo que escribo (Rápido)"
L.OPT_TRANSLATE_OUTGOING_TIP = "Tu mensaje se traduce justo antes de enviarse. Usa el modo Rápido, así que escribe frases cortas y simples. Para traducir tus propios mensajes con precisión, usa la app Companion: traduce y copia el texto para que solo tengas que pegarlo."
L.OPT_WRITE_IN = "Escribir en:"
L.OPT_WRITE_IN_TIP = "Su idioma (auto) responde a cada jugador en el último idioma en que te escribió. Si nadie te ha escrito aún en otro idioma, tu mensaje se envía tal como lo escribiste."
L.THEIR_LANGUAGE = "Su idioma (auto)"
L.OPT_OUTGOING_TAG = "Añadir \"(traducido)\" para avisar"
L.OPT_OUTGOING_TAG_TIP = "Pone una etiqueta corta, en su idioma, delante de tu mensaje traducido para que sepan que lo tradujo una máquina."

L.OPT_ROMANIZE = "Nombres extranjeros en letras latinas"
L.OPT_ROMANIZE_TIP = "Los nombres en otros alfabetos (como 小明 o Иван) muestran su lectura en letras latinas al pasar el cursor. El nombre real nunca cambia."
L.OPT_MINIMAP = "Botón del minimapa"
L.OPT_MINIMAP_TIP = "Muestra el botón de WoW Translate en el minimapa. También encontrarás WoW Translate en el menú de addons junto al minimapa."
L.OPT_REMEMBER = "Recordar mis ajustes al reiniciar"
L.OPT_REMEMBER_TIP = "Por ahora, la beta de WoW: Forever olvida los ajustes de los addons al reiniciar el juego. Esto guarda una copia en una macro llamada \"WoWTranslate\". Puedes desactivarlo cuando quieras y la macro se borra."
L.REMEMBER_NOTE = "Arreglo para la beta. Usa un espacio de macro."
L.REMEMBER_AT_RISK = "Tus cambios se perderán al reiniciar el juego (error de la beta). Marca esta casilla para conservarlos."
L.REMEMBER_ON = "Tus ajustes se recordarán (guardados en la macro \"WoWTranslate\")."
L.REMEMBER_OFF = "Los ajustes ya no se guardarán en una macro."

L.CHANNEL_WHISPER = "Susurros"
L.CHANNEL_PARTY = "Grupo"
L.CHANNEL_RAID = "Banda"
L.CHANNEL_INSTANCE = "Mazmorra y campo de batalla"
L.CHANNEL_GUILD = "Hermandad"
L.CHANNEL_SAY = "Decir"
L.CHANNEL_YELL = "Gritar"
L.CHANNEL_CHANNEL = "Comercio y Mundo"
L.CHANNEL_EMOTE = "Emociones"

L.BUTTON_TRY = "Probar"
L.BUTTON_TRY_TIP = "Muestra algunos ejemplos de traducción en tu ventana de chat."
L.BUTTON_RESET = "Restablecer"
L.BUTTON_HOW_TO_SETUP = "Cómo configurarlo"
L.BUTTON_SEND_TEST = "Enviar una prueba"
L.BUTTON_USE_ACCURATE = "Activar el modo Preciso"
L.BUTTON_OPEN_OPTIONS = "Abrir WoW Translate"
L.SETTINGS_PANEL_TEXT = "Traduce el chat desde y hacia otros idiomas. Escribe /wt cuando quieras para abrir las opciones."

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "El modo Preciso necesita la app WoW Translate Companion."
L.LINK_STATUS_ON = "Conexión con Companion activa (%s). Deja la app abierta."
L.LINK_QUEUE = "%d en espera"
L.LINK_TEST_MESSAGE = "¡Hola desde WoW Translate! Si puedes leer esto en la app Companion, el modo Preciso funciona."
L.LINK_TEST_SENT = "Prueba enviada. Debería aparecer en la app Companion en menos de un segundo."
L.LINK_CORNER_SET = "Conexión con Companion movida a la esquina %s."
L.LINK_SIZE_SET = "Los cuadrados de la conexión con Companion ahora miden %d píxeles."
L.CORNER_TOPLEFT = "superior izquierda"
L.CORNER_TOPRIGHT = "superior derecha"
L.CORNER_BOTTOMLEFT = "inferior izquierda"
L.CORNER_BOTTOMRIGHT = "inferior derecha"

L.GUIDE_TITLE = "Configurar el modo Preciso"
L.GUIDE_BODY = "Los addons no pueden usar internet, así que las traducciones precisas vienen de una pequeña app gratuita que funciona junto al juego.\n\n"
    .. "1. Descarga |cffffd100WoW Translate Companion|r (enlace abajo) y ábrela.\n"
    .. "2. En la app, elige un servicio de traducción y pega tu clave. DeepL y Google te dan una cantidad gratis cada mes y luego cobran.\n"
    .. "3. Juega en modo |cffffd100Ventana|r o |cffffd100Ventana (pantalla completa)|r.\n"
    .. "4. Activa aquí el modo Preciso. Aparecerá una línea fina de color en una esquina de tu pantalla: así se comunica el addon con la app, así que déjala visible.\n\n"
    .. "Luego las traducciones aparecen en la ventana de la app, justo al lado de tu chat."
L.GUIDE_LINK_LABEL = "Página de descarga (haz clic y usa Ctrl+C para copiar):"

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "Original (%s):"
L.TOOLTIP_QUICK_HINT = "Traducción rápida: da la idea general y puede no ser exacta."
L.TOOLTIP_ACCURATE_HINT = "La traducción precisa está en la app Companion."
L.TOOLTIP_CLICK_HINT = "Haz clic para mostrar el original en el chat."
L.ORIGINAL_LINE = "Original (%s):"

-- Minimap
L.MINIMAP_STATUS = "%s - modo %s - idioma: %s"
L.MINIMAP_LEFT_CLICK = "Clic izquierdo: opciones"
L.MINIMAP_RIGHT_CLICK = "Clic derecho: activar o desactivar la traducción"
L.STATE_ON = "Activado"
L.STATE_OFF = "Desactivado"

-- Chat messages
L.GREETING = "Modo %s activado. Los mensajes en otros idiomas se traducen a: %s. Escribe /wt para ver las opciones."
L.GREETING_OFF = "La traducción está desactivada. Escribe /wt on para volver a activarla."
L.TRANSLATION_ON = "La traducción está activada."
L.TRANSLATION_OFF = "La traducción está desactivada."
L.NOW_QUICK = "Modo Rápido: traducciones gratis dentro del juego."
L.NOW_ACCURATE = "Modo Preciso: abre la app Companion para ver traducciones precisas. Escribe /wt link para obtener ayuda."
L.NOW_TRANSLATING_INTO = "Ahora se traduce a: %s."
L.NOW_WRITING_IN = "Tus mensajes se escribirán en: %s."
L.WRITING_ON = "Tus mensajes se traducirán antes de enviarse."
L.WRITING_OFF = "Tus mensajes se enviarán tal como los escribes."
L.LANG_CODES = "Idiomas: auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "No pude saber qué idioma es."
L.NOT_TRANSLATED = "(muy pocas palabras conocidas)"
L.KNOWN_PERCENT = "%d%% de palabras conocidas"
L.DEMO_HEADER = "Ejemplos traducidos (%s):"
L.DEMO_FOOTER = "El modo Rápido da la idea general. Para frases naturales, usa el modo Preciso."
L.SETTINGS_RESET = "Los ajustes volvieron a sus valores predeterminados."
L.ERR_NO_CHAT_FILTERS = "Esta versión del juego no tiene filtros de chat, así que no se puede traducir el chat."

L.STATUS_HEADER = "Estado - versión"
L.STATUS_MODE = "Modo"
L.STATUS_READING = "Lectura"
L.STATUS_WRITING = "Escritura"
L.STATUS_LINK = "Conexión con Companion"
L.STATUS_SAVED_OK = "Los ajustes se guardan con normalidad."
L.STATUS_SAVED_MACRO = "Los ajustes se guardan en la macro \"WoWTranslate\" (arreglo para la beta)."
L.STATUS_SAVED_RISK = "Los ajustes se restablecerán al reiniciar el juego (error de la beta). Escribe /wt remember para conservarlos."
L.STATUS_LOCKDOWN = "El juego bloquea el chat en este momento (combate contra jefe o partida puntuada), así que los mensajes de otros jugadores no se pueden traducir hasta que termine."

L.PERSIST_NO_MACRO_API = "Las macros no están disponibles, así que no se pueden guardar los ajustes."
L.PERSIST_MACRO_FULL = "No se pudo crear la macro \"WoWTranslate\". ¿Están llenos todos los espacios de macros generales?"
L.PERSIST_SAVED = "Guardado."
L.PERSIST_FIXED = "Buenas noticias: ahora el juego guarda por sí mismo los ajustes de los addons, así que se borró la macro \"WoWTranslate\"."
L.PERSIST_HINT = "Consejo: la beta de WoW: Forever olvida los ajustes de los addons al reiniciar el juego. Escribe /wt remember (o marca la casilla en /wt) para conservar tus cambios."
L.PERSIST_RESTORED = "Ajustes restaurados."

L.HELP_HEADER = "Comandos:"
L.HELP_LINES = {
    "/wt - abrir las opciones",
    "/wt on | off - activar o desactivar la traducción",
    "/wt quick | accurate - elegir un modo",
    "/wt to <language> - traducir a este idioma (auto, en, de, fr, es, pt, ru, ko, zh, ja)",
    "/wt write on | off | <language> - traducir lo que escribes",
    "/wt test <text> - ver cómo se traduciría un mensaje",
    "/wt link - ayuda del modo Preciso (/wt link test envía una prueba)",
    "/wt remember - conservar los ajustes al reiniciar (arreglo para la beta)",
    "/wt status - ver qué está activado",
}
