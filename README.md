# X86MV

MSX2 이상(turbo R 포함)의 MSX-DOS2 / Nextor에서 돌아가는 **MV(뮤직비디오) 동영상 플레이어**입니다.
동영상 파일을 [X86MVCONV](https://github.com/taewoo725-maker/x86mvconv)로 MV2 / MV5 / MV8 / MVC로 바꿔 재생합니다.
[X86MSX](https://github.com/taewoo725-maker/x86msx)와 X86 멀티미디어 카트리지에서도 동작합니다.

- 만든이: KimTaeWoo / 도와준이: Lee.J.H
- 버전: V1.11.41
- 라이선스: GPL v3 (`LICENSE`)

## 구성
| 파일 | 하는 일 |
|---|---|
| `X86MV.ASM` | 본체 (`X86MV.COM`) |
| `vc.asm`, `vk.asm` | X86 비디오 클라이언트 모듈 |
| `m8.asm` + `m8*.inc` | 형식별 재생 모듈 (`X86MV8.OVL`, `X86MVA.OVL` 등) |
| `s6/` | SCREEN 6 목록 화면 모듈 (`X86MVUI.OVL`, `X86MVST.OVL`), 한글 글꼴 |
| `browser.inc`, `ui.inc` 등 | 파일 목록·화면 공용 조각 |
| `build.py` | 전체 빌드 |

## 빌드
[pasmo](https://pasmo.speccy.org/)가 필요합니다.

    python3 build.py

결과로 `X86MV.COM`과 `.OVL` 파일들이 생깁니다. 모두 같은 폴더에 두고 실행합니다.
(결과물은 저장소에 넣지 않았습니다. 이 소스로 다시 빌드한 `X86MV.COM`과 `.OVL`은 V1.11.41 배포본과 바이트 단위로 같습니다.)
