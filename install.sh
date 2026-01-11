#!/bin/bash

# 检查 zshrc 是否安装，如果没有则安装
function check_zshrc() {
    if [ ! -f ~/.zshrc ]; then
        echo "zshrc not found, please install it first."
        echo "Installing zshrc..."
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
    fi
    # 配置 zshrc
    echo "Configuring zshrc..."

}

# 检查 homebrew 是否安装，如果没有安装则安装
function check_brew() {
    if [ ! -x "$(command -v brew)" ]; then
        echo "Homebrew not installed, please install it first."
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
}

# 检查 golang 是否安装，如果没有安装则使用 brew安装
function check_golang() {
    if [ ! -x "$(command -v go)" ]; then
        echo "Golang not installed, please install it first."
        echo "Installing Golang..."
        brew install go
    fi

    # 配置 go
    echo "Configuring Golang..."
    echo 'export GOPATH=$HOME/go' >> ~/.zshrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
    source ~/.zshrc

    # 安装 go tools
    go install github.com/go-delve/delve/cmd/dlv@latest
    go install mvdan.cc/gofumpt@latest
    go install golang.org/x/tools/gopls@latest
    go install github.com/mgechev/revive@latest

}

# 检查 rust 是否安装，如果没有安装则使用 安装
function check_rust() {
    if [ ! -x "$(command -v rustc)" ]; then
        echo "Rust not installed, please install it first."
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    fi

    # 配置 rust
    echo "Configuring Rust..."
    echo 'export PATH=$PATH:$HOME/.cargo/bin' >> ~/.zshrc
}

# 检查 minicode是否安装，如果没有安装则使用 brew安装
function check_minicode() {
    if [ ! -x "$(command -v minicode)" ]; then
        echo "Minicode not installed, please install it first."
        echo "Installing Minicode..."
        curl -s https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh | bash
    fi
}

# 检查 vscode 是否安装，如果没有安装则下载并安装
function check_vscode() {
    if [ ! -x "$(command -v code)" ]; then
        echo "VSCode not installed, please install it first."
        echo "Downloading VSCode..."
        curl -fsSL https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64 | tar -xzv
        echo "Installing VSCode..."
        sudo mv VSCode-darwin-arm64 /Applications/Visual\ Studio
        echo 'export PATH=$PATH:/Applications/Visual\ Studio/Visual\ Studio\ Code.app/Contents/Resources/app/bin' >> ~/.zshrc
    fi

    # 配置 vscode
    echo "Configuring VSCode..."
    # 安装插件
    cat extensions.txt | xargs -n 1 code --install-extension

    # 拷贝用户配置
    cp -r vscode-settings.json ~/Library/Application\ Support/Code/User/settings.json
}

function check_nodejs() {
    if [ ! -x "$(command -v node)" ]; then
        echo "Node.js not installed, installing via Homebrew..."
        brew install node
    fi
    
    # 配置 npm 全局路径
    echo 'export PATH=$PATH:$(npm config get prefix)/bin' >> ~/.zshrc
    source ~/.zshrc
}

function main() {
    echo "Installing..."
    sh iterm-lwzsz.sh 
    check_zshrc
    check_brew
    check_golang
    check_rust
    check_minicode
    check_vscode
    check_nodejs
}

main