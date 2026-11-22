# essay_trainer UI layout diagnosis (2026-11-22)

Device: Android 16 API 36.1 emulator, 720x1600 px @ 320 dpi (360x800 dp), release x64 AOT.
States captured: light, dark, font scale 1.0/1.3, editor keyboard, prompt-sheet keyboard, empty home/history.
Not captured: AI grading loading/error and generated candidates (no DeepSeek key). Those two areas are code-reviewed and marked 待确认.

## P0
- P0-1 Editor bottom action bar covered by IME. editor_page.dart:291-325 (Scaffold.bottomNavigationBar), :471-568 (_EditorBottomBar). L3/L7. Fix: keyboard-aware bottom area; keep save/submit accessible above IME.
- P0-2 Prompt sheet field + generate button covered by IME. prompt_generation_sheet.dart:29-45 (fixed 92% height), :266-273 (insets padding), :379-397 (field/button). L3. Fix: shrink sheet with viewInsets, ensureVisible on focus, fixed footer.

## P1
- P1-1 Home has two equal hero CTAs and a full-screen settings card before recent drafts. home_page.dart:196-243, :305-390, :394-473. L4/L3.
- P1-2 Prompt-sheet primary action below fold. prompt_generation_sheet.dart:266-397. L3/L4.
- P1-3 Editor prompt card permanently occupies 132-300px above the body. editor_page.dart:366-374, :423-466. L3/L4/L7.
- P1-4 Empty states lack CTA (history dead end; home/presets only text). history_page.dart:172-199; home_page.dart:608-637; preset_library_page.dart:180-201. L5.
- P1-5 Editor "AI 批改" StatusPill looks tappable but is not. editor_page.dart:531-548. L4/L6.
- P1-6 Settings save-key is visually secondary to test-connection. settings_page.dart:486-503. L4/L6.
- P1-7 (待确认) Grading error/retry not bottom-anchored. grading_page.dart:188-260. L3/L5.

## P2
- P2-1 Global spacing: page padding 20 vs 16, card padding 18/20/22/24, gaps 6/10/14/18/22/26/28; 20+18 double inset in lists. L1.
- P2-2 Duplicate AppBar title + page headline on settings/history/presets/home. L4/L6.
- P2-3 Report sentence feedback Card vs paragraph AppSurface, gaps 8 vs 10. report_page.dart:479-620. L6/L1.
- P2-4 Loading states are bare centered spinners and jump. home:262-269; history:131-134; report:139-142; presets:141-144; grading:173-176. L5.
- P2-5 History swipe-delete vs presets icon-delete; history lacks pull-to-refresh. L6.
- P2-6 Report app bar share/copy IconButtons adjacent with no 8dp gap. report_page.dart:121-131. L2.
- P2-7 Preset cards too dense (4 pills + 3-line preview + 2-line rationale). preset_library_page.dart:226-309. L1/L4.

## Baseline screenshots
.tooling/ui-baseline/{home_light_top,home_light_scrolled,editor_light,editor_light_keyboard2,editor_light_130,editor_light_130_keyboard7,prompt_setup_light,prompt_setup_light_bottom,prompt_setup_light_keyboard2,settings_light_top,settings_dark_top,settings_light_key_section,settings_light_key_keyboard,history_light_130,history_empty,report_light_130_top,report_light_130_bottom,presets_light,home_empty_scrolled,home_light_130}.png
