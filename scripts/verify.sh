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
