# 第二阶段 · AI 批改链路验收报告

日期：2026-11-22

## 1. 完成范围

第二阶段把写作页从“本地草稿”接到完整批改链路：

```
写作页保存草稿
  → GradingPage（读取草稿 + API Key）
  → DeepSeek submit_grading_report 工具调用
  → 严格校验 / 失败重试一次
  → 写入 reports 表
  → ReportPage（题目上下文 + 评分 + 逐句/逐段 + 全文升格）
  → HistoryPage（时间倒序 + 左滑删除）
```

## 2. 批改调用

- 新文件 `lib/services/grading_service.dart`。
- 工具定义在 `lib/core/prompts/grading_tool.dart`：函数名
  `submit_grading_report`，必填字段为 `overallScore`、`maxScore`、
  `dimensionScores`、`sentenceFeedback`、`paragraphFeedback`、
  `revisedEssay`。
- 请求使用 `tools` + `tool_choice` 强制调用该函数，不设置 `strict`。
- 批改 system/user prompt 继续来自现有 `grading_prompts.dart` 与
  `PromptBuilder`；`PromptBuilder.userPrompt` 接收 `draft.promptText`，
  所以 AI 命题产生的题目会进入批改上下文。

### 关于 flutter_deepseek

`flutter_deepseek 0.1.1` 虽然定义了 `ToolCall`，但非流式响应模型
`ChatMessage` 没有 `toolCalls` 字段，响应解析会丢弃
`choices[0].message.tool_calls`。因此 `GradingService` 用同一套工具 schema
走 HTTP 适配层，自行解析 tool arguments；密钥、错误映射、重试与校验都在
服务层完成。出题/连接测试仍使用 `flutter_deepseek`。这是有意的兼容处理，
不是伪造 function calling。

## 3. 严格校验与重试

校验失败只重试一次，第二次请求追加：

> 上一次输出未通过结构校验。请重新调用 submit_grading_report，且 JSON
> 参数必须完全符合工具 schema，不要省略任何必填字段，不要输出解释或
> Markdown。

客户端校验包括：

- `overallScore` 在 0..请求满分之间；客户端强制写入请求的 `maxScore`，
  不信任模型自报满分；
- `dimensionScores` 非空，每项有非空名称、数值分数、正满分与 comment；
- `sentenceFeedback` 非空，`sentenceIndex` 非负整数，
  `issueType`/`severity` 必须命中枚举；
- `paragraphFeedback` 非空，段落号非负整数，三项文本非空；
- `revisedEssay` 非空；
- 若没有 tool call，会尝试解析 `message.content` 的 JSON（兼容忽略
  `tool_choice` 的网关），校验标准不变；
- 两次失败后抛出带 `rawResponse` 的中文错误，UI 可展开、复制原始响应。

## 4. 等待页

`lib/features/grading/grading_page.dart`：

- 自动读取草稿；没有 Key 时显示“去设置 API Key”。
- 显示四阶段指示：题干拆解、逐句精修、逐段诊断、全文评分与升格。
- 展示不定进度条、已等待时间、重试中的提示。
- 完成后自动保存报告并 `pushReplacement` 到报告页；失败可重新批改或返回编辑。

说明：这是**时间驱动的阶段指示**，不是逐 token 流式输出。批改结果以一次
工具调用返回结构化 JSON，当前服务没有把 SSE token 暴露到 UI；如果要真正
逐 token，需要另行接入流式工具调用增量解析。

## 5. 报告页

`lib/features/report/report_page.dart`：

- 顶部显示作文题快照（如果有），再显示标题、语言/体裁与时间。
- 总分卡：大号分数、满分、等级色块、进度条；等级使用
  `AppSemanticColors` 的 excellent/good/needsWork。
- 分维度评分卡：名称、分数/满分、进度条、comment。
- 逐句诊断：`ExpansionTile`，严重度圆点/标签 + 问题类型标签；展开显示
  comment 与 suggestion。critical/minor/suggestion/highlight 均走语义色。
- 逐段诊断：段落号、衔接 comment、内容 comment、建议。
- 全文升格：`SegmentedButton` 在原文与升格版之间切换，二者都是可选中文本。
- AppBar 可复制报告摘要（剪贴板），不引入额外依赖。
- 数据来自 `reports` 表；草稿被删除时报告仍可读，只是没有题目/原文。

## 6. 历史页

`lib/features/history/history_page.dart`：

- 读取 `ReportRepository.all()`，按 `created_at DESC`。
- 每张卡显示分数/满分、草稿标题、语言、维度数、逐句条数与时间。
- 点击进入报告页，返回后刷新。
- 左滑 `Dismissible`，背景使用 `errorContainer` + 删除图标；确认后删除
  SQLite 报告并更新列表。

## 7. 数据与题目关联

- `EssayDraft.promptText` / `promptPresetId` 已在第一阶段 AI 命题模块写入；
- `GradingService` 把 `draft.promptText` 放进 user prompt；
- 报告页通过 `report.draftId` 读取草稿并显示题目；
- `reports.draft_id` 外键指向草稿，数据库 schema v2。

## 8. 测试证据

```text
flutter test --no-pub  →  +55: All tests passed!
flutter analyze        →  No issues found!
flutter build apk --release --target-platform android-x64
                       →  Built ... app-release.apk (20.3 MB)
```

### 真实 DeepSeek Key 验证（2026-11-22）

- `GET /user/balance` 返回 200，`is_available=true`。
- `tool/live_grading_check.dart` 使用真实 Key 跑完整批改：
  - 第一次 tool 参数未通过严格校验，服务自动追加修正提示；
  - 第二次成功，耗时约 19 秒；
  - 得到 `17/25`，3 个维度（Content 6/10、Language 6/10、Structure 5/5），
    **10 条逐句反馈**、1 条逐段反馈、933 字符升格文；
  - 证明真实 DeepSeek 的 tool call 响应可被当前解析器和重试链路接住。
- `tool/live_prompt_check.dart` 使用真实 Key 连续生成两批英语议论文候选：
  - 两批各 3 道，均为第一次通过；
  - 两批标题交集为 0，`lastBatchWasSimilar=false`；
  - 说明“换一批 + 去重”在真实模型上生效。
- 两个 live check 都只从环境变量读取 Key，不把 Key 写入仓库、SQLite 或日志。

新增/扩展测试：

- `test/services/grading_service_test.dart`：工具调用请求体、中文 UTF-8 响应、
  满分注入、三次逐句反馈、字段/枚举校验、失败一次重试、两次失败保留原始
  响应、content JSON 兼容、401 中文错误。
- `test/features/report_page_test.dart`：题目、维度、三条逐句反馈、逐段反馈。
- `test/features/grading_flow_test.dart`：从 `GradingPage` 自动调用 MockClient、
  保存报告、替换路由到 `ReportPage`，并验证题目与三条反馈。
- `test/features/history_page_test.dart`：两份记录、分数/标题、左滑删除仓库调用。
- `test/features/editor_submit_test.dart`：未配置 Key 时保存草稿并提示去设置。
- `test/core/prompt_builder_test.dart`：题目上下文进入批改 user prompt。

## 9. 验收状态

| 标准 | 状态 |
| --- | --- |
| 英语作文提交后进入等待并显示阶段进度 | 已实现；MockClient 全流程测试通过 |
| 报告页展示分维度评分 | 已实现；widget test 通过 |
| 报告页至少 3 条逐句反馈 | 已实现；测试数据为 3 条，服务要求非空 |
| 逐句/逐段排版及严重度语义色 | 已实现；使用 ThemeExtension |
| 原文/升格版可对照 | 已实现；SegmentedButton |
| 历史页倒序与滑动删除 | 已实现；widget test 通过 |
| 题目与作文关联 | 已实现；批改 prompt 与报告页测试通过 |
| 真实 DeepSeek 成功批改 | 已执行：真实 Key、真实工具调用、第一次校验失败后重试成功；报告 17/25、3 维度、10 条逐句反馈 |
| 真实两批“换一批” | 已执行：两批各 3 道，标题交集 0，相似度未触发 |
| 应用内真实 Key 点击复验 | **未执行**：软件模拟器 system_server 持续 ANR；服务层真实调用与 UI 全流程（Mock）分别验证 |
| 第二阶段深色模式截图 | **未完成**：同上，缺现场截图 |

## 10. 剩余风险 / 下一步

1. 真实服务层已验证；若要验证“应用内点击 + 安全存储 + 真实网络”的完整链路，
   需要一台稳定设备或模拟器，并在设置页填入 Key 后跑一遍英语作文。
2. 启动稳定模拟器后补拍报告页/历史页浅色 + 深色 + 1.3x 大字号截图。
3. 若要求真正的逐 token 流式展示，需要把 `stream: true` 的 tool-call delta
   累积接入服务与等待页；当前实现是阶段指示，不冒充 token 流。
4. 第三阶段：中文维度细化、报告导出/系统分享、更多评分设置。
