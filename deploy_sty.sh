#!/usr/bin/env bash

# deploy_sty.sh
#
# 部署 *.sty 样式文件到 TeX Live 的 TEXMFLOCAL 目录
# 使用方式: ./deploy_sty.sh

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

# 外部工具调用函数
invoke_tool() {
  local sudo_cmd="$1"
  local tool_name="$2"
  shift 2
  local tool_args=("$@")

  if ! command -v "$tool_name" &> /dev/null; then
    log_msg 'ERROR' "命令 '$tool_name' 未找到 (请检查它是否已安装并在 PATH 环境变量中)。"
    return 1
  fi

  log_msg 'STEP' "正在运行: ${sudo_cmd} ${tool_name} ${tool_args[*]}"
  if ${sudo_cmd} "${tool_name}" "${tool_args[@]}"; then
    log_msg 'OK' "'$tool_name' 执行成功。"
    return 0
  else
    local exit_code=$?
    log_msg 'ERROR' "'$tool_name' 执行失败，退出码为 $exit_code。"
    return $exit_code
  fi
}

# ==============================================================================
# 脚本初始化
# ==============================================================================

# 确定脚本文件所在的绝对路径
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
log_msg 'STEP' "脚本所在目录: $SCRIPT_DIR"

# 使用 kpsewhich 工具获取 TeX Live 的路径变量
TEXMFLOCAL=$(kpsewhich --var-value=TEXMFLOCAL 2>/dev/null || echo "")
TEXMFHOME=$(kpsewhich --var-value=TEXMFHOME 2>/dev/null || echo "")

log_msg 'STEP' "检测到 TEXMFLOCAL = $TEXMFLOCAL"
log_msg 'STEP' "检测到 TEXMFHOME  = $TEXMFHOME"
echo ""

# ==============================================================================
# 部署 *.sty 样式文件
# ==============================================================================

STY_FILES=()
while IFS= read -r -d $'\0'; do
  STY_FILES+=("$REPLY")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sty' -print0)

if [ ${#STY_FILES[@]} -eq 0 ]; then
  log_msg 'ERROR' "未在本目录找到任何 .sty 文件，部署失败。"
  exit 1
fi

SUDO_CMD=""
# 检查 TEXMFLOCAL 是否有效
if [ -z "$TEXMFLOCAL" ] || [ ! -d "$TEXMFLOCAL" ]; then
  log_msg 'ERROR' "未找到 TEXMFLOCAL 目录，无法安装 .sty 文件。"
  exit 1
fi

# 检查是否需要 sudo
if ! [ -w "$TEXMFLOCAL" ]; then
  log_msg 'WARN' "TEXMFLOCAL 目录不可写，将尝试使用 'sudo'。"
  SUDO_CMD="sudo"
  log_msg 'INFO' "后续操作需要您输入管理员密码。"
  sudo -v
fi

TARGET_TREE="$TEXMFLOCAL"
log_msg 'STEP' "将把 .sty 文件安装到 (LOCAL): $TARGET_TREE"

TEXLATEX_DIR="$TARGET_TREE/tex/latex"
if ! [ -d "$TEXLATEX_DIR" ]; then
  log_msg 'STEP' "目标目录不存在，正在创建: $TEXLATEX_DIR"
  ${SUDO_CMD} mkdir -p "$TEXLATEX_DIR"
fi

for f in "${STY_FILES[@]}"; do
  FILENAME=$(basename "$f")
  PKG_NAME="${FILENAME%.*}"
  PKG_DIR="$TEXLATEX_DIR/$PKG_NAME"

  if ! [ -d "$PKG_DIR" ]; then
    log_msg 'STEP' "正在为宏包 '$PKG_NAME' 创建目录: $PKG_DIR"
    ${SUDO_CMD} mkdir -p "$PKG_DIR"
  fi
  
  DST_FILE="$PKG_DIR/$FILENAME"
  if [ -f "$DST_FILE" ]; then
    log_msg 'INFO' "文件已存在，将覆盖: $DST_FILE"
  else
    log_msg 'INFO' "新安装: $DST_FILE"
  fi
  log_msg 'STEP' "正在复制: $FILENAME -> $DST_FILE"
  ${SUDO_CMD} cp -f "$f" "$DST_FILE"
  log_msg 'OK' "完成复制: $FILENAME"
done

echo ""
log_msg 'STEP' "刷新 TeX Live 文件数据库..."

# 刷新文件名数据库
if ! [ -w "$TEXMFLOCAL" ]; then
  SUDO_CMD="sudo"
else
  SUDO_CMD=""
fi
invoke_tool "${SUDO_CMD}" mktexlsr

echo ""
echo "==================== 部署完成 ===================="
echo "*.sty     : 已安装到 $TEXLATEX_DIR"
echo "=================================================="
