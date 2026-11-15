# 릴리스 확인 목록과 롤백

`/adk:release` 가 성숙도 `ga` 기준으로 쓰는 확인 목록과 롤백 절차다.

## 1. 태그 전 확인

- `main` 최신 CI(`verify`·`review`) 통과
- `LorePin.toc` 의 `## Version` 이 이번 태그 번호와 같음, `## Interface` 가 현재 Retail 빌드와 같음
- `CHANGELOG.md` 에 이번 버전 절이 있음 → CurseForge 업로드의 changelog 가 이 절이다
- `sh .github/spec-trace.sh` 의 `M MANUAL` TC 마다 게임 내 확인한 방법과 결과 → 하나라도 비면 태그를 만들지 않는다
  - PR 마다 게임 내 확인 결과를 PR 에 남기므로, 그 기록으로 갈음한다. TC 마다 확인한 PR 을 릴리스 노트 초안에 적는다.
  - 갈음하는 조건: 그 PR 의 확인 커밋부터 태그 대상 커밋까지 아래 허용 목록 밖의 변경이 없다. 허용 목록 밖이 하나라도 바뀌었으면 그 변경이 닿는 TC 를 태그 대상 커밋으로 다시 확인한다.

    | 바뀌어도 되는 것 | 이유 |
    | --- | --- |
    | `LorePin.toc` 의 `## Version` 줄 | 버전 표시만 바뀐다 |
    | `docs/`, `*.md` | 문서, 배포 zip 에 실리지 않는다 |
    | `*.test.lua`, `scripts/` | 테스트·검증 도구, 배포 zip 에 실리지 않는다 |
    | `.github/`, `.claude/`, `.githooks/`, `.luacheckrc`, `.editorconfig`, `.gitignore` | CI·개발 설정, 배포 zip 에 실리지 않는다 |

    - 배포 zip 에서 빠지는 범위의 근거: `/curseforge:deploy` 의 패키징 규칙(curseforge 플러그인 `is_packaged`)이 `.` 으로 시작하는 경로, 최상위 `docs/`·`scripts/`, `*.md`, `*.test.lua` 를 뺀다. 그 규칙이 바뀌면 이 표도 맞춘다.
    - `.gitattributes` 는 zip 에 실리지 않지만 실리는 파일의 바이트(줄바꿈 등)를 바꿀 수 있다 → 허용 목록에 넣지 않는다.

  - 판정 명령: 아래 출력이 `LorePin.toc` 의 `## Version` 줄 변경뿐이면 갈음한다 (줄 단위라 `.toc` 의 다른 줄 변경도 보인다).

    ```sh
    git diff -U0 <확인 커밋>..<태그 대상> -- . ':!docs' ':!*.md' ':!*.test.lua' ':!scripts' ':!.github' ':!.claude' ':!.githooks' ':!.luacheckrc' ':!.editorconfig' ':!.gitignore'
    ```

- §3(이전 버전에서의 업데이트)은 저장 데이터를 바꾸는 릴리스에서만 게임 내에서 확인한다.
  - 저장 데이터를 정하는 파일: `Core/Config.lua`(`LorePinDB` 키·기본값), `Core/PinManager.lua`(핀 레코드), `Core/CategoryManager.lua`(사용자 카테고리 레코드).
  - `git diff <직전 태그>..<태그 대상> -- Core/Config.lua Core/PinManager.lua Core/CategoryManager.lua` 에서 저장 키·레코드 필드의 추가·삭제·이름 변경·기존 값의 의미 변경이 없으면 갈음한다. 판정 근거를 릴리스 노트 초안에 적는다.

## 2. 게임 내 확인 (태그 대상 커밋)

- 확인 환경: Retail 클라이언트, 이 애드온만 켠 상태와 평소 애드온 구성 둘 다
- Lua 오류 표시를 켠다: `/console scriptErrors 1` → 아래 항목 중 오류 창이 뜨면 실패

| 항목 | 확인 |
| --- | --- |
| 로드 | 로그인·`/reload` 후 오류 없음, 애드온 목록에 버전 표시 |
| 핀 생성 | `/lp`, `/lp <제목>`, 지도에서 위치 지정 |
| 핀 편집·삭제 | 상세 패널에서 수정 저장·취소·삭제, ESC 로 창 닫기 |
| 표시 | 월드맵에 핀 표시, 툴팁 |
| 목록 | `/lp list` 검색·카테고리 필터·정렬, 고른 핀 일괄 변경·삭제 |
| 카테고리 | 기본 카테고리, 사용자 카테고리 추가·삭제 |
| 설정 | `/lp settings` 값 변경 → `/reload` 후 유지 |
| 저장 | 핀·설정이 `/reload`·재접속 후 유지, 다른 캐릭터에서 같은 핀 |
| 언어 | koKR·enUS 클라이언트 문구 |

## 3. 이전 버전에서의 업데이트

- 직전 릴리스 버전으로 핀·사용자 카테고리·설정을 만든 `LorePinDB` 가 있는 상태에서 새 버전을 설치해 2를 다시 확인한다.
- 새 설치(빈 DB)만으로 확인하면 공허하다 → 기존 데이터의 호환이 이 항목의 대상이다.
- `LorePinDB` 의 구조를 바꾸는 릴리스는 이전 버전 코드가 새 구조를 읽어도 오류 없이 동작해야 한다 → 아래 롤백이 데이터 손상 없이 가능해야 하기 때문이다.
  - 지킬 수 없으면 노트 맨 위에 "이전 버전으로 되돌리면 {무엇}이 사라짐" 을 적고, 롤백 전에 `WTF/Account/<계정>/SavedVariables/LorePin.lua` 백업을 안내한다.

## 4. 롤백

배포한 파일은 업로드 API 로 지우거나 되돌릴 수 없고, 공개 태그는 이미 받은 사용자가 있다 → 되돌리기는 **이전 내용을 담은 새 patch 버전을 앞으로 배포**하는 것이다.

1. 문제 버전 `vX.Y.Z` 와 마지막 정상 버전 `vA.B.C` 를 정한다.
2. 이슈를 만들고(bugfix), 워크트리에서 문제 변경을 되돌린다.
   - 변경 일부만 문제면 해당 커밋만 `git revert`, 전부면 `git diff vA.B.C vX.Y.Z` 의 역을 적용한다.
   - `LorePin.toc` 의 `## Version` 을 `X.Y.(Z+1)` 로, `CHANGELOG.md` 에 "vX.Y.Z 의 {변경} 되돌림" 절을 추가한다.
3. 일반 PR 절차(검증·리뷰·merge)를 거친다 → 롤백도 `main` 이력에 남아야 다음 릴리스가 문제 변경을 다시 싣지 않는다.
4. `/adk:release X.Y.(Z+1)` → `/curseforge:deploy vX.Y.(Z+1)` 로 배포하고 1~3을 확인한다.
5. 문제 버전 정리
   - GitHub 릴리스 `vX.Y.Z`: 태그는 지우지 않고 노트 맨 위에 "철회: vX.Y.(Z+1) 사용" 을 적는다 (`gh release edit`).
   - CurseForge 의 `vX.Y.Z` 파일: 업로드 도구로는 바꿀 수 없다 → 저장소 소유자가 웹 UI(Files 탭)에서 처리한다.
