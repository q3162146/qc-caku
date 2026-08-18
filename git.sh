#!/usr/bin/env bash
# git 便捷包装（系统未安装 git 时使用）
# 用法: ./git.sh <git命令...>   例: ./git.sh status / ./git.sh add -A / ./git.sh commit -m "..."
# 说明: git 二进制解包自 Ubuntu noble 官方 deb（版本 2.43.0），存放于 .git-local/gitroot/
# 建议: 后续在系统安装 git (sudo apt install git) 后即可直接用 git 命令，本脚本可弃用
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITROOT="$DIR/.git-local/gitroot"
export GIT_EXEC_PATH="$GITROOT/usr/lib/git-core"
exec "$GITROOT/usr/bin/git" "$@"
