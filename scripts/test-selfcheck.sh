#!/bin/sh
# 러너가 실패를 통과로 삼키면 모든 테스트가 공허해진다 → 실패 fixture 마다 비정상 종료를 확인한다.
set -u
cd "$(dirname "$0")/.."
run() { lua5.1 scripts/test.lua "$@" > /dev/null 2>&1; }

run scripts/test-fixtures/pass.lua || { echo "러너 자기 점검 실패: 통과 fixture 가 실패함"; exit 1; }
for f in scripts/test-fixtures/fail_*.lua; do
    if run "$f"; then echo "러너 자기 점검 실패: $f 가 통과함"; exit 1; fi
done
if run scripts/test-fixtures/pass.lua scripts/test-fixtures/fail_eq.lua; then echo "러너 자기 점검 실패: 여러 파일 중 하나의 실패가 묻힘"; exit 1; fi
echo "러너 자기 점검: ok"
