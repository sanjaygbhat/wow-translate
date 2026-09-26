-- WoW Translate: French
local _, WT = ...
if WT.Locale() ~= "frFR" then return end
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "T"

-- Modes
L.MODE_QUICK = "Rapide"
L.MODE_QUICK_BADGE = "|cff20ff20GRATUIT|r"
L.MODE_QUICK_BODY = "Marche tout de suite, dans le jeu. Donne le sens général, morceau par morceau. Pas toujours exact."
L.MODE_ACCURATE = "Précis"
L.MODE_ACCURATE_BADGE = "|cffffcc00SERVICE PAYANT|r"
L.MODE_ACCURATE_BODY = "De vraies traductions, naturelles. Nécessite l'app gratuite Companion sur votre PC et un compte de traduction (quota mensuel gratuit, puis payant)."

-- Options window
L.SECTION_MODE = "Comment dois-je traduire ?"
L.SECTION_READING = "Lire le chat"
L.SECTION_WRITING = "Écrire dans le chat"
L.SECTION_OTHER = "Autres"

L.OPT_TRANSLATE_INCOMING = "Traduire les messages des joueurs"
L.OPT_TRANSLATE_INCOMING_TIP = "Les messages dans d'autres langues sont traduits dans votre fenêtre de chat."
L.OPT_TRANSLATE_INTO = "Traduire en :"
L.OPT_TRANSLATE_INTO_TIP = "La langue que vous voulez lire. Auto utilise la langue de votre jeu."
L.AUTO_LANG = "Auto (%s)"
L.OPT_SHOW_ORIGINAL = "Afficher aussi le texte d'origine"
L.OPT_SHOW_ORIGINAL_TIP = "Ajoute le message d'origine en gris après la traduction."
L.OPT_LOCALIZE_LINKS = "Objets et quêtes dans ma langue"
L.OPT_LOCALIZE_LINKS_TIP = "Les liens d'objets, de quêtes et de sorts affichent leur nom dans votre langue. Cela vient directement du jeu, donc c'est toujours exact."
L.OPT_PAUSE_AFK = "Pause quand je suis absent (ABS)"
L.OPT_PAUSE_AFK_TIP = "Pas de traduction tant que vous êtes marqué ABS."
L.OPT_MARKER = "Afficher l'étiquette [T]"
L.OPT_MARKER_TIP = "Un petit [T] devant les lignes traduites. Survolez-le pour voir le message d'origine."

L.OPT_TRANSLATE_OUTGOING = "Traduire ce que j'écris (Rapide)"
L.OPT_TRANSLATE_OUTGOING_TIP = "Votre message est traduit juste avant d'être envoyé. Cela utilise le mode Rapide : faites des phrases courtes et simples. Pour traduire vos propres messages avec précision, utilisez l'app Companion : elle traduit et copie le texte pour que vous n'ayez plus qu'à le coller."
L.OPT_WRITE_IN = "Écrire en :"
L.OPT_WRITE_IN_TIP = "Langue du joueur (auto) répond à chaque joueur dans la dernière langue qu'il a utilisée pour vous écrire. Si personne n'a encore écrit dans une autre langue, votre message est envoyé tel que vous l'avez tapé."
L.THEIR_LANGUAGE = "Langue du joueur (auto)"
L.OPT_OUTGOING_TAG = "Ajouter \"(traduit)\" pour prévenir"
L.OPT_OUTGOING_TAG_TIP = "Ajoute une courte mention, dans leur langue, devant votre message traduit pour qu'ils sachent qu'une machine l'a traduit."

L.OPT_ROMANIZE = "Noms étrangers en lettres latines"
L.OPT_ROMANIZE_TIP = "Les noms écrits dans d'autres alphabets (comme 小明 ou Иван) ont une lecture en lettres latines dans leur infobulle. Le vrai nom ne change jamais."
L.OPT_MINIMAP = "Bouton de la minicarte"
L.OPT_MINIMAP_TIP = "Affiche le bouton WoW Translate sur la minicarte. Vous trouverez aussi WoW Translate dans le menu des addons à côté de la minicarte."
L.OPT_REMEMBER = "Garder mes réglages au redémarrage"
L.OPT_REMEMBER_TIP = "La bêta de WoW: Forever oublie pour l'instant les réglages des addons quand le jeu redémarre. Cette option en garde une copie dans une macro nommée \"WoWTranslate\". Vous pouvez la désactiver à tout moment et la macro est supprimée."
L.REMEMBER_NOTE = "Correctif bêta. Utilise un emplacement de macro."
L.REMEMBER_AT_RISK = "Vos changements seront perdus au redémarrage du jeu (bug de la bêta). Cochez cette case pour les garder."
L.REMEMBER_ON = "Vos réglages seront gardés (dans la macro \"WoWTranslate\")."
L.REMEMBER_OFF = "Les réglages ne seront plus gardés dans une macro."

L.CHANNEL_WHISPER = "Chuchotements"
L.CHANNEL_PARTY = "Groupe"
L.CHANNEL_RAID = "Raid"
L.CHANNEL_INSTANCE = "Donjon & champ de bataille"
L.CHANNEL_GUILD = "Guilde"
L.CHANNEL_SAY = "Dire"
L.CHANNEL_YELL = "Crier"
L.CHANNEL_CHANNEL = "Commerce & Monde"
L.CHANNEL_EMOTE = "Emotes"

L.BUTTON_TRY = "Essayer"
L.BUTTON_TRY_TIP = "Affiche quelques exemples de traduction dans votre fenêtre de chat."
L.BUTTON_RESET = "Réinitialiser"
L.BUTTON_HOW_TO_SETUP = "Comment le configurer"
L.BUTTON_SEND_TEST = "Envoyer un test"
L.BUTTON_USE_ACCURATE = "Activer le mode Précis"
L.BUTTON_OPEN_OPTIONS = "Ouvrir WoW Translate"
L.SETTINGS_PANEL_TEXT = "Traduit le chat depuis et vers d'autres langues. Tapez /wt à tout moment pour ouvrir les options."

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "Le mode Précis nécessite l'app WoW Translate Companion."
L.LINK_STATUS_ON = "Lien Companion actif (%s). Laissez l'app ouverte."
L.LINK_QUEUE = "%d en attente"
L.LINK_TEST_MESSAGE = "Bonjour de WoW Translate ! Si vous lisez ceci dans l'app Companion, le mode Précis fonctionne."
L.LINK_TEST_SENT = "Test envoyé. Il devrait apparaître dans l'app Companion en moins d'une seconde."
L.LINK_CORNER_SET = "Lien Companion déplacé dans le coin %s."
L.LINK_SIZE_SET = "Les carrés du lien Companion font maintenant %d pixels."
L.CORNER_TOPLEFT = "supérieur gauche"
L.CORNER_TOPRIGHT = "supérieur droit"
L.CORNER_BOTTOMLEFT = "inférieur gauche"
L.CORNER_BOTTOMRIGHT = "inférieur droit"

L.GUIDE_TITLE = "Configurer le mode Précis"
L.GUIDE_BODY = "Les addons n'ont pas accès à Internet, donc les traductions précises viennent d'une petite app gratuite qui tourne à côté du jeu.\n\n"
    .. "1. Téléchargez |cffffd100WoW Translate Companion|r (lien ci-dessous) et lancez-la.\n"
    .. "2. Dans l'app, choisissez un service de traduction et collez votre clé. DeepL et Google offrent un quota gratuit chaque mois, puis c'est payant.\n"
    .. "3. Jouez en mode |cffffd100Fenêtré|r ou |cffffd100Fenêtré (plein écran)|r.\n"
    .. "4. Activez le mode Précis ici. Une fine ligne colorée apparaît dans un coin de votre écran : c'est ainsi que l'addon parle à l'app, alors laissez-la visible.\n\n"
    .. "Les traductions s'affichent ensuite dans la fenêtre de l'app, juste à côté de votre chat."
L.GUIDE_LINK_LABEL = "Page de téléchargement (cliquez, puis Ctrl+C pour copier) :"

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "Original (%s) :"
L.TOOLTIP_QUICK_HINT = "Traduction rapide : donne le sens général et peut être inexacte."
L.TOOLTIP_ACCURATE_HINT = "La traduction précise est dans l'app Companion."
L.TOOLTIP_CLICK_HINT = "Cliquez pour afficher l'original dans le chat."
L.ORIGINAL_LINE = "Original (%s) :"

-- Minimap
L.MINIMAP_STATUS = "%s - mode %s - vers : %s"
L.MINIMAP_LEFT_CLICK = "Clic gauche : options"
L.MINIMAP_RIGHT_CLICK = "Clic droit : activer ou désactiver la traduction"
L.STATE_ON = "Activé"
L.STATE_OFF = "Désactivé"

-- Chat messages
L.GREETING = "Mode %s activé. Les messages dans d'autres langues sont traduits en : %s. Tapez /wt pour les options."
L.GREETING_OFF = "La traduction est désactivée. Tapez /wt on pour la réactiver."
L.TRANSLATION_ON = "La traduction est activée."
L.TRANSLATION_OFF = "La traduction est désactivée."
L.NOW_QUICK = "Mode Rapide : traductions gratuites dans le jeu."
L.NOW_ACCURATE = "Mode Précis : lancez l'app Companion pour voir les traductions précises. Tapez /wt link pour de l'aide."
L.NOW_TRANSLATING_INTO = "Traduction maintenant vers : %s."
L.NOW_WRITING_IN = "Vos messages seront écrits en : %s."
L.WRITING_ON = "Vos messages seront traduits avant d'être envoyés."
L.WRITING_OFF = "Vos messages seront envoyés tels que vous les tapez."
L.LANG_CODES = "Langues : auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "Je n'ai pas pu savoir de quelle langue il s'agit."
L.NOT_TRANSLATED = "(trop peu de mots connus)"
L.KNOWN_PERCENT = "%d%% des mots connus"
L.DEMO_HEADER = "Exemples traduits (%s) :"
L.DEMO_FOOTER = "Le mode Rapide donne le sens général. Pour des phrases naturelles, utilisez le mode Précis."
L.SETTINGS_RESET = "Les réglages sont revenus par défaut."
L.ERR_NO_CHAT_FILTERS = "Cette version du jeu n'a pas de filtres de chat, le chat ne peut donc pas être traduit."

L.STATUS_HEADER = "Statut - version"
L.STATUS_MODE = "Mode"
L.STATUS_READING = "Lecture"
L.STATUS_WRITING = "Écriture"
L.STATUS_LINK = "Lien Companion"
L.STATUS_SAVED_OK = "Les réglages sont sauvegardés normalement."
L.STATUS_SAVED_MACRO = "Les réglages sont gardés dans la macro \"WoWTranslate\" (correctif bêta)."
L.STATUS_SAVED_RISK = "Les réglages seront réinitialisés au redémarrage du jeu (bug de la bêta). Tapez /wt remember pour les garder."
L.STATUS_LOCKDOWN = "Le jeu bloque le chat en ce moment (combat de boss ou match classé), donc les messages des autres joueurs ne peuvent pas être traduits avant la fin."

L.PERSIST_NO_MACRO_API = "Les macros ne sont pas disponibles, les réglages ne peuvent donc pas être gardés."
L.PERSIST_MACRO_FULL = "Impossible de créer la macro \"WoWTranslate\". Tous les emplacements de macros générales sont-ils pleins ?"
L.PERSIST_SAVED = "Sauvegardé."
L.PERSIST_FIXED = "Bonne nouvelle : le jeu sauvegarde maintenant lui-même les réglages des addons, la macro \"WoWTranslate\" a donc été supprimée."
L.PERSIST_HINT = "Astuce : la bêta de WoW: Forever oublie les réglages des addons quand le jeu redémarre. Tapez /wt remember (ou cochez la case dans /wt) pour garder vos changements."
L.PERSIST_RESTORED = "Réglages restaurés."

L.HELP_HEADER = "Commandes :"
L.HELP_LINES = {
    "/wt - ouvrir les options",
    "/wt on | off - activer ou désactiver la traduction",
    "/wt quick | accurate - choisir un mode",
    "/wt to <language> - traduire dans cette langue (auto, en, de, fr, es, pt, ru, ko, zh, ja)",
    "/wt write on | off | <language> - traduire ce que vous écrivez",
    "/wt test <text> - voir comment un message serait traduit",
    "/wt link - aide du mode Précis (/wt link test envoie un test)",
    "/wt remember - garder les réglages au redémarrage (correctif bêta)",
    "/wt status - voir ce qui est activé",
}
