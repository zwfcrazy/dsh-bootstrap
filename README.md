# dsh-bootstrap

在全新机器上一键搭建 DeepSeek Harness（DSH）环境：装 DSH 本体、自建插件、dsh-config-manager，并从 Git 拉回你的配置。

支持 **Windows / Ubuntu·Debian / macOS** 三平台。

## 前置要求

- Node.js >= 22（脚本会自动检查/安装）
- Windows 10/11、Ubuntu/Debian 20.04+ 或 macOS
- 能访问 GitHub 的网络

## Windows

```powershell
git clone https://github.com/zwfcrazy/dsh-bootstrap.git
cd dsh-bootstrap
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

## Ubuntu / Debian

```bash
git clone https://github.com/zwfcrazy/dsh-bootstrap.git
cd dsh-bootstrap
bash setup.sh
```

## macOS

```bash
git clone https://github.com/zwfcrazy/dsh-bootstrap.git
cd dsh-bootstrap
bash setup-macos.sh
```

> 脚本最后会创建 **`~/Applications/DSH.app`** 启动器：双击即后台启动 DSH 并自动打开浏览器（无终端窗口），可拖到 Dock。运行日志在 `~/.dsh/dsh-web.log`。

> headless（无浏览器）服务器上，`gh auth login` 请选 token 或 device 流程（脚本里有提示）。

## 脚本做了哪些事

| 步骤 | Windows | Ubuntu | macOS |
|---|---|---|---|
| 装包管理器 | （winget 已内置） | apt | **Homebrew** |
| 装 Node 22+ | 检查提示 | NodeSource | `brew install node` |
| 装 pnpm | `npm install -g pnpm` | 同左（sudo 兜底） | 同左 |
| 装 GitHub CLI | `winget install GitHub.cli` | 官方 apt 源 | `brew install gh` |
| 装 DSH | `npm install -g @deepseek-ai/dsh@0.1.1-rc.2` | 同左 | 同左 |
| 装自建插件 | 由 config_sync_pull 拉回时自动重装（脚本不硬编码） | 同左 | 同左 |
| 装配置同步 | `dsh plugin --profile web add dsh-config-manager@0.1.54` | 同左 | 同左 |
| 写同步通道 | 生成 `~/.dsh/dsh-config-manager/sync/sync-config.json` | 同左 | 同左 |
| 写 token 凭据 | 写入 `~/.dsh/.credentials.yaml` | 同左 | 同左 |
| 登录 GitHub | `gh auth login` | 同左 | 同左 |
| 启动器 | — | — | **DSH.app** |

## 配置同步（跨机核心）

- 同步仓库：`https://github.com/zwfcrazy/dsh-config-sync`（**私有**）
- 通道配置：`~/.dsh/dsh-config-manager/sync/sync-config.json`
  ```json
  {
    "schemaVersion": 3,
    "transport": "git",
    "git": { "repoUrl": "https://github.com/zwfcrazy/dsh-config-sync" }
  }
  ```
- 认证 token：DSH 凭据 `DSH_CONFIG_MANAGER_SYNC_TOKEN`（存于 `~/.dsh/.credentials.yaml` 的 `refs` 下）
- **密钥永不进同步**：默认备份不含任何 apikey/token

## 拉回配置的两种方式

1. **GUI**：设置 → Backup & Migration → Sync → Pull。
2. **模型工具**：在 DSH 对话里说「拉取配置同步」，agent 会跑 `config_sync_pull`（零写入预览）→ 确认后导入。

## 注意事项

- 装插件/MCP 后需重启 DSH 生效。
- **自建插件代码由各自的 git 仓库承载**（`github:` spec 安装）；dsh-config-manager 只同步插件的「声明」（装哪个、什么版本），不搬运插件二进制。
- apikey 默认不随配置同步，换机后需重新填入（或在源机器做加密备份）。`n- 新增/更新自建插件后：在主机器 `config_sync_push` 即可，bootstrap 脚本不用改；新机器拉回时自动重装。
- 三个脚本都**不硬编码任何密钥**：token 是运行时从 `gh auth token` 取的。

## 相关仓库

- [dsh-skills-inventory](https://github.com/zwfcrazy/dsh-skills-inventory) — 自建插件示例
- [dsh-config-manager](https://github.com/xiajiajun516/dsh-config-manager) — 配置备份/迁移/同步（上游）