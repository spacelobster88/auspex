# mac-bootstrap

从全新 Mac Mini 一键部署 AI 服务栈。

## ⚠️ 免责声明

**本脚本会安装系统级软件、修改 LaunchAgents 配置、写入 HOME 目录文件。**

使用本脚本可能带来的风险包括但不限于：
- 系统配置被修改
- 与现有软件产生冲突
- 服务异常导致资源占用过高
- 密钥/令牌配置不当导致的安全问题

**使用本脚本造成的任何系统损坏、数据丢失、服务中断、安全事故等问题，由用户自行承担全部责任，与开发者无关。**

请在运行前仔细阅读每个脚本的内容，确认你理解每一步操作。

---

## 硬件要求

| 项目 | 最低要求 | 推荐 |
|------|---------|------|
| 芯片 | Apple Silicon (M1+) | M2 / M4 |
| 内存 | 16 GB | 16 GB+（Claude CLI 单进程峰值可达 6-10 GB） |
| 磁盘 | 30 GB 可用 | 100 GB+（含 Ollama 模型、brew 包、项目代码） |
| macOS | 14.0 (Sonoma)+ | 最新版本 |

## 服务架构

```
Ollama (port 11434)           ← 向量嵌入服务
  └──▶ mini-claude-bot (port 8000)  ← 网关 + cron + memory
         └──▶ telegram-claude-hero   ← Telegram 入口
centurion (port 8100)          ← Agent 编排引擎（独立）
```

| 服务 | 技术栈 | 端口 | 说明 |
|------|--------|------|------|
| Ollama | Homebrew | 11434 | nomic-embed-text 模型，为 mini-claude-bot 提供向量嵌入 |
| mini-claude-bot | Python 3.13 / FastAPI | 8000 | 多会话 Claude 网关、Cron 调度、语义记忆、日报生成 |
| telegram-claude-hero | Go 1.25 | - | Telegram Bot 桥接，转发消息到 mini-claude-bot |
| centurion | Python 3.12+ / FastAPI | 8100 | AI Agent 编排引擎，管理多个 Claude CLI 进程 |

## 使用方法

### Phase 0: 手动前置步骤

这些步骤无法自动化，需要在运行脚本前手动完成：

1. **macOS 权限设置**（系统设置 → 隐私与安全性）：
   - 给 Terminal.app 或 iTerm2 授权：**辅助功能 (Accessibility)**
   - 给 Terminal.app 或 iTerm2 授权：**完全磁盘访问权限 (Full Disk Access)**
   - 给 Terminal.app 或 iTerm2 授权：**自动化 (Automation)**

2. **准备好以下信息**：
   - GitHub 账号（用于克隆 private repo）
   - Telegram Bot Token（从 [@BotFather](https://t.me/BotFather) 获取）
   - Anthropic 账号（用于 Claude CLI 登录）

### Phase 1: 安装系统依赖

```bash
git clone https://github.com/spacelobster88/mac-bootstrap.git
cd mac-bootstrap
chmod +x *.sh
./install.sh
```

这会安装：Homebrew、Python、Go、Node.js、Ollama、Claude CLI、tectonic (LaTeX)、GitHub CLI。

### Phase 2: 克隆项目 + 配置 + 启动服务

```bash
# 先完成 GitHub 和 Claude 登录
gh auth login
claude login

# 然后运行
./setup.sh
```

脚本会交互式引导你：
- 克隆 3 个项目 repo
- 构建各项目（Python venv、Go build）
- 输入 Telegram Bot Token 等 secrets
- 安装并启动 4 个 LaunchAgent 服务

### Phase 3: 验证

```bash
./health-check.sh
```

验证所有服务是否正常运行。

### 卸载

```bash
./uninstall.sh
```

停止所有服务并移除 LaunchAgent 配置。

## 目录结构

```
mac-bootstrap/
├── README.md                 # 本文档
├── LICENSE                   # MIT
├── install.sh                # 系统依赖安装
├── setup.sh                  # 项目配置与服务启动
├── health-check.sh           # 服务健康检查
├── uninstall.sh              # 服务卸载
├── Brewfile                  # Homebrew 依赖清单
├── launchd/                  # LaunchAgent plist 模板
│   ├── com.eddie.ollama.plist.template
│   ├── com.eddie.mini-claude-bot.plist.template
│   ├── com.eddie.telegram-claude-hero.plist.template
│   └── com.eddie.centurion.plist.template
└── env/                      # 环境变量模板
    ├── mini-claude-bot.env.example
    └── centurion.env.example
```

## 手动步骤清单

以下操作需要浏览器交互或手动配置，脚本会在适当时候提示：

| 步骤 | 命令 / 操作 | 说明 |
|------|------------|------|
| GitHub 登录 | `gh auth login` | 克隆 private repo 需要 |
| Claude 登录 | `claude login` | 需 Anthropic 账号，浏览器交互 |
| macOS 权限 | 系统设置 → 隐私与安全性 | Terminal/iTerm2 需要 Accessibility + Full Disk Access + Automation |
| Telegram Token | @BotFather | setup.sh 会提示输入 |
| Gmail App Password | Google 账号设置 | 仅在需要 daily report 邮件时 |

## 数据迁移（可选）

如果从旧机器迁移，可以拷贝以下数据：

```bash
# 聊天历史 + 记忆数据库
scp old-mac:~/Projects/mini-claude-bot/data/mini-claude-bot.db \
    ~/Projects/mini-claude-bot/data/

# Telegram 配置（含 bot token）
scp old-mac:~/.telegram-claude-hero.json ~/

# Claude 配置
scp -r old-mac:~/.claude/ ~/
```

## License

MIT
