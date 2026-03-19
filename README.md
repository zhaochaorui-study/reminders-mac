# Reminders Mac

一个基于 SwiftUI 的 macOS 菜单栏待办提醒应用。

## AI 配置

1. 运行 `./app.sh run`
2. 在设置页的“AI 解析”里二选一：
3. 开启“使用系统免费模型（DeepSeek）”，直接走默认 DeepSeek 配置
4. 或者复制 `.env.example` 为 `.env.local`，填写自定义 OpenAI 兼容配置 `LLM_API_KEY` / `LLM_API_URL` / `LLM_MODEL`

`.env.local` 已加入 Git 忽略，不会被提交。
