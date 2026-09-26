-- WoW Translate: Portuguese
local _, WT = ...
local loc = WT.Locale() if loc ~= "ptBR" and loc ~= "ptPT" then return end
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "T"

-- Modes
L.MODE_QUICK = "Rápido"
L.MODE_QUICK_BADGE = "|cff20ff20GRÁTIS|r"
L.MODE_QUICK_BODY = "Funciona na hora, dentro do jogo. Dá o sentido geral, frase por frase. Nem sempre é exato."
L.MODE_ACCURATE = "Preciso"
L.MODE_ACCURATE_BADGE = "|cffffcc00SERVIÇO PAGO|r"
L.MODE_ACCURATE_BODY = "Traduções reais e naturais. Precisa do app gratuito Companion no seu PC e de uma conta de tradução (cota mensal grátis, depois pago)."

-- Options window
L.SECTION_MODE = "Como devo traduzir?"
L.SECTION_READING = "Ler o chat"
L.SECTION_WRITING = "Escrever no chat"
L.SECTION_OTHER = "Outros"

L.OPT_TRANSLATE_INCOMING = "Traduzir mensagens de outros jogadores"
L.OPT_TRANSLATE_INCOMING_TIP = "Mensagens em outros idiomas são traduzidas na sua janela de chat."
L.OPT_TRANSLATE_INTO = "Traduzir para:"
L.OPT_TRANSLATE_INTO_TIP = "O idioma que você quer ler. Auto usa o idioma do seu jogo."
L.AUTO_LANG = "Auto (%s)"
L.OPT_SHOW_ORIGINAL = "Mostrar também o texto original"
L.OPT_SHOW_ORIGINAL_TIP = "Mostra a mensagem original em cinza depois da tradução."
L.OPT_LOCALIZE_LINKS = "Itens e missões no meu idioma"
L.OPT_LOCALIZE_LINKS_TIP = "Links de itens, missões e feitiços mostram o nome no seu idioma. Isso vem direto do jogo, então é sempre exato."
L.OPT_PAUSE_AFK = "Pausar enquanto estou ausente (AFK)"
L.OPT_PAUSE_AFK_TIP = "Nada é traduzido enquanto você estiver marcado como ausente."
L.OPT_MARKER = "Mostrar a etiqueta [T]"
L.OPT_MARKER_TIP = "Um pequeno [T] na frente das linhas traduzidas. Passe o mouse sobre ele para ver a mensagem original."

L.OPT_TRANSLATE_OUTGOING = "Traduzir o que eu escrevo (Rápido)"
L.OPT_TRANSLATE_OUTGOING_TIP = "Sua mensagem é traduzida logo antes de ser enviada. Usa o modo Rápido, então escreva frases curtas e simples. Para traduções precisas das suas próprias mensagens, use o app Companion: ele traduz e copia o texto para você colar."
L.OPT_WRITE_IN = "Escrever em:"
L.OPT_WRITE_IN_TIP = "Idioma do jogador (auto) responde a cada jogador no último idioma em que ele escreveu para você. Se ninguém escreveu em outro idioma ainda, sua mensagem é enviada do jeito que você digitou."
L.THEIR_LANGUAGE = "Idioma do jogador (auto)"
L.OPT_OUTGOING_TAG = "Adicionar \"(traduzido)\" para avisar"
L.OPT_OUTGOING_TAG_TIP = "Adiciona uma etiqueta curta, no idioma deles, antes da sua mensagem traduzida para que saibam que foi traduzida por uma máquina."

L.OPT_ROMANIZE = "Nomes estrangeiros em letras latinas"
L.OPT_ROMANIZE_TIP = "Nomes em outros alfabetos (como 小明 ou Иван) ganham uma leitura em letras latinas na dica. O nome real nunca é alterado."
L.OPT_MINIMAP = "Botão no minimapa"
L.OPT_MINIMAP_TIP = "Mostra o botão do WoW Translate no minimapa. Você também encontra o WoW Translate no menu de addons ao lado do minimapa."
L.OPT_REMEMBER = "Manter configurações após reiniciar"
L.OPT_REMEMBER_TIP = "A beta do WoW: Forever esquece por enquanto as configurações de addons quando o jogo reinicia. Isto guarda uma cópia em uma macro chamada \"WoWTranslate\". Você pode desligar quando quiser e a macro é removida."
L.REMEMBER_NOTE = "Correção da beta. Usa um espaço de macro."
L.REMEMBER_AT_RISK = "Suas alterações serão perdidas quando o jogo reiniciar (bug da beta). Marque esta caixa para mantê-las."
L.REMEMBER_ON = "Suas configurações serão lembradas (guardadas na macro \"WoWTranslate\")."
L.REMEMBER_OFF = "As configurações não serão mais guardadas em uma macro."

L.CHANNEL_WHISPER = "Sussurros"
L.CHANNEL_PARTY = "Grupo"
L.CHANNEL_RAID = "Raide"
L.CHANNEL_INSTANCE = "Masmorra e Campo de Batalha"
L.CHANNEL_GUILD = "Guilda"
L.CHANNEL_SAY = "Dizer"
L.CHANNEL_YELL = "Gritar"
L.CHANNEL_CHANNEL = "Comércio e Mundo"
L.CHANNEL_EMOTE = "Emotes"

L.BUTTON_TRY = "Experimentar"
L.BUTTON_TRY_TIP = "Mostra alguns exemplos de tradução na sua janela de chat."
L.BUTTON_RESET = "Redefinir"
L.BUTTON_HOW_TO_SETUP = "Como configurar"
L.BUTTON_SEND_TEST = "Enviar um teste"
L.BUTTON_USE_ACCURATE = "Ativar o modo Preciso"
L.BUTTON_OPEN_OPTIONS = "Abrir o WoW Translate"
L.SETTINGS_PANEL_TEXT = "Traduz o chat de e para outros idiomas. Digite /wt a qualquer momento para abrir as opções."

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "O modo Preciso precisa do app WoW Translate Companion."
L.LINK_STATUS_ON = "Conexão com o Companion ativa (%s). Mantenha o app aberto."
L.LINK_QUEUE = "%d na fila"
L.LINK_TEST_MESSAGE = "Olá do WoW Translate! Se você consegue ler isto no app Companion, o modo Preciso está funcionando."
L.LINK_TEST_SENT = "Teste enviado. Ele deve aparecer no app Companion em até um segundo."
L.LINK_CORNER_SET = "Conexão com o Companion movida para o canto %s."
L.LINK_SIZE_SET = "Os quadrados da conexão com o Companion agora têm %d pixels."
L.CORNER_TOPLEFT = "superior esquerdo"
L.CORNER_TOPRIGHT = "superior direito"
L.CORNER_BOTTOMLEFT = "inferior esquerdo"
L.CORNER_BOTTOMRIGHT = "inferior direito"

L.GUIDE_TITLE = "Configurar o modo Preciso"
L.GUIDE_BODY = "Addons não podem usar a internet, então as traduções precisas vêm de um pequeno app gratuito que roda ao lado do jogo.\n\n"
    .. "1. Baixe o |cffffd100WoW Translate Companion|r (link abaixo) e abra-o.\n"
    .. "2. No app, escolha um serviço de tradução e cole sua chave. DeepL e Google dão uma cota grátis todo mês e depois cobram.\n"
    .. "3. Jogue no modo |cffffd100Janela|r ou |cffffd100Janela (tela cheia)|r.\n"
    .. "4. Ative o modo Preciso aqui. Uma linha fina colorida aparece em um canto da tela: é assim que o addon fala com o app, então deixe-a visível.\n\n"
    .. "As traduções então aparecem na janela do app, bem ao lado do seu chat."
L.GUIDE_LINK_LABEL = "Página de download (clique e aperte Ctrl+C para copiar):"

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "Original (%s):"
L.TOOLTIP_QUICK_HINT = "Tradução rápida: dá o sentido geral e pode não ser exata."
L.TOOLTIP_ACCURATE_HINT = "A tradução precisa está no app Companion."
L.TOOLTIP_CLICK_HINT = "Clique para mostrar o original no chat."
L.ORIGINAL_LINE = "Original (%s):"

-- Minimap
L.MINIMAP_STATUS = "%s - modo %s - para: %s"
L.MINIMAP_LEFT_CLICK = "Clique esquerdo: opções"
L.MINIMAP_RIGHT_CLICK = "Clique direito: ligar ou desligar a tradução"
L.STATE_ON = "Ligado"
L.STATE_OFF = "Desligado"

-- Chat messages
L.GREETING = "Modo %s ligado. Mensagens em outros idiomas são traduzidas para: %s. Digite /wt para ver as opções."
L.GREETING_OFF = "A tradução está desligada. Digite /wt on para ligá-la de novo."
L.TRANSLATION_ON = "A tradução está ligada."
L.TRANSLATION_OFF = "A tradução está desligada."
L.NOW_QUICK = "Modo Rápido: traduções grátis dentro do jogo."
L.NOW_ACCURATE = "Modo Preciso: abra o app Companion para ver traduções precisas. Digite /wt link para ajuda."
L.NOW_TRANSLATING_INTO = "Traduzindo agora para: %s."
L.NOW_WRITING_IN = "Suas mensagens serão escritas em: %s."
L.WRITING_ON = "Suas mensagens serão traduzidas antes de serem enviadas."
L.WRITING_OFF = "Suas mensagens serão enviadas do jeito que você digitar."
L.LANG_CODES = "Idiomas: auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "Não consegui identificar que idioma é esse."
L.NOT_TRANSLATED = "(poucas palavras conhecidas)"
L.KNOWN_PERCENT = "%d%% das palavras conhecidas"
L.DEMO_HEADER = "Exemplos traduzidos (%s):"
L.DEMO_FOOTER = "O modo Rápido dá o sentido geral. Para frases naturais, use o modo Preciso."
L.SETTINGS_RESET = "As configurações voltaram ao padrão."
L.ERR_NO_CHAT_FILTERS = "Esta versão do jogo não tem filtros de chat, então o chat não pode ser traduzido."

L.STATUS_HEADER = "Status - versão"
L.STATUS_MODE = "Modo"
L.STATUS_READING = "Leitura"
L.STATUS_WRITING = "Escrita"
L.STATUS_LINK = "Conexão com o Companion"
L.STATUS_SAVED_OK = "As configurações são salvas normalmente."
L.STATUS_SAVED_MACRO = "As configurações ficam guardadas na macro \"WoWTranslate\" (correção da beta)."
L.STATUS_SAVED_RISK = "As configurações serão redefinidas quando o jogo reiniciar (bug da beta). Digite /wt remember para mantê-las."
L.STATUS_LOCKDOWN = "O jogo está bloqueando o chat agora (luta contra chefe ou partida ranqueada), então as mensagens de outros jogadores só poderão ser traduzidas quando acabar."

L.PERSIST_NO_MACRO_API = "Macros não estão disponíveis, então as configurações não podem ser guardadas."
L.PERSIST_MACRO_FULL = "Não foi possível criar a macro \"WoWTranslate\". Todos os espaços de macros gerais estão cheios?"
L.PERSIST_SAVED = "Salvo."
L.PERSIST_FIXED = "Boa notícia: agora o jogo salva sozinho as configurações de addons, então a macro \"WoWTranslate\" foi removida."
L.PERSIST_HINT = "Dica: a beta do WoW: Forever esquece as configurações de addons quando o jogo reinicia. Digite /wt remember (ou marque a caixa em /wt) para manter suas alterações."
L.PERSIST_RESTORED = "Configurações restauradas."

L.HELP_HEADER = "Comandos:"
L.HELP_LINES = {
    "/wt - abrir as opções",
    "/wt on | off - ligar ou desligar a tradução",
    "/wt quick | accurate - escolher um modo",
    "/wt to <language> - traduzir para este idioma (auto, en, de, fr, es, pt, ru, ko, zh, ja)",
    "/wt write on | off | <language> - traduzir o que você escreve",
    "/wt test <text> - ver como uma mensagem seria traduzida",
    "/wt link - ajuda do modo Preciso (/wt link test envia um teste)",
    "/wt remember - manter as configurações após reiniciar (correção da beta)",
    "/wt status - mostrar o que está ligado",
}
