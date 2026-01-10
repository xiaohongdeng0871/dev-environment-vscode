#!/bin/bash
# iterm_lrzsz_install.sh
# 自动安装 iTerm2 并配置 lrzsz 文件传输支持

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 检查是否以 root 运行
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "请不要以 root 用户运行此脚本"
        exit 1
    fi
}

# 检查 Homebrew
check_brew() {
    if ! command -v brew &> /dev/null; then
        step "Homebrew 未安装，正在安装..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 配置 Homebrew 环境变量
        if [[ "$SHELL" == *"zsh"* ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ "$SHELL" == *"bash"* ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        info "Homebrew 已安装，版本: $(brew --version | head -n1)"
    fi
}

# 安装 iTerm2
install_iterm2() {
    step "正在安装 iTerm2..."
    
    if brew list --cask | grep -q iterm2; then
        info "iTerm2 已安装"
    else
        # 安装 iTerm2
        brew install --cask iterm2
        
        # 如果安装失败，尝试直接下载
        if [ $? -ne 0 ]; then
            warn "通过 Homebrew 安装失败，尝试直接下载..."
            curl -L -o /tmp/iterm2.zip "https://iterm2.com/downloads/stable/latest"
            unzip -q /tmp/iterm2.zip -d /tmp/
            mv "/tmp/iTerm.app" /Applications/
            rm -f /tmp/iterm2.zip
        fi
    fi
    
    info "iTerm2 安装完成"
}

# 安装 lrzsz
install_lrzsz() {
    step "正在安装 lrzsz..."
    
    if brew list | grep -q lrzsz; then
        info "lrzsz 已安装"
    else
        brew install lrzsz
        
        if [ $? -eq 0 ]; then
            info "lrzsz 安装成功，版本: $(brew info lrzsz | grep -E '^/usr/local/Cellar/lrzsz/' | awk '{print $1}' | xargs basename)"
        else
            error "lrzsz 安装失败"
            return 1
        fi
    fi
    return 0
}

# 安装 expect（用于自动交互）
install_expect() {
    if ! command -v expect &> /dev/null; then
        step "正在安装 expect..."
        brew install expect
    fi
}

# 配置 rz/sz 脚本
configure_iterm2_rzsz() {
    step "配置 iTerm2 rz/sz 支持..."
    
    # 创建配置目录
    CONFIG_DIR="$HOME/.config/iterm2_rzsz"
    mkdir -p "$CONFIG_DIR"
    
    # 1. 创建 iterm2-send-zmodem.sh
    cat > "$CONFIG_DIR/iterm2-send-zmodem.sh" << 'EOF'
#!/bin/bash
# Author: Matt Mastracci (matthew@mastracci.com)
# AppleScript from http://stackoverflow.com/questions/4309087/cancel-button-on-osascript-in-a-bash-script
# licensed under cc-wiki with attribution required
# Remainder of script public domain

osascript -e 'tell application "iTerm2" to version' > /dev/null 2>&1 && NAME=iTerm2 || NAME=iTerm
if [[ $NAME = "iTerm" ]]; then
    FILE=$(osascript -e 'tell application "iTerm" to activate' -e 'tell application "iTerm" to set thefile to choose file with prompt "Choose a file to send"' -e "do shell script (\"echo \"&(quoted form of POSIX path of thefile as Unicode text)&\"\")")
else
    FILE=$(osascript -e 'tell application "iTerm2" to activate' -e 'tell application "iTerm2" to set thefile to choose file with prompt "Choose a file to send"' -e "do shell script (\"echo \"&(quoted form of POSIX path of thefile as Unicode text)&\"\")")
fi
if [[ $FILE = "" ]]; then
    echo Cancelled.
    # Send ZModem cancel
    echo -e \\x18\\x18\\x18\\x18\\x18
    sleep 1
    echo
    echo \# Cancelled transfer
else
    /opt/homebrew/bin/sz "$FILE" -e
    sleep 1
    echo
    echo \# Received "$FILE"
fi
EOF
    
    # 2. 创建 iterm2-recv-zmodem.sh
    cat > "$CONFIG_DIR/iterm2-recv-zmodem.sh" << 'EOF'
#!/bin/bash
# Author: Matt Mastracci (matthew@mastracci.com)
# AppleScript from http://stackoverflow.com/questions/4309087/cancel-button-on-osascript-in-a-bash-script
# licensed under cc-wiki with attribution required
# Remainder of script public domain

osascript -e 'tell application "iTerm2" to version' > /dev/null 2>&1 && NAME=iTerm2 || NAME=iTerm
if [[ $NAME = "iTerm" ]]; then
    FILE=$(osascript -e 'tell application "iTerm" to activate' -e 'tell application "iTerm" to set thefile to choose folder with prompt "Choose a folder to place received files in"' -e "do shell script (\"echo \"&(quoted form of POSIX path of thefile as Unicode text)&\"\")")
else
    FILE=$(osascript -e 'tell application "iTerm2" to activate' -e 'tell application "iTerm2" to set thefile to choose folder with prompt "Choose a folder to place received files in"' -e "do shell script (\"echo \"&(quoted form of POSIX path of thefile as Unicode text)&\"\")")
fi
if [[ $FILE = "" ]]; then
    echo Cancelled.
    # Send ZModem cancel
    echo -e \\x18\\x18\\x18\\x18\\x18
    sleep 1
    echo
    echo \# Cancelled transfer
else
    cd "$FILE"
    /opt/homebrew/bin/rz -E
    sleep 1
    echo
    echo \# Sent
fi
EOF
    
    # 添加执行权限
    chmod +x "$CONFIG_DIR"/*.sh
    
    # 3. 创建自动检测脚本
    cat > "$CONFIG_DIR/auto_rzsz.sh" << 'EOF'
#!/usr/bin/expect -f
# 自动检测 rz/sz 并执行

# 获取 lrzsz 路径
set lrzsz_path "/opt/homebrew/bin"
if {[file exists $lrzsz_path/rz] == 0} {
    set lrzsz_path "/usr/local/bin"
}

# 检查是否支持 rz/sz
if {[file exists $lrzsz_path/rz] == 0 && [file exists $lrzsz_path/sz] == 0} {
    puts "lrzsz not found. Please install with: brew install lrzsz"
    exit 1
}

# 设置 rz/sz 路径
set rz_cmd "$lrzsz_path/rz"
set sz_cmd "$lrzsz_path/sz"
EOF
    
    chmod +x "$CONFIG_DIR/auto_rzsz.sh"
    
    info "rz/sz 脚本已创建到: $CONFIG_DIR"
}

# 配置 shell 环境
configure_shell() {
    step "配置 shell 环境..."
    
    # 确定 shell 配置文件
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        SHELL_RC="$HOME/.bash_profile"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
    
    # 检查是否已配置
    if grep -q "LRZSZ_PATH" "$SHELL_RC"; then
        info "lrzsz 路径已配置"
    else
        # 添加 lrzsz 到 PATH
        echo '' >> "$SHELL_RC"
        echo '# lrzsz configuration' >> "$SHELL_RC"
        echo 'export LRZSZ_PATH="/opt/homebrew/bin"' >> "$SHELL_RC"
        echo 'export PATH="$LRZSZ_PATH:$PATH"' >> "$SHELL_RC"
        info "已添加 lrzsz 到 PATH"
    fi
    
    # 添加 iTerm2 rz/sz 触发器配置提示
    if ! grep -q "iTerm2 ZModem" "$SHELL_RC"; then
        echo '' >> "$SHELL_RC"
        echo '# iTerm2 ZModem configuration' >> "$SHELL_RC"
        echo '# 在 iTerm2 中配置以下触发器:' >> "$SHELL_RC"
        echo '# 1. rz 触发器: 正则表达式: \*\*B0100 动作: Run Silent Coprocess 参数: $HOME/.config/iterm2_rzsz/iterm2-recv-zmodem.sh' >> "$SHELL_RC"
        echo '# 2. sz 触发器: 正则表达式: \*\*B00000000000000 动作: Run Silent Coprocess 参数: $HOME/.config/iterm2_rzsz/iterm2-send-zmodem.sh' >> "$SHELL_RC"
    fi
}

# 显示配置指南
show_config_guide() {
    echo -e "\n${BLUE}==============================${NC}"
    echo -e "${GREEN}安装完成！请按以下步骤配置：${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo ""
    echo -e "${YELLOW}步骤 1: 重启终端或执行${NC}"
    echo "source $SHELL_RC"
    echo ""
    echo -e "${YELLOW}步骤 2: 配置 iTerm2 触发器${NC}"
    echo "1. 打开 iTerm2 → Preferences → Profiles"
    echo "2. 选择你的 Profile → Advanced → Triggers"
    echo "3. 点击 Edit → 添加以下两个触发器:"
    echo ""
    echo -e "${GREEN}触发器 1 (用于 rz 上传):${NC}"
    echo "   Regular Expression: \*\*B0100"
    echo "   Action: Run Silent Coprocess"
    echo "   Parameters: $HOME/.config/iterm2_rzsz/iterm2-recv-zmodem.sh"
    echo "   Instant: ✓"
    echo ""
    echo -e "${GREEN}触发器 2 (用于 sz 下载):${NC}"
    echo "   Regular Expression: \*\*B00000000000000"
    echo "   Action: Run Silent Coprocess"
    echo "   Parameters: $HOME/.config/iterm2_rzsz/iterm2-send-zmodem.sh"
    echo "   Instant: ✓"
    echo ""
    echo -e "${YELLOW}步骤 3: 使用方法${NC}"
    echo "- 上传文件到服务器: 在终端输入 'rz'，选择文件"
    echo "- 从服务器下载文件: 在终端输入 'sz 文件名'，选择保存目录"
    echo ""
    echo -e "${YELLOW}步骤 4: 测试${NC}"
    echo "1. 连接到支持 ZModem 的服务器（如通过 ssh）"
    echo "2. 在服务器上输入 'rz' 测试上传"
    echo "3. 在服务器上输入 'sz 文件名' 测试下载"
    echo ""
    echo -e "${BLUE}===================================${NC}"
    echo -e "${GREEN}配置文件位置: $HOME/.config/iterm2_rzsz/${NC}"
    echo -e "${BLUE}===================================${NC}"
}

# 测试安装
test_installation() {
    step "测试安装..."
    
    if command -v sz &> /dev/null; then
        info "sz 命令可用: $(which sz)"
    else
        warn "sz 命令未找到，请检查 PATH 配置"
    fi
    
    if command -v rz &> /dev/null; then
        info "rz 命令可用: $(which rz)"
    else
        warn "rz 命令未找到，请检查 PATH 配置"
    fi
    
    if [ -f "$HOME/.config/iterm2_rzsz/iterm2-send-zmodem.sh" ]; then
        info "iTerm2 脚本已安装"
    fi
    
    info "请重新打开 iTerm2 使配置生效"
}

# 主函数
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN} iTerm2 和 lrzsz 安装脚本 ${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # 检查运行环境
    check_root
    
    # 检查操作系统
    if [[ "$(uname)" != "Darwin" ]]; then
        error "此脚本仅支持 macOS 系统"
        exit 1
    fi
    
    # 安装步骤
    check_brew
    install_iterm2
    install_expect
    install_lrzsz
    configure_iterm2_rzsz
    configure_shell
    test_installation
    show_config_guide
    
    echo -e "\n${GREEN}安装完成！${NC}"
}

# 执行主函数
main "$@"