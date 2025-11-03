#!/usr/bin/env bash

# deploy_latexmkrc.sh
#
# 部署 .latexmkrc 配置文件到用户的主目录 (~/.latexmkrc)
# 使用方式: ./deploy_latexmkrc.sh

set -e

# ==============================================================================
# 辅助函数和控制台设置
# ==============================================================================

# 定义用于彩色输出的ANSI转义码
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'

# 日志输出函数
log_msg() {
  local level="$1"
  local msg="$2"
  local prefix="[${level}] "
  local color="$COLOR_RESET"

  case "$level" in
    ERROR) color="$COLOR_RED" ;;
    WARN)  color="$COLOR_YELLOW" ;;
    OK)    color="$COLOR_GREEN" ;;
    STEP)  color="$COLOR_CYAN" ;;
  esac

  echo -e "${color}${prefix}${msg}${COLOR_RESET}"
}

# ==============================================================================
# 脚本初始化
# ==============================================================================

# 确定脚本文件所在的绝对路径
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
log_msg 'STEP' "脚本所在目录: $SCRIPT_DIR"
echo ""

# ==============================================================================
# 部署 latexmkrc 配置文件
# ==============================================================================

SRC_RC=""
# 检查当前目录下是否存在 latexmkrc 或 .latexmkrc
if [ -f "$SCRIPT_DIR/latexmkrc" ]; then
  SRC_RC="$SCRIPT_DIR/latexmkrc"
elif [ -f "$SCRIPT_DIR/.latexmkrc" ]; then
  SRC_RC="$SCRIPT_DIR/.latexmkrc"
fi

# 目标路径是用户主目录下的 .latexmkrc 文件
DST_RC="$HOME/.latexmkrc"

if [ -n "$SRC_RC" ]; then
  if [ -f "$DST_RC" ]; then
    log_msg 'INFO' "检测到已存在的目标文件，将执行覆盖: $DST_RC"
  else
    log_msg 'INFO' "将在以下位置创建新文件: $DST_RC"
  fi
  log_msg 'STEP' "正在复制 latexmkrc -> $DST_RC"
  cp -f "$SRC_RC" "$DST_RC"
  log_msg 'OK' "latexmkrc 配置文件安装完成。"
else
  log_msg 'ERROR' "脚本目录中未找到 latexmkrc 或 .latexmkrc 文件，部署失败。"
  exit 1
fi

echo ""
echo "==================== 部署完成 ===================="
echo "latexmkrc : 已安装到 $DST_RC"
echo "=================================================="
