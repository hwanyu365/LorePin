#!/bin/bash
# 로컬과 CI 가 같이 돌리는 단일 검증 명령.
set -euo pipefail
cd "$(dirname "$0")/.."

TOC="$(ls ./*.toc)"

# TOC 에 나열된 파일이 빠지면 게임은 조용히 로드에 실패한다 → 목록과 실제 파일을 대조한다.
missing=0
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    rel="$(printf '%s' "$line" | tr '\\' '/')"
    if [ ! -f "$rel" ]; then
        echo "TOC 에 있으나 파일이 없음: $rel"
        missing=$((missing + 1))
    fi
done < "$TOC"
if [ "$missing" -gt 0 ]; then
    echo "실패: TOC 에 나열된 파일 $missing 개가 없습니다."
    exit 1
fi
echo "TOC 정합: ok ($TOC)"

if ! command -v luacheck > /dev/null; then
    echo "실패: luacheck 가 없습니다. 설치: luarocks install luacheck"
    exit 1
fi
luacheck .

if ! command -v lua5.1 > /dev/null; then
    echo "실패: lua5.1 이 없습니다. 설치: apt-get install lua5.1 (Windows: LuaBinaries 5.1.5 를 PATH 의 lua5.1 로)"
    exit 1
fi
sh scripts/test-selfcheck.sh

# 커밋 전 테스트도 돌린다 → 추적성 검사(spec-trace.sh)와 같은 범위.
tests="$(git -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.test.lua')"
if [ -z "$tests" ]; then
    echo "테스트: 0 files"
else
    # 파일 목록은 줄 단위로만 나눈다 → 이름에 공백이 있어도 한 파일이다.
    # shellcheck disable=SC2086
    ( IFS=$'\n'; set -f; lua5.1 scripts/test.lua $tests )
fi
