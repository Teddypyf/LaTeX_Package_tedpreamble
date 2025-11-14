#!/usr/bin/env bash

# deploy.sh (中文注释版)
#
# 这是一个为 macOS/Linux 设计的 LaTeX 相关文件部署脚本。
# 它的功能是:
#   - 部署 .latexmkrc 配置文件到用户的主目录 (~/.latexmkrc)
#   - 部署 *.sty 样式文件到 TeX Live 的 TEXMFLOCAL 或 TEXMFHOME 目录
#   - 部署 fonts/ 目录下的字体到 TEXMFLOCAL (这通常需要管理员/sudo权限)

# --- 'set -e' 表示脚本中的任何命令一旦执行失败，整个脚本就会立即停止执行。
set -e

# ==============================================================================
# region 辅助函数和控制台设置
# ==============================================================================

# --- 定义用于彩色输出的ANSI转义码 ---
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'

# --- 日志输出函数 ---
# 用法: log_msg <级别> "消息内容"
# 级别可以是: STEP, INFO, OK, WARN, ERROR
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

  # 使用 -e 参数让 echo 能够解析颜色代码
  echo -e "${color}${prefix}${msg}${COLOR_RESET}"
}

# --- 用户确认函数 ---
# 用法: if confirm_yes "您确定要执行此操作吗?"; then ...; fi
# 接受 'y', 'Y' (yes) 作为肯定的回答
confirm_yes() {
  local question="$1"
  # -p 参数可以在同一行显示提示信息
  read -p "$question (Y/N, 默认 N): " answer
  # 使用正则表达式匹配用户的输入
  [[ "$answer" =~ ^[Yy]$ ]]
}

# --- 外部工具调用函数 ---
# 用法: invoke_tool <sudo命令前缀> <工具名> <参数1> <参数2> ...
invoke_tool() {
  local sudo_cmd="$1"   # 是否需要sudo (可以是"sudo"或空字符串)
  local tool_name="$2"  # 要执行的命令, 例如 mktexlsr
  shift 2               # 将前两个参数移出参数列表
  local tool_args=("$@") # 剩下的都是命令的参数

  # 检查命令是否存在于系统的PATH中
  if ! command -v "$tool_name" &> /dev/null; then
    log_msg 'WARN' "命令 '$tool_name' 未找到 (请检查它是否已安装并在 PATH 环境变量中)。"
    return 1 # 返回失败状态
  fi

  log_msg 'STEP' "正在运行: ${sudo_cmd} ${tool_name} ${tool_args[*]}"
  # 执行命令, 并根据其返回值判断成功或失败
  if ${sudo_cmd} "${tool_name}" "${tool_args[@]}"; then
    log_msg 'OK' "'$tool_name' 执行成功。"
    return 0 # 返回成功状态
  else
    local exit_code=$?
    log_msg 'WARN' "'$tool_name' 执行失败，退出码为 $exit_code。"
    return $exit_code # 返回具体的失败退出码
  fi
}
# endregion

# ==============================================================================
# region 脚本和 TeX Live 环境初始化
# ==============================================================================

# --- 确定脚本文件所在的绝对路径 ---
# 这是一个健壮的方法，无论脚本如何被调用，都能找到其真实位置
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
log_msg 'STEP' "脚本所在目录: $SCRIPT_DIR"

# --- 使用 kpsewhich 工具获取 TeX Live 的重要路径变量 ---
# '2>/dev/null' 是为了在命令失败时抑制错误信息
# '|| echo ""' 是为了在命令失败时给变量赋一个空值，防止脚本因变量未定义而中断
TEXMFLOCAL=$(kpsewhich --var-value=TEXMFLOCAL 2>/dev/null || echo "")
TEXMFHOME=$(kpsewhich --var-value=TEXMFHOME 2>/dev/null || echo "")

log_msg 'STEP' "检测到 TEXMFLOCAL = $TEXMFLOCAL"
log_msg 'STEP' "检测到 TEXMFHOME  = $TEXMFHOME"
echo "" # 输出一个空行用于分隔
# endregion

# region 主要部署逻辑

# --- 用于最后生成报告的结果标记 ---
RC_INSTALLED=false
STY_INSTALLED=false
CWL_INSTALLED=false


# --- 1) 部署 latexmkrc 配置文件 ---
if confirm_yes "是否要安装/更新 latexmkrc 配置文件到您的用户目录?"; then
  SRC_RC=""
  # 检查当前目录下是否存在 latexmkrc 或 .latexmkrc
  if [ -f "$SCRIPT_DIR/latexmkrc" ]; then
    SRC_RC="$SCRIPT_DIR/latexmkrc"
  elif [ -f "$SCRIPT_DIR/.latexmkrc" ]; then
    SRC_RC="$SCRIPT_DIR/.latexmkrc"
  fi
  
  # 目标路径是用户主目录下的 .latexmkrc 文件
  DST_RC="$HOME/.latexmkrc"

  if [ -n "$SRC_RC" ]; then # 检查是否找到了源文件
    if [ -f "$DST_RC" ]; then
      log_msg 'INFO' "检测到已存在的目标文件，将执行覆盖: $DST_RC"
    else
      log_msg 'INFO' "将在以下位置创建新文件: $DST_RC"
    fi
    log_msg 'STEP' "正在复制 latexmkrc -> $DST_RC"
    cp -f "$SRC_RC" "$DST_RC" # -f 参数表示强制覆盖
    log_msg 'OK' "latexmkrc 配置文件安装完成。"
    RC_INSTALLED=true
  else
    log_msg 'WARN' "脚本目录中未找到 latexmkrc 或 .latexmkrc 文件，跳过此步骤。"
  fi
else
  log_msg 'INFO' "用户选择跳过 latexmkrc 的安装。"
fi
echo ""
# endregion

# --- 2) 部署 *.sty 样式文件 (仅限系统目录) ---
if confirm_yes "是否要安装/更新 *.sty 样式文件到 TeX Live 系统? (需要管理员权限)"; then
  STY_FILES=()
  while IFS= read -r -d $'\0'; do
    STY_FILES+=("$REPLY")
  done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sty' -print0)

  if [ ${#STY_FILES[@]} -gt 0 ]; then
    SUDO_CMD=""
    # 1. 检查 TEXMFLOCAL 是否有效
    if [ -z "$TEXMFLOCAL" ] || [ ! -d "$TEXMFLOCAL" ]; then
      log_msg 'WARN' "未找到 TEXMFLOCAL 目录，无法安装 .sty 文件。"
    else
      # 2. 检查是否需要 sudo
      if ! [ -w "$TEXMFLOCAL" ]; then
        log_msg 'WARN' "TEXMFLOCAL 目录不可写，将尝试使用 'sudo'。"
        SUDO_CMD="sudo"
        log_msg 'INFO' "后续操作可能需要您输入管理员密码。"
        sudo -v # 提前请求一次sudo权限
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
        STY_INSTALLED=true
      done
    fi
  else
    log_msg 'WARN' "未在本目录找到任何 .sty 文件，跳过样式安装。"
  fi
else
  log_msg 'INFO' "用户选择跳过 *.sty 文件的安装。"
fi
echo ""

# --- 3) 部署 cwl 自动补全文件 ---
if confirm_yes "是否要安装/更新 cwl 自动补全文件到 TeXstudio?"; then
  # 查找 cwl 文件
  CWL_FILES=()
  while IFS= read -r -d $'\0'; do
    CWL_FILES+=("$REPLY")
  done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.cwl' -print0)

  if [ ${#CWL_FILES[@]} -gt 0 ]; then
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
      cp -f "$f" "$DST_FILE" # -f 参数表示强制覆盖
      log_msg 'OK' "完成复制: $FILENAME"
      CWL_INSTALLED=true
    done
  else
    log_msg 'WARN' "脚本目录中未找到 cwl 文件，跳过此步骤。"
  fi
else
  log_msg 'INFO' "用户选择跳过 cwl 文件的安装。"
fi
echo ""
# endregion

# region 安装后刷新
# 检查是否有任何类型的安装被执行过
DID_ANY_INSTALL=false
if [ "$RC_INSTALLED" = true ] || [ "$STY_INSTALLED" = true ]; then
  DID_ANY_INSTALL=true
fi

if [ "$STY_INSTALLED" = true ]; then
  log_msg 'STEP' "检测到 .sty 文件变更，开始刷新 TeX Live 文件数据库..."
  SUDO_CMD="sudo"
  # 如果 TEXMFLOCAL 不可写，刷新数据库也需要 sudo
  if ! [ -w "$TEXMFLOCAL" ]; then
    SUDO_CMD="sudo"
  else
    SUDO_CMD=""
  fi

  # 刷新文件名数据库
  invoke_tool "${SUDO_CMD}" mktexlsr
elif [ "$DID_ANY_INSTALL" = true ]; then
  log_msg 'INFO' "已安装文件，但无需刷新 TeX Live 数据库。"
else
  log_msg 'INFO' "未执行任何安装操作，无需刷新数据库。"
fi
# endregion

# region 总结报告
echo ""
echo "==================== 安装汇总 ===================="
if [ "$RC_INSTALLED" = true ]; then echo "latexmkrc : 已安装"; else echo "latexmkrc : 未安装"; fi
if [ "$STY_INSTALLED" = true ]; then echo "*.sty     : 已安装"; else echo "*.sty     : 未安装"; fi
if [ "$CWL_INSTALLED" = true ]; then echo "*.cwl     : 已安装"; else echo "*.cwl     : 未安装"; fi
echo "=================================================="
read -p "按回车键退出..."
# endregion