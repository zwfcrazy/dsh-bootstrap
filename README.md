# dsh-bootstrap

在全新机器上一键搭建 DeepSeek Harness（DSH）环境：装 DSH 本体、自建插件、dsh-config-manager，并从 Git 拉回你的配置。

## 前置要求

- Node.js >= 22（脚本会自动检查）
- Windows 10/11（脚本用 PowerShell）
- 能访问 GitHub 的网络

## 一键搭建

```powershell
# ① 拉取本仓库
git clone https://github.com/zwfcrazy/dsh-bootstrap.git
cd dsh-bootstrap

# ② 运行脚本（ExecutionPolicy Bypass 免去右键解锁）
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

脚本会依次：检查 Node → 装 pnpm → 装 GitHub CLI → 装 DSH launcher → 装自建插件 + dsh-config-manager → 写同步通道配置 → 引导你 `gh auth login` 并拉回配置。

## 脚本对应的手动步骤（对照表）

| 步骤 | 命令 |
|---|---|
| 装 pnpm | `npm install -g pnpm` |
| 装 GitHub CLI | `winget install --id GitHub.cli -e` |
| 装 DSH launcher | `npm install -g @deepseek-ai/dsh@0.1.1-rc.2` |
| 装自建插件 | `dsh plugin --profile web add github:zwfcrazy/dsh-skills-inventory` |
| 装配置同步 | `dsh plugin --profile web add dsh-config-manager@0.1.54` |
| 写同步通道配置 | 生成 `~/.dsh/dsh-config-manager/sync/sync-config.json` |
| 登录 GitHub | `gh auth login`（浏览器授权） |
| 拉回配置 | GUI 或让 agent 跑 `config_sync_pull` |

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
- apikey 默认不随配置同步，换机后需重新填入（或在源机器做加密备份）。

## 相关仓库

- [dsh-skills-inventory](https://github.com/zwfcrazy/dsh-skills-inventory) — 自建插件示例
- [dsh-config-manager](https://github.com/xiajiajun516/dsh-config-manager) — 配置备份/迁移/同步（上游）