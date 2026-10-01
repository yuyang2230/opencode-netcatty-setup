# opencode 安装 + Netcatty 集成配置手册（Windows）

> 来源：2026-10-01 完整实践（Windows）。适用于其他 Windows 机器复现。
> 配套脚本：[patch-netcatty-opencode-timeout.ps1](patch-netcatty-opencode-timeout.ps1)（超时补丁一键版，纯 ASCII 避开 PowerShell 5.1 编码坑）。

## 1. 安装 opencode CLI

前置：Node.js（本机用 v24）。

```cmd
npm install -g opencode-ai
opencode --version
```

- 装完真实可执行文件在：`%APPDATA%\npm\node_modules\opencode-ai\bin\opencode.exe`
- cmd 里敲的 `opencode` 只是 `.cmd` 转发脚本（node wrapper），GUI 程序集成时要认 exe

## 2. 配置 Zen（免费模型）

1. 到 https://opencode.ai/auth 注册/登录，拿到 API key（`oc_sk_...` 格式）
2. 写入凭据文件 `%USERPROFILE%\.local\share\opencode\auth.json`：

```json
{
  "opencode": {
    "type": "api",
    "key": "oc_sk_你的key"
  }
}
```

（等价方式：运行 `opencode auth login` → 选 opencode → 粘贴 key）

3. 全局配置 `%USERPROFILE%\.config\opencode\opencode.jsonc`：

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/big-pickle",                    // 默认，免费
  "small_model": "opencode/mimo-v2.6-flash-free",    // 起标题/摘要等轻量任务，免费
  "autoshare": false,
  "mcp": {
    "netcatty-external": {
      "type": "local",
      "command": [
        "node",
        "C:\\Program Files\\Netcatty\\resources\\app.asar.unpacked\\electron\\mcp\\netcatty-external-mcp-server.cjs"
      ],
      "environment": {
        "NETCATTY_EXTERNAL_MCP_DISCOVERY_FILE": "C:\\Users\\adminwh\\AppData\\Roaming\\netcatty\\external-mcp\\discovery.json"
      },
      "enabled": true
    }
  }
}
```

4. 验证：`opencode run -m opencode/big-pickle "hi"` 应正常返回。

### Zen 当前免费模型清单（限时活动，会轮换，以官方为准）

```
opencode/big-pickle
opencode/space-bunny-free
opencode/longcat-2.5-preview-free
opencode/mimo-v2.6-flash-free
opencode/ling-3.0-flash-fin-free
opencode/nemotron-3-ultra-free
opencode/nemotron-3.5-lightning-free
opencode/muse-spark-1.3-contributor-free
```

命名规则：永远是 `opencode/模型ID`（opencode 是 Zen 网关供应商名，不能省）；免费与否看模型 ID 是否带 `-free` 后缀或查 https://opencode.ai/docs/zen/ 。

## 3. Netcatty 集成

### 3.1 设置环境变量（让 Netcatty 直接找到 exe）

```cmd
setx OPENCODE_BIN "%USERPROFILE%\AppData\Roaming\npm\node_modules\opencode-ai\bin\opencode.exe"
```

然后**彻底重启 Netcatty**（GUI 应用启动时快照 PATH/环境变量）。

### 3.2 外部 MCP（opencode ↔ Netcatty 工具互通）

- Netcatty 设置 → AI → 开启 External MCP，且 Netcatty 保持运行
- discovery 文件（Netcatty 自动刷新端口/token）：`%APPDATA%\netcatty\external-mcp\discovery.json`
- opencode 侧配置已写在上面 jsonc 的 `mcp` 段（用 node 直跑 .cjs，比 .cmd 稳）

## 4. 重要：Netcatty 的 5000ms 超时补丁（必做）

**问题**：Netcatty 内嵌 opencode SDK 的 `createOpencodeServer` 硬编码 `timeout: 5000`，而 Windows 上 opencode server 启动实测 4.6~8.9 秒 → 报
`Timeout waiting for server to start after 5000ms`（cmd 下 TUI 没有死线所以正常）。

**根因（已核实，2026-10-01）**：`@opencode-ai/sdk` 的 `createOpencodeServer` 在 `dist/server.js` 和 `dist/v2/server.js` 里默认值写死 `port: 4096, timeout: 5000`；Netcatty 主聊天路径（`electron/bridges/aiBridge/sdk/opencodeDriver.cjs` 的 `runOpenCodeTurn`）调 `withOpenCodeServerPort({ config, signal })` 时没有透传 `timeout`，落到 SDK 默认 5000ms（连接池路径传了 10000ms 也偏紧）。已提交官方 issue：[binaricat/Netcatty#3578](https://github.com/binaricat/Netcatty/issues/3578)。等官方修复前用下面的补丁，或直接跑仓库里的 [`patch-netcatty-opencode-timeout.ps1`](patch-netcatty-opencode-timeout.ps1)。

**修复**：等长替换 app.asar 中两处（仅限 `port: 4096,` 开头的上下文）：

```
timeout: 5000,   →   timeout: 64e3,    （64 秒，字节等长不破坏 asar）
```

⚠️ app.asar 里 `timeout: 5000` 有 8 处，另外 6 处属于 gh/wsl/ssh-add/icacls 等功能，**不能动**，必须按 `port: 4096` 锚点精确匹配。

**补丁脚本**（管理员 PowerShell 运行；先关闭 Netcatty）：

```powershell
$asar = 'C:\Program Files\Netcatty\resources\app.asar'
$bak  = 'C:\Program Files\Netcatty\resources\app.asar.bak-timeout5000'
Copy-Item $asar $bak
$enc = [Text.Encoding]::GetEncoding(28591)
$s = [IO.File]::ReadAllText($asar, $enc)
$n = [regex]::Matches($s, '(port: 4096,(\s+)timeout: )5000,').Count
$s = [regex]::Replace($s, '(port: 4096,(\s+)timeout: )5000,', '${1}64e3,')
[IO.File]::WriteAllText($asar, $s, $enc)
"Patched $n place(s). Backup: $bak"
```

补丁后重开 Netcatty 验证 agent 调 opencode 不再超时。

注意：
- Netcatty 升级会覆盖 app.asar，届时如复发需重打补丁
- .ps1 保存为 UTF-8 无 BOM 会被 PowerShell 5.1 按 GBK 解析中文出语法错误——脚本内容保持纯 ASCII，或双击 .bat 启动器

## 5. 验证清单

1. `opencode --version` ✓
2. `opencode run -m opencode/big-pickle "hi"` 返回 ✓（Zen key + 免费模型通）
3. `opencode auth list` 显示 OpenCode Zen api ✓
4. Netcatty agent 调 opencode 不报 Timeout ✓
5. opencode TUI 里能看到 netcatty-external 的 MCP 工具（需 Netcatty 在运行）✓
