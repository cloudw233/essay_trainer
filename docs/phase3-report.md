# 第三阶段 · 中文评分与系统分享

日期：2026-11-22

## 1. 完成范围

第三阶段补上原计划的两个高价值缺口：

1. **中文评分维度细化**：从“四个维度名称”升级为有明确满分和分数锚点的 50 分制。
2. **报告系统分享**：报告页可调起 Android 系统分享面板，分享完整文本摘要；
   原生通道不可用时回退到剪贴板。

没有引入新的 pub 依赖；分享通过 Android `MethodChannel` 实现，只传递文本。

## 2. 中文评分锚点

`lib/core/prompts/grading_prompts.dart` 的 `chineseGradingPrompt` 现在明确：

| 维度 | 满分 | 锚点摘要 |
|---|---:|---|
| 立意与内容 | 20 | 18–20 深刻切题；15–17 明确具体；12–14 基本切题；0–11 偏题/套作 |
| 结构与层次 | 15 | 13–15 完整推进；11–12 清楚略平；8–10 基本成立；0–7 残缺/堆砌 |
| 语言与表达 | 10 | 9–10 准确有变化；7–8 通顺；5–6 基本达意；0–4 表达不清 |
| 书写与规范 | 5 | 5 规范好；4 小错；3 影响阅读；0–2 问题明显 |

Prompt 同时要求：

- 不得改动维度名称或满分；
- 四个维度得分之和必须等于总分；
- 无法判断卷面时，只依据文本中的错别字、标点和格式，并在理由中说明。

### 真实中文 live check

`tool/live_chinese_grading_check.dart` 使用真实 DeepSeek Key 跑了一篇中文记叙文：

```text
41 / 50
立意与内容 17 / 20
结构与层次 12 / 15
语言与表达 8 / 10
书写与规范 4 / 5
逐句反馈 14 条
逐段反馈 1 条
耗时约 16 秒，第一次通过
```

维度名称、满分和总分关系均与 Prompt 锚点一致。这个检查只从
`DEEPSEEK_API_KEY` 环境变量读取 Key，不写入仓库、SQLite 或日志。

## 3. 报告摘要

新增纯 Dart 函数 `lib/core/utils/report_summary.dart`：

- 标题、总分/满分、语言/体裁/最低字数；
- 每个维度的名称、分数、满分和 comment；
- 每条逐句反馈的序号、严重度、问题类型、原句、comment、建议；
- 每段衔接、内容与建议；
- 全文升格。

报告页的“复制”和“分享”使用同一份摘要，避免两套文本漂移。

## 4. Android 系统分享

新增 `lib/services/system_share.dart`：

```text
MethodChannel('essay_trainer/share')
  → 'shareText' { text, subject? }
  → MainActivity ACTION_SEND + createChooser
```

- `MainActivity.kt` 实现 `MethodChannel`，使用 `Intent.ACTION_SEND`、
  `type=text/plain`，可带 `EXTRA_SUBJECT`。
- 报告页 AppBar 新增分享按钮；分享成功直接交给系统面板。
- 通道不可用、抛 `MissingPluginException` 或 `PlatformException` 时，服务
  返回 false，页面自动复制摘要并提示“系统分享不可用，报告摘要已复制。”
- 只分享文本，不发送 API Key、原始请求、数据库路径或图片。
- 未新增 `share_plus` 依赖，避免额外的 Android 构建面。

## 5. 测试

```text
flutter test --no-pub  →  +60: All tests passed!
flutter analyze        →  No issues found!
flutter build apk --release --target-platform android-x64
                       →  Built ... app-release.apk (20.3 MB)
```

新增覆盖：

- `test/core/prompt_builder_test.dart`：中文 20/15/10/5 锚点、维度名称/满分锁定；
- `test/core/report_summary_test.dart`：完整摘要、草稿删除后的标题兜底；
- `test/services/system_share_test.dart`：MethodChannel 参数、无通道返回 false；
- `test/features/report_page_test.dart`：分享按钮调用摘要通道；
- 原 55 项 Phase 2 测试保持通过。

## 6. 验收状态

| 标准 | 状态 |
|---|---|
| 中文四维满分与分数锚点 | 已实现；Prompt 测试通过 |
| 真实中文模型遵循锚点 | 已执行；41/50，17/20、12/15、8/10、4/5 |
| 报告复制摘要 | 已实现；摘要测试通过 |
| 系统分享调起 | 已实现；MethodChannel 测试通过 |
| 分享不可用兜底 | 已实现；返回 false 后复制 |
| Android APK 编译 | 已通过；20.3 MB release |
| 设备上实际 chooser 截图 | 未完成；模拟器 system_server ANR |

## 7. 剩余限制

1. 当前没有稳定设备/模拟器，未能实际点开 Android chooser 并截图。
2. 应用内真实 Key 点击链路仍未现场复验；服务层英文/中文真实批改和 UI 测试
   分别通过。
3. 深色模式/1.3x 大字号截图仍待稳定设备补拍。
