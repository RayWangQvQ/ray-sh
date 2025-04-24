#!/bin/bash
###
 # @Author: Ray zai7lou@outlook.com
 # @Date: 2024-05-19 12:34:11
 # @LastEditors: Gemini
 # @LastEditTime: 2025-04-24
 # @FilePath: ./node_exporter_installer_auto_os.sh
 # @Description: Installs Node Exporter, automatically detecting OS and architecture.
 #
 # Copyright (c) 2024 by ${git_name_email}, All Rights Reserved.
###

set -e
set -u
set -o pipefail

NODE_EXPORTER_VERSION="1.9.1" # Specify the desired Node Exporter version
SCRIPT_VERSION="2025-04-24" # Version of this script

# Display ultra cool Ray Node logo
echo ""
echo -e "\033[38;5;51m██████╗ \033[38;5;45m █████╗ \033[38;5;39m██╗   ██╗\033[38;5;33m    \033[38;5;27m███╗   ██╗\033[38;5;21m ██████╗ \033[38;5;57m██████╗ \033[38;5;93m███████╗"
echo -e "\033[38;5;51m██╔══██╗\033[38;5;45m██╔══██╗\033[38;5;39m╚██╗ ██╔╝\033[38;5;33m    \033[38;5;27m████╗  ██║\033[38;5;21m██╔═══██╗\033[38;5;57m██╔══██╗\033[38;5;93m██╔════╝"
echo -e "\033[38;5;51m██████╔╝\033[38;5;45m███████║\033[38;5;39m ╚████╔╝ \033[38;5;33m    \033[38;5;27m██╔██╗ ██║\033[38;5;21m██║   ██║\033[38;5;57m██║  ██║\033[38;5;93m█████╗  "
echo -e "\033[38;5;51m██╔══██╗\033[38;5;45m██╔══██║\033[38;5;39m  ╚██╔╝  \033[38;5;33m    \033[38;5;27m██║╚██╗██║\033[38;5;21m██║   ██║\033[38;5;57m██║  ██║\033[38;5;93m██╔══╝  "
echo -e "\033[38;5;51m██║  ██║\033[38;5;45m██║  ██║\033[38;5;39m   ██║   \033[38;5;33m    \033[38;5;27m██║ ╚████║\033[38;5;21m╚██████╔╝\033[38;5;57m██████╔╝\033[38;5;93m███████╗"
echo -e "\033[38;5;51m╚═╝  ╚═╝\033[38;5;45m╚═╝  ╚═╝\033[38;5;39m   ╚═╝   \033[38;5;33m    \033[38;5;27m╚═╝  ╚═══╝\033[38;5;21m ╚═════╝ \033[38;5;57m╚═════╝ \033[38;5;93m╚══════╝"
echo ""
echo -e "\033[38;5;208m════════════════════════════════════════════════════════════════════\033[0m"
echo -e "\033[1m\033[38;5;226m        » Node Exporter Installer «        \033[0m"
sleep 0.5
echo -e "\033[1m\033[38;5;118m        » Installer Version: $SCRIPT_VERSION «         \033[0m"
echo -e "\033[1m\033[38;5;118m        » Node Exporter Version: v${NODE_EXPORTER_VERSION}  «         \033[0m"
echo -e "\033[38;5;208m════════════════════════════════════════════════════════════════════\033[0m"
echo ""

echo "Installer version: $SCRIPT_VERSION"

# --- Configuration ---
BASE_DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download"

# Variables to be filled by user input
CERT_FILE=""
CERT_KEY_FILE=""
PORT="9100" # Default port
USER_NAME=""
USER_PWD_HASH=""

# --- Detect OS and Architecture ---
OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_TYPE=$(uname -m)
NODE_EXPORTER_ARCH=""

# Map uname -m output to node_exporter architecture naming
case $OS_TYPE in
    linux)
        case $ARCH_TYPE in
            x86_64) NODE_EXPORTER_ARCH="amd64";;
            aarch64) NODE_EXPORTER_ARCH="arm64";;
            armv*) NODE_EXPORTER_ARCH="armv${ARCH_TYPE:4}";; # Handles armv5, armv6, armv7
            i?86) NODE_EXPORTER_ARCH="386";;
            mips64*) NODE_EXPORTER_ARCH="mips64";; # Check mips64 first
            mips*) NODE_EXPORTER_ARCH="mips";;     # Then check mips
            *) echo "错误：不支持的 Linux 架构 '$ARCH_TYPE'"; exit 1;;
        esac
        ;;
    darwin)
         case $ARCH_TYPE in
            x86_64) NODE_EXPORTER_ARCH="amd64";;
            arm64) NODE_EXPORTER_ARCH="arm64";; # For Apple Silicon Macs
            *) echo "错误：不支持的 Darwin (macOS) 架构 '$ARCH_TYPE'"; exit 1;;
        esac
        ;;
    *)
        echo "错误：不支持的操作系统 '$OS_TYPE'"
        exit 1
        ;;
esac

# Construct download URL and filename
NODE_EXPORTER_FILENAME="node_exporter-${NODE_EXPORTER_VERSION}.${OS_TYPE}-${NODE_EXPORTER_ARCH}.tar.gz"
DOWNLOAD_URL="${BASE_DOWNLOAD_URL}/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_FILENAME}"
EXTRACTED_DIR="node_exporter-${NODE_EXPORTER_VERSION}.${OS_TYPE}-${NODE_EXPORTER_ARCH}"

echo "检测到操作系统: $OS_TYPE"
echo "检测到架构: $ARCH_TYPE (映射为: $NODE_EXPORTER_ARCH)"
echo "将下载: $DOWNLOAD_URL"

# --- User Input ---
read -p "请输入 cert file 全路径 (留空则不启用 TLS): " CERT_FILE
if [[ -n "$CERT_FILE" ]]; then
    read -p "请输入 cert key file 全路径: " CERT_KEY_FILE
    if [[ -z "$CERT_KEY_FILE" ]]; then
        echo "错误：指定了 cert file 但未指定 cert key file。"
        exit 1
    fi
fi

read -p "请输入端口号 (默认 9100): " USER_PORT_INPUT
# Use default if input is empty
PORT=${USER_PORT_INPUT:-$PORT}

read -p "请输入 basic auth 用户名 (留空则不启用): " USER_NAME
if [[ -n "$USER_NAME" ]]; then
    echo "请为用户 '$USER_NAME' 生成 bcrypt 哈希密码。"
    echo "可以使用在线工具（如 https://bcrypt-generator.com/ 或 https://bfotool.com/zh/bcrypt-hash-generator），推荐使用 10 rounds。"
    read -p "请输入 bcrypt 哈希密码: " USER_PWD_HASH
    if [[ -z "$USER_PWD_HASH" ]]; then
        echo "错误：指定了用户名但未指定密码哈希。"
        exit 1
    fi
fi

# --- Installation ---
INSTALL_DIR="/opt/node_exporter"
BIN_PATH="/usr/local/bin/node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
CONFIG_FILE="$INSTALL_DIR/config.yml"
NODE_EXPORTER_USER="node_exporter"

# Create a temporary directory for download and extraction
TMP_DIR=$(mktemp -d)
echo "使用临时目录: $TMP_DIR"
cd "$TMP_DIR"

# Download
echo -e "\n--- 开始下载 ---"
if [ ! -f "$NODE_EXPORTER_FILENAME" ]; then
    echo "正在下载 $DOWNLOAD_URL ..."
    wget -q --show-progress "$DOWNLOAD_URL"
else
    echo "$NODE_EXPORTER_FILENAME 已存在，跳过下载。"
fi

# Extract
echo -e "\n--- 开始解压 ---"
tar xvfz "$NODE_EXPORTER_FILENAME"
cd "$EXTRACTED_DIR"
ls -l

# Create node_exporter user and group if they don't exist
echo -e "\n--- 开始设置用户权限 ---"
if ! id "$NODE_EXPORTER_USER" &>/dev/null; then
    echo "创建用户 '$NODE_EXPORTER_USER'..."
    useradd --system --no-create-home --shell /bin/false "$NODE_EXPORTER_USER"
else
    echo "用户 '$NODE_EXPORTER_USER' 已存在。"
fi

# Create installation directory and config file
echo -e "\n--- 开始创建配置文件 ---"
mkdir -p "$INSTALL_DIR"
# Generate config only if TLS or Basic Auth is enabled
if [[ -n "$CERT_FILE" || -n "$USER_NAME" ]]; then
    echo "生成配置文件 $CONFIG_FILE ..."
    > "$CONFIG_FILE" # Create or truncate the file
    if [[ -n "$CERT_FILE" ]]; then
        cat <<EOF >> "$CONFIG_FILE"
tls_server_config:
  cert_file: $CERT_FILE
  key_file: $CERT_KEY_FILE
EOF
    fi
    if [[ -n "$USER_NAME" ]]; then
         cat <<EOF >> "$CONFIG_FILE"
basic_auth_users:
  $USER_NAME: '$USER_PWD_HASH'
EOF
    fi
    chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE" # Restrict permissions for config file
else
    echo "未启用 TLS 或 Basic Auth，不创建配置文件。"
fi

# Copy node_exporter binary and set ownership
echo -e "\n--- 开始复制二进制文件 ---"
cp -f ./node_exporter "$BIN_PATH"
chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$BIN_PATH"
chmod 755 "$BIN_PATH"

# Set certificate ownership and permissions if TLS is enabled
if [[ -n "$CERT_FILE" ]]; then
    echo -e "\n--- 开始设置证书权限 ---"
    # Check if files exist before changing permissions
    if [[ -f "$CERT_FILE" && -f "$CERT_KEY_FILE" ]]; then
        chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$CERT_FILE" "$CERT_KEY_FILE"
        # Key file should be more restricted
        chmod 640 "$CERT_FILE"
        chmod 600 "$CERT_KEY_FILE"
        echo "证书权限已设置。"
    else
        echo "错误：证书文件 $CERT_FILE 或 $CERT_KEY_FILE 不存在！"
        # Optionally clean up and exit here if certs are mandatory
        # rm -rf "$TMP_DIR"
        # exit 1
    fi
fi

# Create or update systemd service file
echo -e "\n--- 开始设置 systemd 服务 ---"
# Base ExecStart command
EXEC_START="/usr/local/bin/node_exporter --web.listen-address=:$PORT"
# Add config file argument if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    EXEC_START="$EXEC_START --web.config.file=$CONFIG_FILE"
fi

cat <<EOF | tee "$SERVICE_FILE"
[Unit]
Description=Node Exporter (Version: ${NODE_EXPORTER_VERSION})
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
Group=$NODE_EXPORTER_USER
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=$EXEC_START

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, start and enable node_exporter service
echo -e "\n--- 开始启动服务 ---"
systemctl daemon-reload
systemctl restart node_exporter # Use restart to apply changes if service was already running
if systemctl is-enabled node_exporter &>/dev/null; then
    echo "服务已启用。"
else
    systemctl enable node_exporter
fi

# Clean up temporary directory
echo -e "\n--- 清理临时文件 ---"
rm -rf "$TMP_DIR"
echo "临时目录 $TMP_DIR 已删除。"


# Check service status
echo -e "\n--- 检查服务状态 ---"
sleep 3s
echo "监听端口:"
# Try ss first, fallback to netstat
if command -v ss &> /dev/null; then
    ss -tlpn | grep ":$PORT" || echo "端口 $PORT 未监听到 (使用 ss)。"
elif command -v netstat &> /dev/null; then
    netstat -tlpn | grep ":$PORT" || echo "端口 $PORT 未监听到 (使用 netstat)。"
else
    echo "警告：无法找到 ss 或 netstat 命令来检查监听端口。"
fi
echo -e "\n服务状态:"
systemctl status node_exporter --no-pager # --no-pager prevents less from being used

echo -e "\n--- 安装完成 ---"
echo "Node Exporter (版本 ${NODE_EXPORTER_VERSION}) 已安装并启动在端口 $PORT。"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "配置文件: $CONFIG_FILE"
fi
echo "服务名: node_exporter.service"