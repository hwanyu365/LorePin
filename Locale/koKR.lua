local _, ns = ...
if GetLocale() ~= "koKR" then return end

local L = ns.L

-- General
L.PIN_CREATED         = "핀 생성됨: %s"
L.PIN_UPDATED         = "핀 수정됨: %s"
L.PIN_DELETED         = "핀 삭제됨: %s"
L.PIN_NOT_FOUND       = "핀을 찾을 수 없습니다."
L.NO_POSITION         = "현재 위치를 확인할 수 없습니다."
L.NO_MAP              = "사용 가능한 맵이 없습니다."
L.MAX_PINS_REACHED    = "최대 핀 개수에 도달했습니다 (%d)."
L.TITLE_REQUIRED      = "제목을 입력해주세요."

-- Categories
L.CATEGORY_GENERAL    = "일반"
L.CATEGORY_QUEST      = "퀘스트"
L.CATEGORY_DANGER     = "위험"
L.CATEGORY_GATHER     = "수집"
L.CATEGORY_SCENIC     = "풍경"
L.CATEGORY_COMPLETE   = "완료"

-- Pin Popup
L.POPUP_TITLE         = "새 핀"
L.POPUP_EDIT_TITLE    = "핀 편집"
L.FIELD_TITLE         = "제목"
L.FIELD_NOTE          = "메모"
L.FIELD_CATEGORY      = "카테고리"
L.FIELD_LOCATION      = "위치"
L.FIELD_COORD_X       = "X"
L.FIELD_COORD_Y       = "Y"
L.BTN_USE_PLAYER_POS  = "현재 위치"
L.BTN_PICK_FROM_MAP   = "지도에서 선택"
L.PICK_MODE_HINT      = "월드맵에서 핀을 꽂을 위치를 클릭하세요. ESC 로 취소."
L.INVALID_COORDINATES = "잘못된 좌표입니다. X, Y는 0~100 사이여야 합니다."
L.BUTTON_SAVE         = "저장"
L.BUTTON_CANCEL       = "취소"
L.BUTTON_DELETE       = "삭제"
L.BUTTON_EDIT         = "편집"
L.BUTTON_CLOSE        = "닫기"
L.BUTTON_WAYPOINT     = "경로"
L.BUTTON_TOMTOM       = "TomTom"

-- Detail / Edit Panel
L.DETAIL_TITLE        = "핀"
L.DETAIL_MODE_VIEW    = "보기"
L.DETAIL_MODE_EDIT    = "편집"
L.CREATED_AT          = "생성"
L.CREATED_BY          = "작성자"
L.CONFIRM_DELETE      = "이 핀을 삭제하시겠습니까?"
L.UNSAVED_CHANGES     = "저장하지 않은 변경 사항이 있습니다."
L.DISCARD_CONFIRM     = "변경 사항을 버리시겠습니까?"

-- List Panel
L.LIST_TITLE          = "내 핀 목록"
L.LIST_EMPTY          = "아직 핀이 없습니다. /lp 로 생성하세요."
L.LIST_SEARCH         = "검색"
L.LIST_FILTER_ALL     = "전체"
L.LIST_SORT_NEWEST    = "최신순"
L.LIST_SORT_OLDEST    = "오래된순"
L.LIST_SORT_MAP       = "지역별"
L.LIST_TOTAL_COUNT    = "총 %d개 핀"
L.LIST_NEW_PIN        = "새 핀"
L.LIST_ROW_WAYPOINT   = "경로"
L.LIST_ROW_TOMTOM     = "TomTom"
L.TOMTOM_NOT_LOADED   = "TomTom 애드온이 설치되지 않았습니다."

-- Settings
L.SETTING_SHOW_WMAP   = "월드맵에 핀 표시"
L.SETTING_SHOW_MMAP   = "미니맵에 핀 표시"
L.SETTING_WMAP_SIZE   = "월드맵 아이콘 크기"
L.SETTING_MMAP_SIZE   = "미니맵 아이콘 크기"
L.SETTING_MAX_PINS    = "최대 핀 개수"
L.SETTING_RESET_PINS       = "모든 핀 초기화"
L.SETTING_RESET_PINS_CONFIRM = "모든 핀을 삭제하시겠습니까? 되돌릴 수 없습니다."
L.SETTING_RESET_SETTINGS    = "설정을 기본값으로 초기화"
L.SETTING_RESET_SETTINGS_CONFIRM = "모든 설정을 기본값으로 되돌리시겠습니까? (핀은 삭제되지 않습니다.)"
L.SETTING_OPEN_LIST         = "핀 목록 열기"

-- Slash Commands
L.HELP_HEADER         = "LorePin 명령어:"
L.HELP_NEW            = "/lp — 현재 위치에 핀 생성"
L.HELP_TITLE          = "/lp <제목> — 제목으로 빠른 생성"
L.HELP_LIST           = "/lp list — 모든 핀 보기"
L.HELP_SETTINGS       = "/lp settings — 설정 열기"
L.HELP_HELP           = "/lp help — 이 도움말 보기"
