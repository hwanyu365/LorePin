# 길안내 스펙

## 1. 개요

| 항목 | 값 |
| --- | --- |
| 문서명 | spec_navigation |
| 작성일 / 최종 수정일 | 2026-11-14 / 2026-11-14 |
| 버전 | 1.0 |
| 기준 커밋 ID | 1a40209 |

- **기능명:** 기본 웨이포인트·TomTom 웨이포인트 토글 (UC5)
- **목적 (Why):** 기록한 곳으로 다시 가는 것이 핀의 주된 쓰임이다 → 핀에서 바로 길안내를 켜고 끈다.

## 2. 목표 및 범위

### In Scope

- WoW 기본 사용자 웨이포인트 토글, TomTom 이 설치돼 있으면 TomTom 웨이포인트 토글

### Out of Scope

- 경로 계산, 여러 핀 연속 안내

## 3. 요구사항

### 3.1 사용자 스토리

- `US#5` [as-built] 핀 위치로 가려는 플레이어로서, 길을 찾기 위해, 핀에서 웨이포인트를 켜고 끄고 싶다 → FR#21~FR#24

### 3.2 기능 요구사항

- `FR#21` [as-built] 기본 웨이포인트 토글

  ```
  Given 현재 사용자 웨이포인트가 이 핀의 지도이고 좌표 차이가 x·y 모두 0.001 미만
  When  토글
  Then  웨이포인트를 지우고 "removed"
  Given 그 밖
  When  토글
  Then  핀 위치에 웨이포인트를 만들고 추적(super-track)을 켠 뒤 "added"
  Given 핀에 mapID 가 없거나 웨이포인트 API 가 없다, 또는 설정 중 오류
  Then  nil
  ```

  - WoW 는 사용자 웨이포인트를 하나만 둔다 → 활성 표시는 한 번에 한 핀에만 켜진다.
- `FR#22` [as-built] TomTom 웨이포인트 토글

  ```
  Given TomTom 이 없다 (AddWaypoint·RemoveWaypoint 가 없음)
  Then  nil 과 "TomTom 없음" 메시지
  Given 이 핀의 TomTom 웨이포인트가 있다
  Then  지우고 "removed"
  Given 없다
  Then  핀 지도·좌표로 만든다 (제목 = 핀 제목, 미니맵 화살표 켬, TomTom 월드맵 아이콘 끔, from = LorePin) → "added"
  Given TomTom 이 웨이포인트를 만들지 못했다
  Then  nil 과 실패 메시지
  ```

- `FR#23` [as-built] 핀을 지우면 그 핀의 TomTom 웨이포인트도 지운다 (TomTom 이 없으면 기록만 지운다).
- `FR#24` [as-built] 상세 패널·목록 행의 [웨이포인트]·[TomTom] 버튼은 활성일 때 강조된다. TomTom 이 없으면 [TomTom] 은 비활성(반투명)이다.

## 6. 동작 로직 및 정책

### 6.n 설계 결정

| 결정 | 선택 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| `D#5` | TomTom 웨이포인트 UID 를 핀 ID 별로 메모리에만 둔다 | `LorePinDB` 에 저장 | TomTom 이 자기 웨이포인트를 저장하고, `/reload` 뒤 UID 는 무효가 된다 |
| `D#6` | TomTom 월드맵 아이콘을 끈다 | 켠다 | LorePin 핀·기본 웨이포인트와 겹쳐 같은 위치에 아이콘이 셋이 된다 |

## 7. 테스트 및 검증 기준

| TC | 시나리오 | 대상 | 비고 |
| --- | --- | --- | --- |
| `TC#26` | 기본 웨이포인트: 활성 판정(같은 지도·0.001 경계·다른 지도), 토글 added·removed, mapID·API 없음 → nil | [FR#21] | |
| `TC#27` | TomTom: 없음 → nil·메시지, added(옵션 값)·removed, 생성 실패 → nil | [FR#22] | |
| `TC#28` | 핀 삭제 시 TomTom 웨이포인트 제거, TomTom 없을 때 기록만 제거 | [FR#23] | |
| `TC#29` | 버튼 강조·TomTom 없을 때 비활성 | [FR#24] | (수동) 게임 내 |

## 부록. 변경 이력

- GH-12: as-built 스펙 작성
