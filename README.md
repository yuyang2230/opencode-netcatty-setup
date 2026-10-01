# opencode + Netcatty Windows 集成指南 | opencode × Netcatty integration guide (Windows)

让 [Netcatty](https://github.com/binaricat/Netcatty)（AI-Powered SSH Workspace）的 Catty Agent 稳定调用 [opencode](https://opencode.ai) CLI（OpenCode Zen 免费模型），并修复 Windows 下的 5000ms 启动超时。

Make Netcatty's Catty Agent work with the opencode CLI (free Zen models) on Windows, and fix the `Timeout waiting for server to start after 5000ms` failure.

## 内容 | Contents

| 文件 | 说明 |
|---|---|
| [`manual_cn.md`](manual_cn.md) | 完整中文手册：opencode 安装、Zen 免费模型配置、Netcatty 集成、5000ms 超时补丁 |
| [`patch-netcatty-opencode-timeout.ps1`](patch-netcatty-opencode-timeout.ps1) | 超时补丁一键脚本（等长字节替换 app.asar，纯 ASCII，避开 PowerShell 5.1 编码坑） |

## 5000ms 超时一句话版 | The timeout fix in one paragraph

`@opencode-ai/sdk` 的 `createOpencodeServer` 硬编码默认 `timeout: 5000`，Windows 上 opencode server 冷启动实测 4.6~8.9 秒，于是 Netcatty 里报 `Timeout waiting for server to start after 5000ms`（TUI 下无死线所以正常）。官方 issue：[binaricat/Netcatty#3579](https://github.com/binaricat/Netcatty/issues/3579)。等官方修复前，用脚本对 `app.asar` 做等长替换（`port: 4096,` 锚点后的 `timeout: 5000,` → `timeout: 64e3,`，恰好命中 SDK 的 2 处，不碰 gh/wsl/ssh-add/icacls 的另外 6 处）。

⚠️ Netcatty 升级会覆盖 `app.asar`，复发需重跑脚本。

## 验证环境 | Tested with

Netcatty 1.1.83 · Windows 10/11 x64 · opencode-ai (npm) · @opencode-ai/sdk 1.18.34
