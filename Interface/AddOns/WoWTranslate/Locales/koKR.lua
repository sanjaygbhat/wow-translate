-- WoW Translate: Korean
local _, WT = ...
if WT.Locale() ~= "koKR" then return end
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "번"

-- Modes
L.MODE_QUICK = "빠른"
L.MODE_QUICK_BADGE = "|cff20ff20무료|r"
L.MODE_QUICK_BODY = "게임 안에서 바로 작동해요. 문장 조각별로 대략적인 뜻을 알려줘요. 항상 정확하지는 않아요."
L.MODE_ACCURATE = "정확"
L.MODE_ACCURATE_BADGE = "|cffffcc00유료 서비스|r"
L.MODE_ACCURATE_BODY = "자연스러운 진짜 번역이에요. PC에 무료 Companion 앱과 번역 서비스 계정이 필요해요 (매달 무료 사용량 제공, 이후 유료)."

-- Options window
L.SECTION_MODE = "어떻게 번역할까요?"
L.SECTION_READING = "채팅 읽기"
L.SECTION_WRITING = "채팅 쓰기"
L.SECTION_OTHER = "기타"

L.OPT_TRANSLATE_INCOMING = "다른 플레이어의 메시지 번역"
L.OPT_TRANSLATE_INCOMING_TIP = "다른 언어로 된 메시지를 채팅창에서 번역해요."
L.OPT_TRANSLATE_INTO = "번역할 언어:"
L.OPT_TRANSLATE_INTO_TIP = "읽고 싶은 언어예요. 자동을 고르면 게임 언어를 사용해요."
L.AUTO_LANG = "자동 (%s)"
L.OPT_SHOW_ORIGINAL = "원문도 함께 표시"
L.OPT_SHOW_ORIGINAL_TIP = "번역 뒤에 원래 메시지를 회색으로 덧붙여요."
L.OPT_LOCALIZE_LINKS = "아이템과 퀘스트 이름을 내 언어로"
L.OPT_LOCALIZE_LINKS_TIP = "아이템, 퀘스트, 주문 링크의 이름을 내 언어로 보여줘요. 게임에서 직접 가져오므로 항상 정확해요."
L.OPT_PAUSE_AFK = "자리 비움 중에는 일시 정지"
L.OPT_PAUSE_AFK_TIP = "자리 비움 상태일 때는 번역하지 않아요."
L.OPT_MARKER = "[번] 표시 보기"
L.OPT_MARKER_TIP = "번역된 줄 앞에 작은 [번]이 붙어요. 마우스를 올리면 원래 메시지를 볼 수 있어요."

L.OPT_TRANSLATE_OUTGOING = "내가 쓴 글 번역 (빠른 모드)"
L.OPT_TRANSLATE_OUTGOING_TIP = "메시지를 보내기 직전에 번역해요. 빠른 모드를 쓰므로 문장을 짧고 간단하게 써 주세요. 내 메시지를 정확하게 번역하려면 Companion 앱을 사용하세요. 번역한 텍스트를 복사해 주니 붙여넣기만 하면 돼요."
L.OPT_WRITE_IN = "쓸 언어:"
L.OPT_WRITE_IN_TIP = "상대방 언어(자동)를 고르면 각 플레이어가 마지막으로 나에게 쓴 언어로 답해요. 아직 아무도 다른 언어로 쓰지 않았다면 입력한 그대로 보내요."
L.THEIR_LANGUAGE = "상대방 언어 (자동)"
L.OPT_OUTGOING_TAG = "\"(번역됨)\" 표시 붙이기"
L.OPT_OUTGOING_TAG_TIP = "번역된 메시지 앞에 상대방 언어로 짧은 표시를 붙여서 기계 번역이라는 걸 알려줘요."

L.OPT_ROMANIZE = "외국 이름을 로마자로 표시"
L.OPT_ROMANIZE_TIP = "다른 문자로 된 이름(예: 小明, Иван)은 툴팁에 로마자 읽기가 표시돼요. 실제 이름은 절대 바뀌지 않아요."
L.OPT_MINIMAP = "미니맵 버튼"
L.OPT_MINIMAP_TIP = "미니맵에 WoW Translate 버튼을 표시해요. 미니맵 옆의 애드온 메뉴에서도 WoW Translate를 찾을 수 있어요."
L.OPT_REMEMBER = "재시작 후에도 설정 기억하기"
L.OPT_REMEMBER_TIP = "현재 WoW: Forever 베타는 게임을 다시 시작하면 애드온 설정을 잊어버려요. 이 옵션은 \"WoWTranslate\"라는 매크로 하나에 사본을 저장해요. 언제든 끌 수 있고, 끄면 매크로도 삭제돼요."
L.REMEMBER_NOTE = "베타용 임시 해결책. 매크로 칸 1개를 사용해요."
L.REMEMBER_AT_RISK = "게임을 다시 시작하면 변경 사항이 사라져요 (베타 버그). 유지하려면 이 칸을 체크하세요."
L.REMEMBER_ON = "설정을 기억해요 (\"WoWTranslate\" 매크로에 저장)."
L.REMEMBER_OFF = "이제 설정을 매크로에 저장하지 않아요."

L.CHANNEL_WHISPER = "귓속말"
L.CHANNEL_PARTY = "파티"
L.CHANNEL_RAID = "공격대"
L.CHANNEL_INSTANCE = "던전 & 전장"
L.CHANNEL_GUILD = "길드"
L.CHANNEL_SAY = "일반 대화"
L.CHANNEL_YELL = "외치기"
L.CHANNEL_CHANNEL = "거래 & 공개 채널"
L.CHANNEL_EMOTE = "감정 표현"

L.BUTTON_TRY = "사용해 보기"
L.BUTTON_TRY_TIP = "채팅창에 번역 예시를 몇 개 보여줘요."
L.BUTTON_RESET = "초기화"
L.BUTTON_HOW_TO_SETUP = "설정 방법"
L.BUTTON_SEND_TEST = "테스트 보내기"
L.BUTTON_USE_ACCURATE = "정확 모드 켜기"
L.BUTTON_OPEN_OPTIONS = "WoW Translate 열기"
L.SETTINGS_PANEL_TEXT = "채팅을 다른 언어로, 또는 다른 언어에서 번역해요. 언제든 /wt를 입력하면 옵션이 열려요."

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "정확 모드를 쓰려면 WoW Translate Companion 앱이 필요해요."
L.LINK_STATUS_ON = "Companion 연결이 켜져 있어요 (%s). 앱을 계속 실행해 두세요."
L.LINK_QUEUE = "%d개 대기 중"
L.LINK_TEST_MESSAGE = "WoW Translate에서 인사드려요! Companion 앱에서 이 글이 보이면 정확 모드가 작동하는 거예요."
L.LINK_TEST_SENT = "테스트를 보냈어요. 1초 안에 Companion 앱에 나타날 거예요."
L.LINK_CORNER_SET = "Companion 연결을 %s 모서리로 옮겼어요."
L.LINK_SIZE_SET = "이제 Companion 연결 사각형 크기는 %d픽셀이에요."
L.CORNER_TOPLEFT = "왼쪽 위"
L.CORNER_TOPRIGHT = "오른쪽 위"
L.CORNER_BOTTOMLEFT = "왼쪽 아래"
L.CORNER_BOTTOMRIGHT = "오른쪽 아래"

L.GUIDE_TITLE = "정확 모드 설정하기"
L.GUIDE_BODY = "애드온은 인터넷을 쓸 수 없어서, 정확한 번역은 게임 옆에서 실행되는 작은 무료 앱이 맡아요.\n\n"
    .. "1. |cffffd100WoW Translate Companion|r을 내려받아(아래 링크) 실행하세요.\n"
    .. "2. 앱에서 번역 서비스를 고르고 키를 붙여넣으세요. DeepL과 Google은 매달 무료 사용량을 주고, 그 이후에는 요금이 청구돼요.\n"
    .. "3. |cffffd100창 모드|r 또는 |cffffd100창 모드(전체 화면)|r로 플레이하세요.\n"
    .. "4. 여기서 정확 모드를 켜세요. 화면 모서리에 얇은 색 선이 나타나요. 애드온이 앱과 대화하는 방법이니 가리지 마세요.\n\n"
    .. "그러면 채팅 바로 옆, 앱 창에 번역이 나타나요."
L.GUIDE_LINK_LABEL = "다운로드 페이지 (클릭한 뒤 Ctrl+C로 복사):"

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "원문 (%s):"
L.TOOLTIP_QUICK_HINT = "빠른 번역: 대략적인 뜻을 알려주며 정확하지 않을 수 있어요."
L.TOOLTIP_ACCURATE_HINT = "정확한 번역은 Companion 앱에서 볼 수 있어요."
L.TOOLTIP_CLICK_HINT = "클릭하면 채팅에 원문을 보여줘요."
L.ORIGINAL_LINE = "원문 (%s):"

-- Minimap
L.MINIMAP_STATUS = "%s - %s 모드 - 번역 언어: %s"
L.MINIMAP_LEFT_CLICK = "왼쪽 클릭: 옵션"
L.MINIMAP_RIGHT_CLICK = "오른쪽 클릭: 번역 켜기/끄기"
L.STATE_ON = "켜짐"
L.STATE_OFF = "꺼짐"

-- Chat messages
L.GREETING = "%s 모드가 켜졌어요. 다른 언어로 된 메시지를 번역해요 (번역 언어: %s). 옵션은 /wt를 입력하세요."
L.GREETING_OFF = "번역이 꺼져 있어요. 다시 켜려면 /wt on을 입력하세요."
L.TRANSLATION_ON = "번역이 켜졌어요."
L.TRANSLATION_OFF = "번역이 꺼졌어요."
L.NOW_QUICK = "빠른 모드: 게임 안에서 무료로 번역해요."
L.NOW_ACCURATE = "정확 모드: 정확한 번역을 보려면 Companion 앱을 실행하세요. 도움말은 /wt link를 입력하세요."
L.NOW_TRANSLATING_INTO = "이제 번역할 언어: %s."
L.NOW_WRITING_IN = "이제 내 메시지를 쓸 언어: %s."
L.WRITING_ON = "메시지를 보내기 전에 번역해요."
L.WRITING_OFF = "메시지를 입력한 그대로 보내요."
L.LANG_CODES = "언어: auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "어떤 언어인지 알아내지 못했어요."
L.NOT_TRANSLATED = "(아는 단어가 너무 적음)"
L.KNOWN_PERCENT = "아는 단어 %d%%"
L.DEMO_HEADER = "번역 예시 (%s):"
L.DEMO_FOOTER = "빠른 모드는 대략적인 뜻을 알려줘요. 자연스러운 문장을 원하면 정확 모드를 사용하세요."
L.SETTINGS_RESET = "설정을 기본값으로 되돌렸어요."
L.ERR_NO_CHAT_FILTERS = "이 게임 버전에는 채팅 필터가 없어서 채팅을 번역할 수 없어요."

L.STATUS_HEADER = "상태 - 버전"
L.STATUS_MODE = "모드"
L.STATUS_READING = "읽기"
L.STATUS_WRITING = "쓰기"
L.STATUS_LINK = "Companion 연결"
L.STATUS_SAVED_OK = "설정이 정상적으로 저장돼요."
L.STATUS_SAVED_MACRO = "설정을 \"WoWTranslate\" 매크로에 보관하고 있어요 (베타용 임시 해결책)."
L.STATUS_SAVED_RISK = "게임을 다시 시작하면 설정이 초기화돼요 (베타 버그). 유지하려면 /wt remember를 입력하세요."
L.STATUS_LOCKDOWN = "지금은 게임이 채팅을 잠갔어요 (우두머리 전투 또는 평점제 경기). 끝날 때까지 다른 플레이어의 메시지를 번역할 수 없어요."

L.PERSIST_NO_MACRO_API = "매크로를 쓸 수 없어서 설정을 보관할 수 없어요."
L.PERSIST_MACRO_FULL = "\"WoWTranslate\" 매크로를 만들지 못했어요. 일반 매크로 칸이 모두 찼나요?"
L.PERSIST_SAVED = "저장했어요."
L.PERSIST_FIXED = "좋은 소식: 이제 게임이 애드온 설정을 직접 저장해서 \"WoWTranslate\" 매크로를 삭제했어요."
L.PERSIST_HINT = "팁: WoW: Forever 베타는 게임을 다시 시작하면 애드온 설정을 잊어버려요. 변경 사항을 유지하려면 /wt remember를 입력하세요 (또는 /wt에서 칸을 체크하세요)."
L.PERSIST_RESTORED = "설정을 복원했어요."

L.HELP_HEADER = "명령어:"
L.HELP_LINES = {
    "/wt - 옵션 열기",
    "/wt on | off - 번역 켜기/끄기",
    "/wt quick | accurate - 모드 선택",
    "/wt to <language> - 이 언어로 번역 (auto, en, de, fr, es, pt, ru, ko, zh, ja)",
    "/wt write on | off | <language> - 내가 쓴 글 번역",
    "/wt test <text> - 메시지가 어떻게 번역되는지 보기",
    "/wt link - 정확 모드 도움말 (/wt link test로 테스트 전송)",
    "/wt remember - 재시작 후에도 설정 유지 (베타용 임시 해결책)",
    "/wt status - 켜진 기능 보기",
}
