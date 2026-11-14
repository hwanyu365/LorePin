std = "lua51"
max_line_length = false
unused_args = false

-- WoW API 전역은 게임이 런타임에 넣어 준다. 그 목록을 유지하는 비용 대신 미정의 전역 경고를 끈다.
-- 전역 쓰기(111)는 켜 둔다 → local 을 빠뜨린 오염과 아래 목록에 없는 새 전역을 잡는다.
ignore = {
    "112", "113",  -- 미정의 전역 변경·읽기
    "21",          -- 미사용 지역변수
    "43",          -- 상위 변수 가림 (WoW 핸들러 인자 self 가 계속 걸린다)
    "512",         -- `for _ in pairs(t) do return true end` — 비었는지 보는 관용구
    "61",          -- 공백
}

-- 애드온이 일부러 만드는 전역. 늘릴 때 이 목록에 적어 의도를 남긴다.
globals = {
    "LorePinDB",
    "SLASH_LOREPIN1",
    "SLASH_LOREPIN2",
}

-- 러너 자기 점검용 fixture 는 일부러 깨진 코드와 전역 대역을 담는다.
exclude_files = { "scripts/test-fixtures/" }

-- 테스트는 WoW API 대역을 전역으로 넣는다 → load_source 로 불러온 소스가 그 대역을 전역으로 본다.
-- 111 을 끄지 않고 대역 이름만 허용한다 → 오타로 만든 전역은 계속 잡힌다.
local wowStubs = { "time", "UnitName", "GetRealmName", "GetLocale", "wipe", "C_Map", "TomTom", "UiMapPoint", "C_SuperTrack" }
files["**/*.test.lua"] = { globals = wowStubs }
files["scripts/test-support.lua"] = { globals = wowStubs }
