# Obsidian Note Saver Project

## 목적
Obsidian Vault에 빠른 메모를 입력하고, Gemini 또는 Codex CLI를 사용해 적절한 폴더와 속성으로 저장하는 Windows 보조 도구입니다.

## 구성
- `ObsidianNoteSaver.ps1`: 메인 WPF 앱
- `ObsidianNoteSaver.cmd`: 메인 앱 실행기
- `InstallShortcuts.ps1`: 바탕화면과 시작 메뉴 바로가기 생성기
- `InstallShortcuts.cmd`: 바로가기 생성기 실행기
- `PinToTaskbar.cmd`: 작업표시줄 고정을 위해 시작 메뉴 바로가기를 선택해주는 도우미
- `classification.schema.json`: 원문 유지 모드 분류 스키마
- `refine.schema.json`: 내용 다듬기 모드 저장 스키마
- `Assets/`: 펭귄 아이콘 이미지와 `.ico`

## 실행 진입점
- 바탕화면: `Obsidian Note Saver`
- 단축키: `Ctrl + Alt + O`로 메인 앱 실행
- 작업표시줄: 시작 메뉴의 `Obsidian Note Saver` 바로가기를 고정

## 정리 원칙
프로젝트 파일은 이 폴더에 모으고, 실행 진입점은 바탕화면과 시작 메뉴 바로가기로만 연결합니다.
