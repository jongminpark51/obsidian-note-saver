# Obsidian Note Saver

Obsidian Vault에 간단한 메모를 입력하면 Gemini 또는 Codex CLI를 통해 적절한 폴더와 속성으로 저장하는 Windows 앱입니다.

## 실행
바탕화면의 `Obsidian Note Saver` 바로가기를 실행하거나, 이 폴더의 `ObsidianNoteSaver.cmd`를 더블클릭합니다.

## 작업표시줄
- 시작 메뉴의 `Obsidian Note Saver` 바로가기를 작업표시줄에 고정할 수 있습니다.
- `PinToTaskbar.cmd`를 실행하면 고정할 바로가기 위치가 열립니다.
- Windows에서 자동 작업표시줄 고정이 제한될 수 있으므로, 열린 바로가기를 우클릭한 뒤 `작업 표시줄에 고정`을 선택합니다.

## 단축키
- 바탕화면 `Obsidian Note Saver` 바로가기에 `Ctrl + Alt + O` 단축키가 설정되어 있습니다.

## 저장 모드
- `내용 다듬기`: 선택한 AI 엔진이 내용을 정리하고 템플릿 구조에 맞춰 저장합니다.
- `원문 유지`: 선택한 AI 엔진은 분류 계획만 만들고, 프로그램은 원문을 그대로 둔 채 properties와 저장 위치만 적용합니다.

## AI 엔진
- `Gemini`: Gemini CLI를 사용합니다. 설치되어 있으면 기본 선택됩니다.
- `Codex`: Codex CLI를 사용합니다. Gemini가 없거나 직접 선택한 경우 사용합니다.

## 버튼
- `저장하기`: 선택한 저장 모드로 문서를 생성합니다.
- `Inbox에 바로 저장`: AI를 호출하지 않고 `00 Inbox/`에 빠른 메모 형식으로 저장합니다.
- `크게 보기`: 입력 내용을 별도 창에서 확인하고 편집합니다.
- `Obsidian에서 열기`: 마지막으로 생성된 문서를 Obsidian URI로 엽니다.
- `경로 복사`: 완료된 파일 경로를 클립보드에 복사합니다.

## 입력 영역
- 기본 창 높이를 키웠고, 내용 입력칸에는 세로 스크롤이 항상 표시됩니다.
- 내용 입력칸 위에 글자 수와 줄 수를 표시합니다.
- 긴 메모는 `크게 보기`에서 넓은 편집창으로 확인할 수 있습니다.

## 진행 표시
- `저장하기`를 누르면 진행바와 현재 단계 문구가 표시됩니다.
- Gemini/Codex 응답이 JSON이 아닐 경우 원본 응답은 `.tmp` 폴더에 저장됩니다.
- 마지막 오류는 `.tmp/last-error.txt`에서 확인할 수 있습니다.

## 아이콘
- 앱 아이콘은 `Assets/obsidian-note-saver-penguin.png`와 `Assets/obsidian-note-saver-penguin.ico`를 사용합니다.
- 아이콘은 펭귄 마스코트와 문서 체크 표시를 조합한 이미지입니다.

## 저장 기준
- 성격이 명확하면 `10 Projects`, `20 Areas`, `30 Resources` 중 적합한 위치에 저장합니다.
- 성격이 불명확하면 `00 Inbox`에 저장합니다.
- 기존 파일은 덮어쓰지 않는 것을 기본 규칙으로 합니다.

## 점검
터미널에서 아래 명령으로 기본 경로, 아이콘, JSON 스키마, CLI 인식 여부를 확인할 수 있습니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\ObsidianNoteSaver.ps1" -SelfTest
```

UI만 로딩되는지 확인하려면 다음 명령을 사용합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File ".\ObsidianNoteSaver.ps1" -UiSelfTest
```

바탕화면과 시작 메뉴 바로가기를 다시 만들려면 다음 명령을 사용합니다.

```powershell
.\InstallShortcuts.cmd
```
