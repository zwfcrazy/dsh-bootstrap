#!/usr/bin/env bash
# DSH 新机器一键搭建脚本（macOS）
# 用法: bash setup-macos.sh
set -euo pipefail

DSH_VERSION="0.1.1-rc.2"
CM_VERSION="0.1.54"
GITHUB_USER="zwfcrazy"
PLUGIN_REPO="dsh-skills-inventory"
SYNC_REPO_URL="https://github.com/zwfcrazy/dsh-config-sync"
SYNC_TOKEN_REF="DSH_CONFIG_MANAGER_SYNC_TOKEN"
DSH_URL="http://127.0.0.1:3080/"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "\n${CYAN}=== $1 ===${NC}"; }
ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
info() { echo -e "      $1"; }
die()  { echo -e "  ${RED}[X]${NC} $1"; exit 1; }

# npm 全局安装：前缀不可写时自动 sudo
npmg() {
  local p
  p="$(npm config get prefix 2>/dev/null || echo /usr/local)"
  if [ -w "$p" ] || [ -w "$p/lib" ]; then
    npm install -g "$@"
  else
    sudo npm install -g "$@"
  fi
}

# 创建 DSH.app 启动器（双击启动 DSH + 自动开浏览器，无终端窗口）
create_launcher_app() {
  local appdir="$HOME/Applications/DSH.app"
  local bin="$appdir/Contents/MacOS"
  mkdir -p "$bin" "$appdir/Contents/Resources"

  cat > "$bin/launch.sh" <<'EOF'
#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
URL="http://127.0.0.1:3080/"
LOG="$HOME/.dsh/dsh-web.log"

# 已在运行 → 只打开浏览器
if curl -fsS --max-time 2 "$URL" >/dev/null 2>&1; then
  open "$URL"
  exit 0
fi

# 后台启动 DSH（nohup 脱离终端），轮询等它就绪再开浏览器
nohup dsh web > "$LOG" 2>&1 &
for i in $(seq 1 30); do
  sleep 1
  if curl -fsS --max-time 2 "$URL" >/dev/null 2>&1; then
    open "$URL"
    exit 0
  fi
done

# 30 秒还没起来：用 TextEdit 打开日志排查
open -e "$LOG" 2>/dev/null || true
exit 0
EOF
  chmod +x "$bin/launch.sh"

  cat > "$appdir/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>DSH</string>
  <key>CFBundleDisplayName</key><string>DSH</string>
  <key>CFBundleIdentifier</key><string>com.zwfcrazy.dsh</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleExecutable</key><string>launch.sh</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
</dict>
</plist>
EOF
}

# 0. Homebrew
step "检查/安装 Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    info "安装 Homebrew（会要求输入密码）..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      grep -q 'homebrew/bin/brew shellenv' "$HOME/.zprofile" 2>/dev/null \
        || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi
ok "brew $(brew --version | head -1)"

# 1. Node.js 22+
step "检查/安装 Node.js"
if ! command -v node >/dev/null 2>&1; then
  brew install node
fi
ok "Node $(node --version)"

# 2. pnpm
step "安装 pnpm"
if ! command -v pnpm >/dev/null 2>&1; then
  npmg pnpm
fi
ok "pnpm $(pnpm --version)"

# 3. GitHub CLI
step "安装 GitHub CLI"
if ! command -v gh >/dev/null 2>&1; then
  brew install gh
fi
ok "gh 已就绪"

# 4. DSH launcher
step "安装 DSH launcher"
npmg "@deepseek-ai/dsh@${DSH_VERSION}"
ok "dsh 已安装"

# 5. 插件
step "安装插件"
dsh plugin --profile web add "github:${GITHUB_USER}/${PLUGIN_REPO}"
dsh plugin --profile web add "dsh-config-manager@${CM_VERSION}"
ok "插件已安装"

# 6. GitHub 登录
step "登录 GitHub（浏览器授权）"
gh auth login
token="$(gh auth token 2>/dev/null | tr -d '\r\n')"
[ -n "$token" ] || die "gh auth token 失败"
ok "已登录 ${GITHUB_USER}"

# 7. 写同步通道配置
step "写同步通道配置"
SYNC_DIR="$HOME/.dsh/dsh-config-manager/sync"
mkdir -p "$SYNC_DIR"
cat > "$SYNC_DIR/sync-config.json" <<EOF
{
  "schemaVersion": 3,
  "transport": "git",
  "git": { "repoUrl": "${SYNC_REPO_URL}" }
}
EOF
ok "sync-config.json 已写"

# 8. 写同步 token 到 DSH 凭据（BSD sed 语法）
step "写同步 token 到 DSH 凭据"
CRED="$HOME/.dsh/.credentials.yaml"
if [ ! -f "$CRED" ]; then
  printf 'version: 1\nrefs:\n' > "$CRED"
fi
if grep -qE "^[[:space:]]*${SYNC_TOKEN_REF}[[:space:]]*:" "$CRED"; then
  sed -i '' -E "s|^[[:space:]]*${SYNC_TOKEN_REF}[[:space:]]*:.*|  ${SYNC_TOKEN_REF}: ${token}|" "$CRED"
  info "已更新现有凭据 ${SYNC_TOKEN_REF}"
else
  printf '  %s: %s\n' "${SYNC_TOKEN_REF}" "${token}" >> "$CRED"
  info "已新增凭据 ${SYNC_TOKEN_REF}"
fi
ok "token 已写入 ${CRED}"

# 9. 创建 DSH.app 启动器
step "创建 DSH.app 启动器"
create_launcher_app
ok "已创建 ~/Applications/DSH.app（可拖到 Dock）"
info "双击 DSH.app 即可后台启动 DSH 并自动打开浏览器；日志在 ~/.dsh/dsh-web.log"

# 10. 完成
step "完成"
echo "接下来："
echo "  1. 双击 ~/Applications/DSH.app 启动 DSH"
echo "  2. 在 DSH 对话里说「拉取配置同步」，agent 会跑 config_sync_pull 预览 → 确认导入"
echo ""
echo "全部完成！设置 / 插件声明 / MCP / 技能 / 工作区 会从 Git 拉回。"