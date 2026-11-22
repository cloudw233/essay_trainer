# Security Policy

## 支持范围

当前维护 `0.4.x`。更早版本只做安全修复评估。

## API Key 安全

- 应用不包含硬编码 DeepSeek Key，也没有代理后端。
- 用户 Key 只写入 Android 安全存储；不会进入 SQLite、日志或源码。
- `tool/live_*.dart` 只从 `DEEPSEEK_API_KEY` 环境变量读取 Key。
- 不要在任何 issue、PR、CI 日志或截图中粘贴真实 Key。
- 如果 Key 曾出现在公开位置，请立即在 DeepSeek 控制台轮换/吊销。

## 报告漏洞

请通过仓库的 **Security → Report a vulnerability** 私下报告，不要先公开
issue。请描述影响范围、复现步骤和受影响版本；不要在报告中包含真实用户
Key、作文内容或其他敏感数据。
