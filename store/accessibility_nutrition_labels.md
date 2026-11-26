# Accessibility Nutrition Labels — Moss & Otto (摸索台灯)

> Reference declaration for App Store Connect Accessibility Nutrition Labels and AX1–AX5 / VoiceOver engineering verification.
> Bilingual summary (zh-Hans / English), strictly factual against the current iOS 26 codebase.

---

## Declared App Store Capabilities (声明支持的无障碍能力)

| Capability | Status | Concrete In-App Evidence |
| --- | --- | --- |
| **VoiceOver** | Supported (全站核心流程完整支持) | Semantic labels, traits, and values across all 4 tabs (`摸索 / 台灯 / 留念 / 工坊`), Bedside Lamp dimmer (`accessibilityAdjustableAction`), Passing Lantern slider (`accessibilityAdjustableAction`), Observation 3-state selector cards, Baby Voice waveform stickers, and Storybook spreads. |
| **Larger Text (Dynamic Type AX1–AX5)** | Supported (全站支持到 AX5 最大辅助字号) | Relative text styles + `Typeface.numerals(_:relativeTo:)` + `type.isAccessibilitySize` vertical stacking and `ViewThatFits` layouts in `TodayView`, `LampHubView`, `JourneyHubView`, `EvidenceViews`, `Firsts`, `StorybookView`, `YouView`, plus multi-line wrapping with zero horizontal scrolling (`0 ScrollView(.horizontal)`). |
| **Voice Control (语音控制)** | Supported | Standard SwiftUI button labels and `accessibilityLabel` controls on every tap target (`>= 44x44 pt` across midnight sanctuary, toolbar controls, voice pill, and storybook navigation). |
| **Dark Interface (深色界面与纯黑 3AM 夜灯)** | Supported | Automatic Dark Mode (`ThemeMode.dark` / `.system`) + 19:00–06:00 Lamplight + 00:00–04:59 zero-glare 3AM OLED mode reducing screen luminance without harsh blue spikes. |
| **Differentiate Without Color Alone (不单靠颜色区分)** | Supported | State chips pair iconography (`checkmark.circle`, `clock.badge`, `stethoscope`, `waveform`, `photo.fill`, `circle.bottomhalf.filled`) and explicit text badges alongside Crayon tints. |
| **Sufficient Contrast (足够对比度)** | Supported | Adaptive `Crayon.ink(...)` foreground inks, high-contrast candle/amber text on `#050507` OLED surfaces, and automated contrast checks via `AccessibilityAuditTests`. |
| **Reduced Motion (减弱动态效果)** | Supported | `@Environment(\.accessibilityReduceMotion)` honored across Bedside Lamp glow, Rainstick particles, Polaroid tilt, Storybook spread springs, and Bead Journey transitions. |
| **Offline Speech Read-Aloud & Grandparent Web Card Large Print** | Supported | Built-in offline `AVSpeechSynthesizer` (`SpeechReader`) on L1–L3 Evidence cards + Web `card.html` Large Print Elder Mode toggle & browser speech synthesis. |

---

## 中文 App Store 无障碍标签填报参考

- **旁白（VoiceOver）**：完整支持 4 大核心板块、床头灯无级调光（滑竿可调节手势）、传灯交接金珠（可调节手势）、三态观察勾选与童言声音贴纸播放。
- **更大字体（动态字体 AX3–AX5）**：支持从标准字号平滑放大至辅助特大号（AX5），在大字号下自动将横向卡片排布切换为纵向流式布局，不裁切、不出现横向滚动条。
- **语音控制 / 深色外观 / 不单靠颜色区分 / 减弱动态效果 / 足够对比度**：均已适配并纳入 UI 自动化无障碍审计（`AccessibilityAuditTests`: Default / Lamplight Dark / AX3 / AX5）。
