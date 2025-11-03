#!/usr/bin/env bash

# deploy_cwl.sh
#
# 部署 *.cwl 自动补全文件到 TeXstudio
# 使用方式: ./deploy_cwl.sh

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
# 部署 cwl 自动补全文件
# ==============================================================================

CWL_FILES=()
while IFS= read -r -d $'\0'; do
  CWL_FILES+=("$REPLY")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.cwl' -print0)

if [ ${#CWL_FILES[@]} -eq 0 ]; then
  log_msg 'ERROR' "脚本目录中未找到 cwl 文件，部署失败。"
  exit 1
fi

# 目标路径
DST_DIR="$HOME/.config/texstudio/completion/user"

if [ ! -d "$DST_DIR" ]; then
  log_msg 'INFO' "目标目录不存在，将创建: $DST_DIR"
  mkdir -p "$DST_DIR"
fi

for f in "${CWL_FILES[@]}"; do
  FILENAME=$(basename "$f")
  DST_FILE="$DST_DIR/$FILENAME"
  
  if [ -f "$DST_FILE" ]; then
    log_msg 'INFO' "文件已存在，将覆盖: $DST_FILE"
  else
    log_msg 'INFO' "新安装: $DST_FILE"
  fi
  
  log_msg 'STEP' "正在复制: $FILENAME -> $DST_FILE"
  cp -f "$f" "$DST_FILE"
  log_msg 'OK' "完成复制: $FILENAME"
done

echo ""
echo "==================== 部署完成 ===================="
echo "*.cwl     : 已安装到 $DST_DIR"
echo "=================================================="
