#!/bin/bash
###
 # @Author: Ray
 # @Date: 2024-05-19 12:34:11
 # @LastEditors: Ray
 # @LastEditTime: 2025-04-25
 # @Description: Manages Node Exporter - install, uninstall, status check, and configuration.
###

set -e
set -o pipefail

# Constants
NODE_EXPORTER_VERSION="1.9.1" # Specify the desired Node Exporter version
SCRIPT_VERSION="2025-04-25" # Version of this script
INSTALL_DIR="/opt/node_exporter"
BIN_PATH="/usr/local/bin/node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
CONFIG_FILE="$INSTALL_DIR/config.yml"
NODE_EXPORTER_USER="node_exporter"
DEFAULT_PORT="9100"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper function to display usage instructions
show_help() {
    echo -e "${GREEN}Node Exporter Manager Usage:${NC}"
    echo -e "  $0 [OPTION]"
    echo -e "\n${CYAN}Options:${NC}"
    echo -e "  ${GREEN}--help, -h${NC}         显示此帮助信息"
    echo -e "  ${GREEN}--menu, -m${NC}         显示交互式菜单 (默认)"
    echo -e "  ${GREEN}--install, -i${NC}      安装 Node Exporter"
    echo -e "  ${GREEN}--uninstall, -u${NC}    卸载 Node Exporter"
    echo -e "  ${GREEN}--status, -s${NC}       查看 Node Exporter 状态"
    echo -e "  ${GREEN}--restart, -r${NC}      重启 Node Exporter 服务"
    echo -e "  ${GREEN}--config, -c${NC}       更新 Node Exporter 配置"
    echo -e "  ${GREEN}--backup, -b${NC}       备份当前配置"
    echo -e "  ${GREEN}--restore${NC}          恢复配置备份"
    echo -e "\n${CYAN}安装选项:${NC}"
    echo -e "  ${GREEN}--port=PORT${NC}        指定端口号 (默认: $DEFAULT_PORT)"
    echo -e "  ${GREEN}--tls-cert=FILE${NC}    指定 TLS 证书文件路径"
    echo -e "  ${GREEN}--tls-key=FILE${NC}     指定 TLS 密钥文件路径"
    echo -e "  ${GREEN}--auth-user=USER${NC}   指定 Basic Auth 用户名"
    echo -e "  ${GREEN}--auth-hash=HASH${NC}   指定 Basic Auth 密码哈希值"
    echo -e "\n${YELLOW}示例:${NC}"
    echo -e "  $0 --install --port=9100"
    echo -e "  $0 --install --tls-cert=/path/to/cert.pem --tls-key=/path/to/key.pem"
    echo -e "  $0 --status"
    echo -e "  $0 --uninstall"
}

# Display ultra cool Ray Node logo
display_logo() {
    echo ""
    echo -e "\033[38;5;51m██████╗ \033[38;5;45m █████╗ \033[38;5;39m██╗   ██╗\033[38;5;33m    \033[38;5;27m███╗   ██╗\033[38;5;21m ██████╗ \033[38;5;57m██████╗ \033[38;5;93m███████╗"
    echo -e "\033[38;5;51m██╔══██╗\033[38;5;45m██╔══██╗\033[38;5;39m╚██╗ ██╔╝\033[38;5;33m    \033[38;5;27m████╗  ██║\033[38;5;21m██╔═══██╗\033[38;5;57m██╔══██╗\033[38;5;93m██╔════╝"
    echo -e "\033[38;5;51m██████╔╝\033[38;5;45m███████║\033[38;5;39m ╚████╔╝ \033[38;5;33m    \033[38;5;27m██╔██╗ ██║\033[38;5;21m██║   ██║\033[38;5;57m██║  ██║\033[38;5;93m█████╗  "
    echo -e "\033[38;5;51m██╔══██╗\033[38;5;45m██╔══██║\033[38;5;39m  ╚██╔╝  \033[38;5;33m    \033[38;5;27m██║╚██╗██║\033[38;5;21m██║   ██║\033[38;5;57m██║  ██║\033[38;5;93m██╔══╝  "
    echo -e "\033[38;5;51m██║  ██║\033[38;5;45m██║  ██║\033[38;5;39m   ██║   \033[38;5;33m    \033[38;5;27m██║ ╚████║\033[38;5;21m╚██████╔╝\033[38;5;57m██████╔╝\033[38;5;93m███████╗"
    echo -e "\033[38;5;51m╚═╝  ╚═╝\033[38;5;45m╚═╝  ╚═╝\033[38;5;39m   ╚═╝   \033[38;5;33m    \033[38;5;27m╚═╝  ╚═══╝\033[38;5;21m ╚═════╝ \033[38;5;57m╚═════╝ \033[38;5;93m╚══════╝"
    echo ""
    echo -e "\033[38;5;208m════════════════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[1m\033[38;5;226m        » Node Exporter Manager «        \033[0m"
    sleep 0.5
    echo -e "\033[1m\033[38;5;118m        » Manager Version: $SCRIPT_VERSION «         \033[0m"
    echo -e "\033[1m\033[38;5;118m        » Node Exporter Version: v${NODE_EXPORTER_VERSION}  «         \033[0m"
    echo -e "\033[38;5;208m════════════════════════════════════════════════════════════════════\033[0m"
    echo ""
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 此脚本需要 root 权限来运行。${NC}"
        echo "请使用 sudo 或以 root 用户身份运行此脚本。"
        exit 1
    fi
}

# Function to detect OS and architecture
detect_system() {
    OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH_TYPE=$(uname -m)
    
    case $OS_TYPE in
        linux)
            case $ARCH_TYPE in
                x86_64) NODE_EXPORTER_ARCH="amd64";;
                aarch64) NODE_EXPORTER_ARCH="arm64";;
                armv*) NODE_EXPORTER_ARCH="armv${ARCH_TYPE:4}";; # Handles armv5, armv6, armv7
                i?86) NODE_EXPORTER_ARCH="386";;
                mips64*) NODE_EXPORTER_ARCH="mips64";; # Check mips64 first
                mips*) NODE_EXPORTER_ARCH="mips";;     # Then check mips
                *) echo -e "${RED}错误：不支持的 Linux 架构 '$ARCH_TYPE'${NC}"; exit 1;;
            esac
            ;;
        darwin)
             case $ARCH_TYPE in
                x86_64) NODE_EXPORTER_ARCH="amd64";;
                arm64) NODE_EXPORTER_ARCH="arm64";; # For Apple Silicon Macs
                *) echo -e "${RED}错误：不支持的 Darwin (macOS) 架构 '$ARCH_TYPE'${NC}"; exit 1;;
            esac
            ;;
        *)
            echo -e "${RED}错误：不支持的操作系统 '$OS_TYPE'${NC}"
            exit 1
            ;;
    esac
    
    # Set base URL and filename
    BASE_DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download"
    NODE_EXPORTER_FILENAME="node_exporter-${NODE_EXPORTER_VERSION}.${OS_TYPE}-${NODE_EXPORTER_ARCH}.tar.gz"
    DOWNLOAD_URL="${BASE_DOWNLOAD_URL}/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_FILENAME}"
    EXTRACTED_DIR="node_exporter-${NODE_EXPORTER_VERSION}.${OS_TYPE}-${NODE_EXPORTER_ARCH}"
    
    echo -e "${CYAN}检测到操作系统: ${NC}$OS_TYPE"
    echo -e "${CYAN}检测到架构: ${NC}$ARCH_TYPE (映射为: $NODE_EXPORTER_ARCH)"
}

# Function to parse command line arguments
parse_args() {
    # Default values
    OPERATION="menu"
    USER_PORT=$DEFAULT_PORT
    CERT_FILE=""
    CERT_KEY_FILE=""
    USER_NAME=""
    USER_PWD_HASH=""
    BACKUP_FILE=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --menu|-m)
                OPERATION="menu"
                shift
                ;;
            --install|-i)
                OPERATION="install"
                shift
                ;;
            --uninstall|-u)
                OPERATION="uninstall"
                shift
                ;;
            --status|-s)
                OPERATION="status"
                shift
                ;;
            --restart|-r)
                OPERATION="restart"
                shift
                ;;
            --config|-c)
                OPERATION="config"
                shift
                ;;
            --backup|-b)
                OPERATION="backup"
                shift
                ;;
            --restore)
                OPERATION="restore"
                shift
                ;;
            --port=*)
                USER_PORT="${1#*=}"
                shift
                ;;
            --tls-cert=*)
                CERT_FILE="${1#*=}"
                shift
                ;;
            --tls-key=*)
                CERT_KEY_FILE="${1#*=}"
                shift
                ;;
            --auth-user=*)
                USER_NAME="${1#*=}"
                shift
                ;;
            --auth-hash=*)
                USER_PWD_HASH="${1#*=}"
                shift
                ;;
            --file=*)
                BACKUP_FILE="${1#*=}"
                shift
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate parameters
    if [[ "$OPERATION" == "install" ]]; then
        if [[ -n "$CERT_FILE" && -z "$CERT_KEY_FILE" ]]; then
            echo -e "${RED}错误: 指定了 TLS 证书但未指定密钥文件。${NC}"
            exit 1
        fi
        
        if [[ -n "$USER_NAME" && -z "$USER_PWD_HASH" ]]; then
            echo -e "${RED}错误: 指定了 Basic Auth 用户名但未指定密码哈希。${NC}"
            exit 1
        fi
    fi
    
    if [[ "$OPERATION" == "restore" && -z "$BACKUP_FILE" ]]; then
        echo -e "${RED}错误: 需要使用 --file=PATH 指定要恢复的备份文件。${NC}"
        exit 1
    fi
}
# Function to show main menu
show_menu() {
    clear
    display_logo
    
    echo -e "${CYAN}请选择一个操作:${NC}"
    echo -e "${GREEN}1)${NC} 全新安装 Node Exporter"
    echo -e "${GREEN}2)${NC} 卸载 Node Exporter"
    echo -e "${GREEN}3)${NC} 查看 Node Exporter 状态"
    echo -e "${GREEN}4)${NC} 重启 Node Exporter 服务"
    echo -e "${GREEN}5)${NC} 更新 Node Exporter 配置"
    echo -e "${GREEN}6)${NC} 备份当前配置"
    echo -e "${GREEN}7)${NC} 恢复配置备份"
    echo -e "${RED}0)${NC} 退出"
    
    read -p "请输入选项 [0-7]: " choice
    
    case $choice in
        1) install_node_exporter_interactive ;;
        2) uninstall_node_exporter_interactive ;;
        3) check_status ;;
        4) restart_service ;;
        5) update_config_interactive ;;
        6) backup_config_interactive ;;
        7) restore_config_interactive ;;
        0) exit 0 ;;
        *) 
            echo -e "${RED}无效选项，请重试.${NC}"
            sleep 2
            show_menu
            ;;
    esac
}

# Function for interactive installation
install_node_exporter_interactive() {
    clear
    display_logo
    echo -e "${CYAN}===== 安装 Node Exporter v${NODE_EXPORTER_VERSION} =====${NC}"
    
    # Detect system
    detect_system
    
    # User input
    read -p "请输入 cert file 全路径 (留空则不启用 TLS): " CERT_FILE
    if [[ -n "$CERT_FILE" ]]; then
        read -p "请输入 cert key file 全路径: " CERT_KEY_FILE
        if [[ -z "$CERT_KEY_FILE" ]]; then
            echo -e "${RED}错误：指定了 cert file 但未指定 cert key file。${NC}"
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
            return
        fi
    fi

    read -p "请输入端口号 (默认 $DEFAULT_PORT): " USER_PORT_INPUT
    USER_PORT=${USER_PORT_INPUT:-$DEFAULT_PORT}

    read -p "请输入 basic auth 用户名 (留空则不启用): " USER_NAME
    if [[ -n "$USER_NAME" ]]; then
        echo "请为用户 '$USER_NAME' 生成 bcrypt 哈希密码。"
        echo -e "${YELLOW}可以使用在线工具（如 https://bcrypt-generator.com/ 或 https://bfotool.com/zh/bcrypt-hash-generator），推荐使用 10 rounds。${NC}"
        read -p "请输入 bcrypt 哈希密码: " USER_PWD_HASH
        if [[ -z "$USER_PWD_HASH" ]]; then
            echo -e "${RED}错误：指定了用户名但未指定密码哈希。${NC}"
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
            return
        fi
    fi
    
    # Call the main installation function
    install_node_exporter
    
    read -p "按 Enter 键返回主菜单..." dummy
    show_menu
}

# Function for interactive uninstallation
uninstall_node_exporter_interactive() {
    clear
    display_logo
    echo -e "${CYAN}===== 卸载 Node Exporter =====${NC}"
    
    read -p "确定要卸载 Node Exporter 吗? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}卸载已取消。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi
    
    # Ask if user wants to keep configuration files
    read -p "是否保留配置文件? (y/n, 默认: n): " keep_config
    KEEP_CONFIG=0
    if [[ "$keep_config" == "y" || "$keep_config" == "Y" ]]; then
        KEEP_CONFIG=1
    fi
    
    # Ask if user wants to remove the node_exporter user
    read -p "是否删除 node_exporter 用户? (y/n, 默认: n): " remove_user
    REMOVE_USER=0
    if [[ "$remove_user" == "y" || "$remove_user" == "Y" ]]; then
        REMOVE_USER=1
    fi
    
    # Call the main uninstallation function
    uninstall_node_exporter $KEEP_CONFIG $REMOVE_USER
    
    read -p "按 Enter 键返回主菜单..." dummy
    show_menu
}

# Function for interactive configuration update
update_config_interactive() {
    clear
    display_logo
    echo -e "${CYAN}===== 更新 Node Exporter 配置 =====${NC}"
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi
    
    # Show current configuration
    current_port=$(grep -oP -- "--web.listen-address=:\K[0-9]+" "$SERVICE_FILE" || echo "$DEFAULT_PORT")
    echo -e "${CYAN}当前端口: ${NC}$current_port"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}当前配置文件: ${NC}$CONFIG_FILE"
        echo -e "${CYAN}配置内容:${NC}"
        cat "$CONFIG_FILE"
    else
        echo -e "${YELLOW}当前未使用配置文件。${NC}"
    fi
    
    # Update port
    read -p "输入新端口 (留空则保持当前端口 $current_port): " new_port
    USER_PORT=${new_port:-$current_port}
    
    # TLS configuration
    read -p "更新 TLS 配置? (y/n, 默认: n): " update_tls
    CERT_FILE=""
    CERT_KEY_FILE=""
    if [[ "$update_tls" == "y" || "$update_tls" == "Y" ]]; then
        read -p "请输入 cert file 全路径 (留空则禁用 TLS): " CERT_FILE
        if [[ -n "$CERT_FILE" ]]; then
            read -p "请输入 cert key file 全路径: " CERT_KEY_FILE
            if [[ -z "$CERT_KEY_FILE" ]]; then
                echo -e "${RED}错误：指定了 cert file 但未指定 cert key file。${NC}"
                read -p "按 Enter 键返回主菜单..." dummy
                show_menu
                return
            fi
        fi
    fi
    
    # Basic Auth configuration
    read -p "更新 Basic Auth 配置? (y/n, 默认: n): " update_auth
    USER_NAME=""
    USER_PWD_HASH=""
    if [[ "$update_auth" == "y" || "$update_auth" == "Y" ]]; then
        read -p "请输入 basic auth 用户名 (留空则禁用): " USER_NAME
        if [[ -n "$USER_NAME" ]]; then
            echo "请为用户 '$USER_NAME' 生成 bcrypt 哈希密码。"
            echo -e "${YELLOW}可以使用在线工具（如 https://bcrypt-generator.com/ 或 https://bfotool.com/zh/bcrypt-hash-generator），推荐使用 10 rounds。${NC}"
            read -p "请输入 bcrypt 哈希密码: " USER_PWD_HASH
            if [[ -z "$USER_PWD_HASH" ]]; then
                echo -e "${RED}错误：指定了用户名但未指定密码哈希。${NC}"
                read -p "按 Enter 键返回主菜单..." dummy
                show_menu
                return
            fi
        fi
    fi
    
    # Call the main update function
    update_config
    
    read -p "按 Enter 键返回主菜单..." dummy
    show_menu
}

# Interactive backup function
backup_config_interactive() {
    clear
    display_logo
    echo -e "${CYAN}===== 备份 Node Exporter 配置 =====${NC}"
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi
    
    # Let user specify backup directory
    read -p "请输入备份文件保存路径 (默认: ./node_exporter_backup): " backup_dir
    backup_dir=${backup_dir:-"./node_exporter_backup"}
    
    # Call the main backup function
    backup_config "$backup_dir"
    
    read -p "按 Enter 键返回主菜单..." dummy
    show_menu
}

# Interactive restore function
restore_config_interactive() {
    clear
    display_logo
    echo -e "${CYAN}===== 恢复 Node Exporter 配置 =====${NC}"
    
    # Let user specify backup file
    read -p "请输入要恢复的备份文件路径: " backup_file
    if [ -z "$backup_file" ]; then
        echo -e "${RED}错误: 未指定备份文件。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}错误: 备份文件 '$backup_file' 不存在。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi
    
    # Call the main restore function
    restore_config "$backup_file"
    
    read -p "按 Enter 键返回主菜单..." dummy
    show_menu
}
# Function to install Node Exporter
install_node_exporter() {
    # If not called from interactive mode, show header
    if [ "$OPERATION" != "menu" ]; then
        clear
        display_logo
        echo -e "${CYAN}===== 安装 Node Exporter v${NODE_EXPORTER_VERSION} =====${NC}"
        detect_system
    fi
    
    # Create a temporary directory for download and extraction
    TMP_DIR=$(mktemp -d)
    echo -e "${CYAN}使用临时目录: ${NC}$TMP_DIR"
    cd "$TMP_DIR"

    # Download
    echo -e "\n${YELLOW}--- 开始下载 ---${NC}"
    echo -e "${CYAN}正在下载 ${NC}$DOWNLOAD_URL ..."
    if command -v wget &> /dev/null; then
        wget -q --show-progress "$DOWNLOAD_URL" || { echo -e "${RED}下载失败！${NC}"; exit 1; }
    elif command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$NODE_EXPORTER_FILENAME" "$DOWNLOAD_URL" || { echo -e "${RED}下载失败！${NC}"; exit 1; }
    else
        echo -e "${RED}错误: 需要 wget 或 curl 来下载文件。${NC}"
        exit 1
    fi

    # Extract
    echo -e "\n${YELLOW}--- 开始解压 ---${NC}"
    tar xvfz "$NODE_EXPORTER_FILENAME"
    cd "$EXTRACTED_DIR"

    # Create node_exporter user and group if they don't exist
    echo -e "\n${YELLOW}--- 开始设置用户权限 ---${NC}"
    if ! id "$NODE_EXPORTER_USER" &>/dev/null; then
        echo -e "${CYAN}创建用户 '$NODE_EXPORTER_USER'...${NC}"
        useradd --system --no-create-home --shell /bin/false "$NODE_EXPORTER_USER"
    else
        echo -e "${CYAN}用户 '$NODE_EXPORTER_USER' 已存在。${NC}"
    fi

    # Create installation directory and config file
    echo -e "\n${YELLOW}--- 开始创建配置文件 ---${NC}"
    mkdir -p "$INSTALL_DIR"
    
    # Generate config only if TLS or Basic Auth is enabled
    if [[ -n "$CERT_FILE" || -n "$USER_NAME" ]]; then
        echo -e "${CYAN}生成配置文件 $CONFIG_FILE ...${NC}"
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
        echo -e "${CYAN}未启用 TLS 或 Basic Auth，不创建配置文件。${NC}"
    fi

    # Copy node_exporter binary and set ownership
    echo -e "\n${YELLOW}--- 开始复制二进制文件 ---${NC}"
    cp -f ./node_exporter "$BIN_PATH"
    chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$BIN_PATH"
    chmod 755 "$BIN_PATH"

    # Set certificate ownership and permissions if TLS is enabled
    if [[ -n "$CERT_FILE" ]]; then
        echo -e "\n${YELLOW}--- 开始设置证书权限 ---${NC}"
        # Check if files exist before changing permissions
        if [[ -f "$CERT_FILE" && -f "$CERT_KEY_FILE" ]]; then
            chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$CERT_FILE" "$CERT_KEY_FILE"
            # Key file should be more restricted
            chmod 640 "$CERT_FILE"
            chmod 600 "$CERT_KEY_FILE"
            echo -e "${CYAN}证书权限已设置。${NC}"
        else
            echo -e "${RED}错误：证书文件 $CERT_FILE 或 $CERT_KEY_FILE 不存在！${NC}"
        fi
    fi

    # Create or update systemd service file
    echo -e "\n${YELLOW}--- 开始设置 systemd 服务 ---${NC}"
    # Base ExecStart command
    EXEC_START="/usr/local/bin/node_exporter --web.listen-address=:$USER_PORT"
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

# Reload systemd, enable and start service
    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    
    # Clean up
    echo -e "\n${YELLOW}--- 开始清理临时文件 ---${NC}"
    cd "$OLDPWD"
    rm -rf "$TMP_DIR"
    
    echo -e "\n${GREEN}Node Exporter v${NODE_EXPORTER_VERSION} 安装完成！${NC}"
    echo -e "状态检查:"
    systemctl status node_exporter --no-pager
    
    echo -e "\n${CYAN}访问指南:${NC}"
    echo -e "- Metrics URL: http://$(hostname -I | awk '{print $1}'):$USER_PORT/metrics"
    if [[ -n "$CERT_FILE" ]]; then
        echo -e "- HTTPS 已启用，请使用 https:// 访问"
    fi
    if [[ -n "$USER_NAME" ]]; then
        echo -e "- Basic Auth 已启用，使用用户名: $USER_NAME"
    fi
}

# Function to uninstall Node Exporter
uninstall_node_exporter() {
    local keep_config=$1
    local remove_user=$2
    
    # If not called from interactive mode, set defaults and show header
    if [ "$OPERATION" != "menu" ]; then
        clear
        display_logo
        echo -e "${CYAN}===== 卸载 Node Exporter =====${NC}"
        keep_config=0
        remove_user=0
    fi
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}Node Exporter 服务文件不存在，可能未安装。${NC}"
        return
    fi
    
    echo -e "${CYAN}停止并禁用 Node Exporter 服务...${NC}"
    systemctl stop node_exporter
    systemctl disable node_exporter
    
    echo -e "${CYAN}删除 Node Exporter 服务文件...${NC}"
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    
    echo -e "${CYAN}删除 Node Exporter 二进制文件...${NC}"
    rm -f "$BIN_PATH"
    
    if [ "$keep_config" -eq 0 ]; then
        echo -e "${CYAN}删除 Node Exporter 配置目录...${NC}"
        rm -rf "$INSTALL_DIR"
    else
        echo -e "${CYAN}保留 Node Exporter 配置目录...${NC}"
    fi
    
    if [ "$remove_user" -eq 1 ]; then
        echo -e "${CYAN}删除 node_exporter 用户...${NC}"
        userdel "$NODE_EXPORTER_USER"
    fi
    
    echo -e "${GREEN}Node Exporter 已卸载！${NC}"
}

# Function to check Node Exporter status
check_status() {
    clear
    display_logo
    echo -e "${CYAN}===== Node Exporter 状态 =====${NC}"
    
    # Check if service file exists
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        if [ "$OPERATION" == "menu" ]; then
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
        fi
        return
    fi
    
    # Display systemd status
    echo -e "${CYAN}服务状态:${NC}"
    systemctl status node_exporter --no-pager
    
    # Show listening port
    echo -e "\n${CYAN}监听端口:${NC}"
    PORT=$(grep -oP -- "--web.listen-address=:\K[0-9]+" "$SERVICE_FILE" || echo "$DEFAULT_PORT")
    echo -e "Node Exporter 正在端口 $PORT 上监听"
    
    # Check if port is actually in use
    if command -v ss &> /dev/null; then
        SS_OUTPUT=$(ss -lnpt | grep ":$PORT")
        if [ -n "$SS_OUTPUT" ]; then
            echo -e "${GREEN}端口 $PORT 已被 Node Exporter 占用:${NC}"
            echo "$SS_OUTPUT"
        else
            echo -e "${RED}警告: 端口 $PORT 未被占用，服务可能未正常运行!${NC}"
        fi
    elif command -v netstat &> /dev/null; then
        NETSTAT_OUTPUT=$(netstat -lnpt | grep ":$PORT")
        if [ -n "$NETSTAT_OUTPUT" ]; then
            echo -e "${GREEN}端口 $PORT 已被 Node Exporter 占用:${NC}"
            echo "$NETSTAT_OUTPUT"
        else
            echo -e "${RED}警告: 端口 $PORT 未被占用，服务可能未正常运行!${NC}"
        fi
    else
        echo -e "${YELLOW}无法检查端口状态，请安装 ss 或 netstat 工具。${NC}"
    fi
    
    # Show configuration file
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "\n${CYAN}配置文件:${NC} $CONFIG_FILE"
        echo -e "${CYAN}配置内容:${NC}"
        cat "$CONFIG_FILE"
    else
        echo -e "\n${YELLOW}未使用配置文件。${NC}"
    fi
    
    # Check metrics endpoint
    echo -e "\n${CYAN}检查 metrics 端点可访问性:${NC}"
    if command -v curl &> /dev/null; then
        # Test HTTP response code
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/metrics)
        if [ "$HTTP_CODE" == "200" ]; then
            echo -e "${GREEN}✓ Metrics 端点可访问 (HTTP $HTTP_CODE)${NC}"
        elif [ "$HTTP_CODE" == "401" ]; then
            echo -e "${YELLOW}→ Metrics 端点返回 401 Unauthorized，需要认证${NC}"
        else
            echo -e "${RED}✗ Metrics 端点返回 HTTP $HTTP_CODE${NC}"
        fi
    else
        echo -e "${YELLOW}未安装 curl，无法检查 metrics 端点。${NC}"
    fi
    
    # Show hints
    echo -e "\n${CYAN}访问指南:${NC}"
    IP=$(hostname -I | awk '{print $1}')
    echo -e "- Metrics URL: http://$IP:$PORT/metrics"
    if grep -q "tls_server_config:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "- HTTPS 已启用，请使用 https:// 访问"
    fi
    if grep -q "basic_auth_users:" "$CONFIG_FILE" 2>/dev/null; then
        USER=$(grep -oP "basic_auth_users:\s+\K[a-zA-Z0-9_]+" "$CONFIG_FILE" 2>/dev/null)
        echo -e "- Basic Auth 已启用，使用用户名: $USER"
    fi
    
    if [ "$OPERATION" == "menu" ]; then
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
    fi
}

# Function to restart Node Exporter service
restart_service() {
    clear
    display_logo
    echo -e "${CYAN}===== 重启 Node Exporter 服务 =====${NC}"
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        if [ "$OPERATION" == "menu" ]; then
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
        fi
        return
    fi
    
    echo -e "${CYAN}重启 Node Exporter 服务...${NC}"
    systemctl restart node_exporter
    
    echo -e "${CYAN}服务状态:${NC}"
    systemctl status node_exporter --no-pager
    
    if [ "$OPERATION" == "menu" ]; then
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
    fi
}

# Function to update Node Exporter configuration
update_config() {
    # If not called from interactive mode, show header
    if [ "$OPERATION" != "menu" ]; then
        clear
        display_logo
        echo -e "${CYAN}===== 更新 Node Exporter 配置 =====${NC}"
    fi
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        return
    fi
    
    # Update configuration file
    if [[ -n "$CERT_FILE" || -n "$USER_NAME" ]]; then
        echo -e "${CYAN}更新配置文件 $CONFIG_FILE ...${NC}"
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
        
        # Set certificate ownership and permissions if TLS is enabled
        if [[ -n "$CERT_FILE" ]]; then
            echo -e "${CYAN}更新证书权限...${NC}"
            # Check if files exist before changing permissions
            if [[ -f "$CERT_FILE" && -f "$CERT_KEY_FILE" ]]; then
                chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$CERT_FILE" "$CERT_KEY_FILE"
                # Key file should be more restricted
                chmod 640 "$CERT_FILE"
                chmod 600 "$CERT_KEY_FILE"
                echo -e "${CYAN}证书权限已更新。${NC}"
            else
                echo -e "${RED}错误：证书文件 $CERT_FILE 或 $CERT_KEY_FILE 不存在！${NC}"
            fi
        fi
    else
        # If both TLS and Basic Auth are disabled, remove config file if it exists
        if [ -f "$CONFIG_FILE" ]; then
            echo -e "${CYAN}未启用 TLS 或 Basic Auth，移除配置文件...${NC}"
            rm -f "$CONFIG_FILE"
        else
            echo -e "${CYAN}未启用 TLS 或 Basic Auth，不更新配置文件。${NC}"
        fi
    fi
    
    # Update systemd service file
    echo -e "${CYAN}更新 systemd 服务文件...${NC}"
    # Base ExecStart command
    EXEC_START="/usr/local/bin/node_exporter --web.listen-address=:$USER_PORT"
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
    
    # Reload systemd and restart service
    echo -e "${CYAN}重新加载 systemd 并重启服务...${NC}"
    systemctl daemon-reload
    systemctl restart node_exporter
    
    echo -e "${GREEN}Node Exporter 配置已更新！${NC}"
    echo -e "状态检查:"
    systemctl status node_exporter --no-pager
}

# Function to backup configuration
backup_config() {
    local backup_dir=$1
    
    # If not called from interactive mode, show header
    if [ "$OPERATION" != "menu" ]; then
        clear
        display_logo
        echo -e "${CYAN}===== 备份 Node Exporter 配置 =====${NC}"
    fi
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        return
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    # Generate timestamp
    TIMESTAMP=$(date "+%Y%m%d-%H%M%S")
    BACKUP_FILE="$backup_dir/node_exporter_backup_$TIMESTAMP.tar.gz"
    
    # Create temporary directory for backup files
    TMP_BACKUP_DIR=$(mktemp -d)
    
    # Copy files to temporary directory
    echo -e "${CYAN}收集配置文件...${NC}"
    cp -f "$SERVICE_FILE" "$TMP_BACKUP_DIR/"
    if [ -f "$CONFIG_FILE" ]; then
        cp -f "$CONFIG_FILE" "$TMP_BACKUP_DIR/"
    fi
    
    # Create manifest file with information
    cat <<EOF > "$TMP_BACKUP_DIR/manifest.txt"
Node Exporter Backup
Created: $(date)
Node Exporter Version: $NODE_EXPORTER_VERSION
Service File: $SERVICE_FILE
Config File: $CONFIG_FILE
User: $NODE_EXPORTER_USER
Port: $(grep -oP -- "--web.listen-address=:\K[0-9]+" "$SERVICE_FILE" || echo "$DEFAULT_PORT")
EOF

    # Create tar archive
    echo -e "${CYAN}创建备份文件 $BACKUP_FILE ...${NC}"
    tar -czf "$BACKUP_FILE" -C "$TMP_BACKUP_DIR" .
    
    # Clean up
    rm -rf "$TMP_BACKUP_DIR"
    
    echo -e "${GREEN}备份完成: $BACKUP_FILE${NC}"
}

# Function to restore configuration from backup
restore_config() {
    local backup_file=$1
    
    # If not called from interactive mode, show header
    if [ "$OPERATION" != "menu" ]; then
        clear
        display_logo
        echo -e "${CYAN}===== 恢复 Node Exporter 配置 =====${NC}"
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}错误: 备份文件 '$backup_file' 不存在。${NC}"
        return
    fi
    
    # Create temporary directory for extraction
    TMP_RESTORE_DIR=$(mktemp -d)
    
    echo -e "${CYAN}解压备份文件...${NC}"
    tar -xzf "$backup_file" -C "$TMP_RESTORE_DIR"
    
    # Check if required files exist in backup
    if [ ! -f "$TMP_RESTORE_DIR/$(basename $SERVICE_FILE)" ]; then
        echo -e "${RED}错误: 备份文件中缺少服务文件。${NC}"
        rm -rf "$TMP_RESTORE_DIR"
        return
    fi
    
    echo -e "${CYAN}显示备份信息:${NC}"
    if [ -f "$TMP_RESTORE_DIR/manifest.txt" ]; then
        cat "$TMP_RESTORE_DIR/manifest.txt"
    else
        echo -e "${YELLOW}备份中没有 manifest 文件。${NC}"
    fi
    
    # Create node_exporter user if it doesn't exist
    if ! id "$NODE_EXPORTER_USER" &>/dev/null; then
        echo -e "${CYAN}创建用户 '$NODE_EXPORTER_USER'...${NC}"
        useradd --system --no-create-home --shell /bin/false "$NODE_EXPORTER_USER"
    fi
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Restore service file
    echo -e "${CYAN}恢复服务文件...${NC}"
    cp -f "$TMP_RESTORE_DIR/$(basename $SERVICE_FILE)" "$SERVICE_FILE"
    
    # Restore config file if it exists in backup
    if [ -f "$TMP_RESTORE_DIR/$(basename $CONFIG_FILE)" ]; then
        echo -e "${CYAN}恢复配置文件...${NC}"
        cp -f "$TMP_RESTORE_DIR/$(basename $CONFIG_FILE)" "$CONFIG_FILE"
        chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
    
    # Clean up
    rm -rf "$TMP_RESTORE_DIR"
    
    # Reload systemd
    echo -e "${CYAN}重新加载 systemd ...${NC}"
    systemctl daemon-reload
    
    # Check if Node Exporter is installed
    if [ -f "$BIN_PATH" ]; then
        echo -e "${CYAN}重启 Node Exporter 服务...${NC}"
        systemctl restart node_exporter
        echo -e "${GREEN}Node Exporter 配置已恢复并重启！${NC}"
    else
        echo -e "${YELLOW}警告: Node Exporter 二进制文件不存在，需要重新安装。${NC}"
        echo -e "${YELLOW}配置已恢复，但服务未启动。${NC}"
    fi
}

# Main function
main() {
    check_root
    parse_args "$@"
    
    case "$OPERATION" in
        menu)
            show_menu
            ;;
        install)
            install_node_exporter
            ;;
        uninstall)
            uninstall_node_exporter 0 0
            ;;
        status)
            check_status
            ;;
        restart)
            restart_service
            ;;
        config)
            update_config
            ;;
        backup)
            backup_config "${BACKUP_FILE:-./node_exporter_backup}"
            ;;
        restore)
            restore_config "$BACKUP_FILE"
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"