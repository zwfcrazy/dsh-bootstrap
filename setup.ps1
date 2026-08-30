# DSH 新机器一键搭建脚本
# 用法: powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = "Stop"

$DSH_VERSION     = "0.1.1-rc.2"
$CM_VERSION      = "0.1.54"
$GITHUB_USER     = "zwfcrazy"
$SYNC_REPO_URL   = "https://github.com/zwfcrazy/dsh-config-sync"
$SYNC_TOKEN_REF  = "DSH_CONFIG_MANAGER_SYNC_TOKEN"

function Step($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Info($m) { Write-Host "      $m" }
function Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "  [X] $m" -ForegroundColor Red; exit 1 }

# 0. 预检 GitHub 连通性
Step "预检 GitHub 连通性"
try {
  $null = Invoke-WebRequest -Uri "https://github.com" -Method Head -TimeoutSec 8 -UseBasicParsing
  Ok "github.com 可达"
} catch {
  Warn "无法连接 github.com:443，github: 源插件安装会失败"
  Info "若有代理：git config --global http.proxy http://127.0.0.1:<端口>"
  Info "或用 SSH：git config --global url.'git@github.com:'.insteadOf 'https://github.com/'"
}

# 1. Node
Step "检查 Node.js"
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Die "未找到 Node.js，请先装 https://nodejs.org/ (>=22)" }
Ok ("Node " + (node --version))

# 2. pnpm
Step "安装 pnpm"
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) { npm install -g pnpm }
Ok ("pnpm " + (pnpm --version))

# 3. GitHub CLI
Step "安装 GitHub CLI"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { winget install --id GitHub.cli -e }
Ok "gh 已就绪"

# 4. DSH launcher
Step "安装 DSH launcher"
npm install -g "@deepseek-ai/dsh@$DSH_VERSION"
Ok "dsh 已安装"

# 5. 配置同步插件（只装这一个；其它自建插件由 config_sync_pull 拉回时自动重装）
Step "安装配置同步插件"
dsh plugin --profile web add "dsh-config-manager@$CM_VERSION"
if ($LASTEXITCODE -ne 0) { Die "dsh-config-manager 安装失败（退出码 $LASTEXITCODE）" }
Ok "dsh-config-manager 已安装"

# 6. GitHub 登录
Step "登录 GitHub（浏览器授权，用于配置同步）"
gh auth login
$token = (gh auth token 2>&1 | Out-String).Trim()
if (-not $token) { Die "gh auth token 失败" }
Ok "已登录 $GITHUB_USER"

# 7. 写同步通道配置
Step "写同步通道配置"
$syncDir = Join-Path $env:USERPROFILE ".dsh\dsh-config-manager\sync"
New-Item -ItemType Directory -Force -Path $syncDir | Out-Null
$syncCfg = @{ schemaVersion = 3; transport = "git"; git = @{ repoUrl = $SYNC_REPO_URL } } | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $syncDir "sync-config.json"), $syncCfg, (New-Object System.Text.UTF8Encoding($false)))
Ok "sync-config.json 已写"

# 8. 写同步 token 到 DSH 凭据
Step "写同步 token 到 DSH 凭据"
$credFile = Join-Path $env:USERPROFILE ".dsh\.credentials.yaml"
if (Test-Path $credFile) {
    $lines = [System.IO.File]::ReadAllLines($credFile)
} else {
    $lines = @("version: 1", "refs:")
}
$found = $false
$out = New-Object System.Collections.Generic.List[string]
foreach ($l in $lines) {
    if ($l -match ("^\s*" + [regex]::Escape($SYNC_TOKEN_REF) + "\s*:")) {
        $out.Add("  " + $SYNC_TOKEN_REF + ": " + $token)
        $found = $true
    } else {
        $out.Add($l)
    }
}
if (-not $found) {
    $out.Add("  " + $SYNC_TOKEN_REF + ": " + $token)
}
$content = ($out -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText($credFile, $content, (New-Object System.Text.UTF8Encoding($false)))
Ok "token 已写入 $credFile"

# 9. 完成
Step "完成"
Write-Host "接下来："
Write-Host "  1. 启动 DSH：dsh web"
Write-Host "  2. 在 DSH 对话里说「拉取配置同步」，agent 会跑 config_sync_pull 预览 → 确认导入"
Write-Host "     （导入时 dsh-config-manager 会自动重装你的自建插件）"
Write-Host ""
Write-Host "全部完成！设置 / 插件 / MCP / 技能 / 工作区 会从 Git 拉回。"