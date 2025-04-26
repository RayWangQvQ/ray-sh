#!/bin/bash
###
# @Author: Ray
# @Date: 2024-05-19 12:34:11
# @LastEditors: Ray
# @LastEditTime: 2025-04-26
# @Description: Manages Node Exporter - install, uninstall, status check, and configuration.
# @Modified: 支持非root用户安装, 优化启动和停止逻辑, 移除默认假路径
###

set -e
set -o pipefail

# Constants
NODE_EXPORTER_VERSION="1.9.1" # Specify the desired Node Exporter version
SCRIPT_VERSION="2025-04-26" # Version of this script

# 非root用户使用自己的主目录
HOME_DIR="$HOME"
INSTALL_DIR="$HOME_DIR/.node_exporter"
BIN_PATH="$INSTALL_DIR/bin/node_exporter"
SERVICE_FILE="$INSTALL_DIR/node_exporter.service"
CONFIG_FILE="$INSTALL_DIR/config.yml"
PID_FILE="$INSTALL_DIR/node_exporter.pid"
LOG_FILE="$INSTALL_DIR/node_exporter.log"
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
    echo -e "  ${GREEN}--restore${NC}          恢复配置备份 (使用 --file=PATH)"
    echo -e "  ${GREEN}--start${NC}            启动 Node Exporter"
    echo -e "  ${GREEN}--stop${NC}             停止 Node Exporter"
    echo -e "\n${CYAN}安装/配置选项:${NC}"
    echo -e "  ${GREEN}--port=PORT${NC}        指定端口号 (默认: $DEFAULT_PORT，非root用户需要 >1024)"
    echo -e "  ${GREEN}--tls-cert=FILE${NC}    指定 TLS 证书文件路径"
    echo -e "  ${GREEN}--tls-key=FILE${NC}     指定 TLS 密钥文件路径"
    echo -e "  ${GREEN}--auth-user=USER${NC}   指定 Basic Auth 用户名"
    echo -e "  ${GREEN}--auth-hash=HASH${NC}   指定 Basic Auth 密码哈希值 (完整的 bcrypt 哈希)"
    echo -e "\n${YELLOW}示例:${NC}"
    echo -e "  $0 --install --port=9100"
    echo -e "  $0 --install --tls-cert=/path/to/cert.pem --tls-key=/path/to/key.pem"
    echo -e "  $0 --status"
    echo -e "  $0 --uninstall"
    echo -e "  $0 --restore --file=~/node_exporter_backup_xxxx.tar.gz"
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
    echo -e "\033[1m\033[38;5;226m        » Node Exporter Manager (非root版) «        \033[0m"
    sleep 0.5
    echo -e "\033[1m\033[38;5;118m        » Manager Version: $SCRIPT_VERSION «         \033[0m"
    echo -e "\033[1m\033[38;5;118m        » Node Exporter Version: v${NODE_EXPORTER_VERSION}  «         \033[0m"
    echo -e "\033[38;5;208m════════════════════════════════════════════════════════════════════\033[0m"
    echo ""
}

# Function to check port permissions
check_port_permissions() {
    local port=$1

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}错误: 端口号 '$port' 无效。请输入 1-65535 之间的数字。${NC}"
        return 1
    fi

    if [ $port -le 1024 ] && [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 非root用户不能使用 1-1024 端口范围。${NC}"
        echo -e "${YELLOW}请选择大于 1024 的端口。${NC}"
        return 1
    fi

    return 0
}

# Function to detect OS and architecture
detect_system() {
    OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH_TYPE=$(uname -m)

    case $OS_TYPE in
    linux)
        case $ARCH_TYPE in
        x86_64) NODE_EXPORTER_ARCH="amd64" ;;
        aarch64) NODE_EXPORTER_ARCH="arm64" ;;
        armv*) NODE_EXPORTER_ARCH="armv${ARCH_TYPE:4}" ;; # Handles armv5, armv6, armv7
        i?86) NODE_EXPORTER_ARCH="386" ;;
        mips64*) NODE_EXPORTER_ARCH="mips64" ;; # Check mips64 first
        mips*) NODE_EXPORTER_ARCH="mips" ;;     # Then check mips
        *)
            echo -e "${RED}错误：不支持的 Linux 架构 '$ARCH_TYPE'${NC}"
            exit 1
            ;;
        esac
        ;;
    darwin)
        case $ARCH_TYPE in
        x86_64) NODE_EXPORTER_ARCH="amd64" ;;
        arm64) NODE_EXPORTER_ARCH="arm64" ;; # For Apple Silicon Macs
        *)
            echo -e "${RED}错误：不支持的 Darwin (macOS) 架构 '$ARCH_TYPE'${NC}"
            exit 1
            ;;
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
        --help | -h)
            show_help
            exit 0
            ;;
        --menu | -m)
            OPERATION="menu"
            shift
            ;;
        --install | -i)
            OPERATION="install"
            shift
            ;;
        --uninstall | -u)
            OPERATION="uninstall"
            shift
            ;;
        --status | -s)
            OPERATION="status"
            shift
            ;;
        --restart | -r)
            OPERATION="restart"
            shift
            ;;
        --config | -c)
            OPERATION="config"
            shift
            ;;
        --backup | -b)
            OPERATION="backup"
            shift
            ;;
        --restore)
            OPERATION="restore"
            shift
            ;;
        --start)
            OPERATION="start"
            shift
            ;;
        --stop)
            OPERATION="stop"
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
        --file=*) # Used for restore
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
    if [[ "$OPERATION" == "install" || "$OPERATION" == "config" ]]; then
        if [[ -n "$CERT_FILE" && -z "$CERT_KEY_FILE" ]]; then
            echo -e "${RED}错误: 指定了 TLS 证书但未指定密钥文件。${NC}"
            exit 1
        fi
        if [[ -z "$CERT_FILE" && -n "$CERT_KEY_FILE" ]]; then
             echo -e "${RED}错误: 指定了 TLS 密钥文件但未指定证书文件。${NC}"
             exit 1
        fi
         if [[ -n "$CERT_FILE" && ! -f "$CERT_FILE" ]]; then
             echo -e "${RED}错误: TLS 证书文件 '$CERT_FILE' 不存在或无法读取。${NC}"
             exit 1
         fi
          if [[ -n "$CERT_KEY_FILE" && ! -f "$CERT_KEY_FILE" ]]; then
              echo -e "${RED}错误: TLS 密钥文件 '$CERT_KEY_FILE' 不存在或无法读取。${NC}"
              exit 1
          fi

        if [[ -n "$USER_NAME" && -z "$USER_PWD_HASH" ]]; then
            echo -e "${RED}错误: 指定了 Basic Auth 用户名但未指定密码哈希。${NC}"
            exit 1
        fi
        if [[ -z "$USER_NAME" && -n "$USER_PWD_HASH" ]]; then
            echo -e "${RED}错误: 指定了 Basic Auth 密码哈希但未指定用户名。${NC}"
            exit 1
        fi

        # Check port permissions
        check_port_permissions "$USER_PORT" || exit 1
    fi

    if [[ "$OPERATION" == "restore" && -z "$BACKUP_FILE" ]]; then
        echo -e "${RED}错误: 恢复操作需要使用 --file=PATH 指定要恢复的备份文件。${NC}"
        exit 1
    fi
    if [[ "$OPERATION" == "restore" && ! -f "$BACKUP_FILE" ]]; then
        echo -e "${RED}错误: 备份文件 '$BACKUP_FILE' 不存在。${NC}"
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
    echo -e "${GREEN}4)${NC} 启动 Node Exporter"
    echo -e "${GREEN}5)${NC} 停止 Node Exporter"
    echo -e "${GREEN}6)${NC} 重启 Node Exporter"
    echo -e "${GREEN}7)${NC} 更新 Node Exporter 配置"
    echo -e "${GREEN}8)${NC} 备份当前配置"
    echo -e "${GREEN}9)${NC} 恢复配置备份"
    echo -e "${RED}0)${NC} 退出"

    read -p "请输入选项 [0-9]: " choice

    case $choice in
    1) install_node_exporter_interactive ;;
    2) uninstall_node_exporter_interactive ;;
    3) check_status ;;
    4) start_node_exporter ;;
    5) stop_node_exporter ;;
    6) restart_service ;;
    7) update_config_interactive ;;
    8) backup_config_interactive ;;
    9) restore_config_interactive ;;
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
    while true; do
      read -p "请输入端口号 (默认 $DEFAULT_PORT，非root用户请使用 >1024 的端口): " USER_PORT_INPUT
      USER_PORT=${USER_PORT_INPUT:-$DEFAULT_PORT}
      if check_port_permissions "$USER_PORT"; then
        break
      fi
    done

    read -p "请输入 TLS cert file 全路径 (留空则不启用 TLS): " CERT_FILE
    if [[ -n "$CERT_FILE" ]]; then
        # Basic existence check
        if [ ! -f "$CERT_FILE" ]; then
            echo -e "${RED}错误: 证书文件 '$CERT_FILE' 不存在。${NC}"
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
            return
        fi
        while true; do
            read -p "请输入 TLS cert key file 全路径: " CERT_KEY_FILE
            if [[ -z "$CERT_KEY_FILE" ]]; then
                 echo -e "${RED}错误：必须指定 cert key file。${NC}"
            elif [ ! -f "$CERT_KEY_FILE" ]; then
                echo -e "${RED}错误: 密钥文件 '$CERT_KEY_FILE' 不存在。${NC}"
            else
                break # Valid key file provided
            fi
        done
    else
        CERT_KEY_FILE="" # Ensure key file is empty if cert file is empty
    fi

    read -p "请输入 basic auth 用户名 (留空则不启用): " USER_NAME
    if [[ -n "$USER_NAME" ]]; then
        echo "请为用户 '$USER_NAME' 生成 bcrypt 哈希密码。"
        echo -e "${YELLOW}可以使用在线工具（如 https://bcrypt-generator.com/ 或 https://bfotool.com/zh/bcrypt-hash-generator），推荐使用 10 rounds。${NC}"
        echo -e "${YELLOW}重要: 请复制并粘贴完整的哈希字符串 (通常以 '$2a$' 或 '$2b$' 开头)。${NC}"
        while true; do
            read -p "请输入完整的 bcrypt 哈希密码: " USER_PWD_HASH
            if [[ -z "$USER_PWD_HASH" ]]; then
                echo -e "${RED}错误：必须指定密码哈希。${NC}"
            else
                break # Hash provided
            fi
        done
    else
         USER_PWD_HASH="" # Ensure hash is empty if user is empty
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

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}Node Exporter 似乎未安装。${NC}"
         read -p "按 Enter 键返回主菜单..." dummy
         show_menu
         return
    fi

    read -p "确定要卸载 Node Exporter 吗? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}卸载已取消。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi

    # Ask if user wants to keep configuration files
    read -p "是否保留配置文件 (config.yml, node_exporter.log)? (y/n, 默认: n): " keep_config
    KEEP_CONFIG=0
    if [[ "$keep_config" == "y" || "$keep_config" == "Y" ]]; then
        KEEP_CONFIG=1
    fi

    # Call the main uninstallation function
    uninstall_node_exporter $KEEP_CONFIG

    read -p "按 Enter 键返回主菜单..." dummy
    show_menu
}

# Function for interactive configuration update
update_config_interactive() {
    clear
    display_logo
    echo -e "${CYAN}===== 更新 Node Exporter 配置 =====${NC}"

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 未安装或服务文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi

    # Show current configuration
    current_port=$(grep -oP -- "--web\.listen-address=:\K[0-9]+" "$SERVICE_FILE" || echo "未知")
    echo -e "${CYAN}当前端口: ${NC}$current_port"

    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}当前配置文件: ${NC}$CONFIG_FILE"
        echo -e "${CYAN}配置内容:${NC}"
        cat "$CONFIG_FILE"
    else
        echo -e "${YELLOW}当前未使用外部配置文件 (config.yml)。${NC}"
    fi

    # Update port
    while true; do
      read -p "输入新端口 (留空则保持当前端口 $current_port): " new_port_input
      new_port=${new_port_input:-$current_port}
      if check_port_permissions "$new_port"; then
        USER_PORT=$new_port # Set global USER_PORT for update_config
        break
      fi
    done


    # TLS configuration
    read -p "更新 TLS 配置? (y/n, 默认: n): " update_tls
    if [[ "$update_tls" == "y" || "$update_tls" == "Y" ]]; then
        read -p "请输入 TLS cert file 全路径 (留空则禁用 TLS): " CERT_FILE_INPUT
        CERT_FILE=$CERT_FILE_INPUT # Set global CERT_FILE
        if [[ -n "$CERT_FILE" ]]; then
             if [ ! -f "$CERT_FILE" ]; then
                 echo -e "${RED}错误: 证书文件 '$CERT_FILE' 不存在。${NC}"
                 read -p "按 Enter 键返回主菜单..." dummy
                 show_menu
                 return
             fi
             while true; do
                 read -p "请输入 TLS cert key file 全路径: " CERT_KEY_FILE_INPUT
                 CERT_KEY_FILE=$CERT_KEY_FILE_INPUT # Set global CERT_KEY_FILE
                 if [[ -z "$CERT_KEY_FILE" ]]; then
                     echo -e "${RED}错误：必须指定 cert key file。${NC}"
                 elif [ ! -f "$CERT_KEY_FILE" ]; then
                     echo -e "${RED}错误: 密钥文件 '$CERT_KEY_FILE' 不存在。${NC}"
                 else
                     break # Valid key file provided
                 fi
             done
        else
            CERT_KEY_FILE="" # Ensure key file is empty if cert file is empty
        fi
    else
        # Keep existing TLS settings if not updating explicitly
        # Need to parse existing config file if it exists
         if grep -q 'tls_server_config:' "$CONFIG_FILE" 2>/dev/null; then
             CERT_FILE=$(grep -oP 'cert_file: \K.*' "$CONFIG_FILE" || echo "")
             CERT_KEY_FILE=$(grep -oP 'key_file: \K.*' "$CONFIG_FILE" || echo "")
             echo -e "${YELLOW}保留现有的 TLS 配置。${NC}"
         else
             CERT_FILE=""
             CERT_KEY_FILE=""
             echo -e "${YELLOW}未启用 TLS 配置。${NC}"
         fi
    fi


    # Basic Auth configuration
    read -p "更新 Basic Auth 配置? (y/n, 默认: n): " update_auth
    if [[ "$update_auth" == "y" || "$update_auth" == "Y" ]]; then
        read -p "请输入 basic auth 用户名 (留空则禁用): " USER_NAME_INPUT
        USER_NAME=$USER_NAME_INPUT # Set global USER_NAME
        if [[ -n "$USER_NAME" ]]; then
             echo "请为用户 '$USER_NAME' 生成 bcrypt 哈希密码。"
             echo -e "${YELLOW}可以使用在线工具（如 https://bcrypt-generator.com/ 或 https://bfotool.com/zh/bcrypt-hash-generator），推荐使用 10 rounds。${NC}"
             echo -e "${YELLOW}重要: 请复制并粘贴完整的哈希字符串 (通常以 '$2a$' 或 '$2b$' 开头)。${NC}"
             while true; do
                 read -p "请输入完整的 bcrypt 哈希密码: " USER_PWD_HASH_INPUT
                 USER_PWD_HASH=$USER_PWD_HASH_INPUT # Set global USER_PWD_HASH
                 if [[ -z "$USER_PWD_HASH" ]]; then
                     echo -e "${RED}错误：必须指定密码哈希。${NC}"
                 else
                     break # Hash provided
                 fi
             done
        else
             USER_PWD_HASH="" # Ensure hash is empty if user is empty
        fi
    else
        # Keep existing Auth settings if not updating explicitly
        if grep -q 'basic_auth_users:' "$CONFIG_FILE" 2>/dev/null; then
            USER_NAME=$(grep -oP 'basic_auth_users:\s*\K[^:]+' "$CONFIG_FILE" | sed 's/ //g' || echo "")
            # Note: We don't re-read the hash here for security, assume it stays if user isn't changed
            # Or we can re-read the existing hash from file if needed more accurately
            USER_PWD_HASH=$(grep -oP "$USER_NAME:\s*'\K[^']+" "$CONFIG_FILE" || echo "")
            echo -e "${YELLOW}保留现有的 Basic Auth 配置 (用户: $USER_NAME)。${NC}"
        else
            USER_NAME=""
            USER_PWD_HASH=""
            echo -e "${YELLOW}未启用 Basic Auth 配置。${NC}"
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
        echo -e "${RED}错误: Node Exporter 配置文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi

    # Let user specify backup directory base
    default_backup_base="$HOME/node_exporter_backup"
    read -p "请输入备份文件保存目录的基础名称 (默认: $default_backup_base): " backup_base
    backup_base=${backup_base:-$default_backup_base}
    backup_dir="${backup_base}_$(date +"%Y%m%d_%H%M%S")"

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
    read -p "请输入要恢复的备份归档文件路径 (.tar.gz): " backup_file
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
    # If not called from interactive mode, show header and detect system
    if [ "$OPERATION" != "menu" ] && [ "$OPERATION" != "install" ]; then # Avoid double header if called via --install
        clear
        display_logo
        echo -e "${CYAN}===== 安装 Node Exporter v${NODE_EXPORTER_VERSION} =====${NC}"
        detect_system
        # Check port permissions again for non-interactive install
        check_port_permissions "$USER_PORT" || exit 1
    elif [ "$OPERATION" == "install" ]; then
         # Ensure system is detected even if called non-interactively
         detect_system
    fi

    # Check if already installed
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}警告: Node Exporter 服务文件已存在 ($SERVICE_FILE).${NC}"
        read -p "是否继续并覆盖现有安装? (y/n): " overwrite_confirm
        if [[ "$overwrite_confirm" != "y" && "$overwrite_confirm" != "Y" ]]; then
            echo -e "${RED}安装已取消。${NC}"
            return 1
        fi
        echo -e "${YELLOW}将覆盖现有安装...${NC}"
        # Attempt to stop existing service before overwriting
         if [ -f "$SERVICE_FILE" ]; then
            echo "尝试停止现有服务..."
            "$SERVICE_FILE" stop || echo "无法停止现有服务 (可能未运行)."
            sleep 1
         fi
    fi


    # Create a temporary directory for download and extraction
    TMP_DIR=$(mktemp -d)
    echo -e "${CYAN}使用临时目录: ${NC}$TMP_DIR"
    cd "$TMP_DIR"

    # Download
    echo -e "\n${YELLOW}--- 开始下载 ---${NC}"
    echo -e "${CYAN}正在下载 ${NC}$DOWNLOAD_URL ..."
    if command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$NODE_EXPORTER_FILENAME" "$DOWNLOAD_URL" || {
            echo -e "${RED}下载失败！ (curl)${NC}"
            cd "$HOME" && rm -rf "$TMP_DIR"
            exit 1
        }
    elif command -v wget &>/dev/null; then
        wget -q --show-progress "$DOWNLOAD_URL" || {
            echo -e "${RED}下载失败！ (wget)${NC}"
            cd "$HOME" && rm -rf "$TMP_DIR"
            exit 1
        }
    else
        echo -e "${RED}错误: 需要 wget 或 curl 来下载文件。${NC}"
        cd "$HOME" && rm -rf "$TMP_DIR"
        exit 1
    fi

    # Extract
    echo -e "\n${YELLOW}--- 开始解压 ---${NC}"
    tar xvfz "$NODE_EXPORTER_FILENAME" || {
        echo -e "${RED}解压失败！ ($NODE_EXPORTER_FILENAME)${NC}"
        cd "$HOME" && rm -rf "$TMP_DIR"
        exit 1
    }
    # Check if extracted directory exists
    if [ ! -d "$EXTRACTED_DIR" ]; then
        echo -e "${RED}错误: 解压后未找到预期的目录 '$EXTRACTED_DIR'。${NC}"
        cd "$HOME" && rm -rf "$TMP_DIR"
        exit 1
    fi
    cd "$EXTRACTED_DIR"

    # Create installation directory
    echo -e "\n${YELLOW}--- 开始创建目录结构 ---${NC}"
    mkdir -p "$INSTALL_DIR/bin"

    # Generate config only if TLS or Basic Auth is enabled
    rm -f "$CONFIG_FILE" # Remove existing config if overwriting
    if [[ -n "$CERT_FILE" || -n "$USER_NAME" ]]; then
        echo -e "${CYAN}生成配置文件 $CONFIG_FILE ...${NC}"
        >"$CONFIG_FILE" # Create or truncate the file
        if [[ -n "$CERT_FILE" ]]; then
            cat <<EOF >>"$CONFIG_FILE"
tls_server_config:
  cert_file: $CERT_FILE
  key_file: $CERT_KEY_FILE
EOF
        fi
        if [[ -n "$USER_NAME" ]]; then
            # Ensure the hash is quoted if it contains special chars, though bcrypt usually doesn't
            cat <<EOF >>"$CONFIG_FILE"
basic_auth_users:
  $USER_NAME: '$USER_PWD_HASH'
EOF
        fi
        chmod 600 "$CONFIG_FILE" # Restrict permissions for config file
        echo "配置文件内容:"
        cat "$CONFIG_FILE"
    else
        echo -e "${CYAN}未启用 TLS 或 Basic Auth，不创建外部配置文件。${NC}"
    fi

    # Copy node_exporter binary
    echo -e "\n${YELLOW}--- 开始复制二进制文件 ---${NC}"
    # Check if binary exists in extracted dir
    if [ ! -f "./node_exporter" ]; then
        echo -e "${RED}错误: 未在解压目录中找到 'node_exporter' 二进制文件。${NC}"
        cd "$HOME" && rm -rf "$TMP_DIR"
        exit 1
    fi
    cp -f ./node_exporter "$BIN_PATH"
    chmod 755 "$BIN_PATH"

    # Create start script (service file)
    echo -e "\n${YELLOW}--- 创建启动脚本 ---${NC}"

    # Base ExecStart command - REMOVED fake paths
    EXEC_START="$BIN_PATH --web.listen-address=:$USER_PORT --path.sysfs=$HOME_DIR/fake_sys --path.procfs=$HOME_DIR/fake_proc"
    # Add config file argument if it exists and was created
    if [[ -f "$CONFIG_FILE" ]]; then
        EXEC_START="$EXEC_START --web.config.file=$CONFIG_FILE"
    fi

    cat <<EOF >"$SERVICE_FILE"
#!/bin/bash
# Node Exporter 启动/管理脚本 (非root)
# 版本: ${NODE_EXPORTER_VERSION}
# 安装日期: $(date +"%Y-%m-%d %H:%M:%S")

# --- 配置 ---
COMMAND="$EXEC_START"
PID_FILE="$PID_FILE"
LOG_FILE="$LOG_FILE"
# -------------

# 确保日志和PID目录存在
mkdir -p "\$(dirname "\$PID_FILE")" 2>/dev/null
mkdir -p "\$(dirname "\$LOG_FILE")" 2>/dev/null

# 函数：启动服务
start() {
    if [ -f "\$PID_FILE" ]; then
        PID=\$(cat "\$PID_FILE")
        # Check if the process with this PID actually exists
        if ps -p \$PID > /dev/null 2>&1; then
            echo -e "${YELLOW}Node Exporter 已经在运行 (PID: \$PID)${NC}"
            return 1 # Already running
        else
            # PID file exists, but process doesn't. Clean up stale PID file.
            echo -e "${YELLOW}发现过期的 PID 文件，正在移除...${NC}"
            rm -f "\$PID_FILE"
        fi
    fi

    echo -e "${CYAN}启动 Node Exporter...${NC}"
    # Use nohup to detach, redirect output, run in background
    nohup \$COMMAND >> "\$LOG_FILE" 2>&1 &
    # Store the PID of the background process
    echo \$! > "\$PID_FILE"
    sleep 1 # Give it a moment to start

    # Verify if the process started successfully
    if [ -f "\$PID_FILE" ]; then
        NEW_PID=\$(cat "\$PID_FILE")
        if ps -p \$NEW_PID > /dev/null 2>&1; then
            echo -e "${GREEN}Node Exporter 已启动 (PID: \$NEW_PID)${NC}"
            return 0 # Success
        else
            echo -e "${RED}启动失败！检查日志: \$LOG_FILE ${NC}"
            rm -f "\$PID_FILE" # Clean up PID file on failure
            return 1 # Failure
        fi
    else
         echo -e "${RED}启动失败！无法创建 PID 文件。${NC}"
         return 1 # Failure
    fi
}

# 函数：停止服务
stop() {
    if [ ! -f "\$PID_FILE" ]; then
        echo -e "${YELLOW}PID 文件 (\$PID_FILE) 不存在。Node Exporter 可能没有运行。${NC}"
        return 1 # Not running or PID file missing
    fi

    PID=\$(cat "\$PID_FILE")

    if [ -z "\$PID" ]; then
        echo -e "${YELLOW}PID 文件为空。可能未正常启动或已被停止。${NC}"
        rm -f "\$PID_FILE" # Clean up empty PID file
        return 1
    fi

    # Check if the process actually exists
    if ! ps -p \$PID > /dev/null 2>&1; then
        echo -e "${YELLOW}进程 (PID: \$PID) 未找到。可能已被停止。移除 PID 文件...${NC}"
        rm -f "\$PID_FILE"
        return 1 # Process not found
    fi

    # Process exists, attempt to stop it gracefully
    echo -e "${CYAN}正在停止 Node Exporter (PID: \$PID)...${NC}"
    kill \$PID
    sleep 2 # Wait for graceful shutdown

    # Check if it stopped
    if ps -p \$PID > /dev/null 2>&1; then
        echo -e "${YELLOW}进程未能正常停止，尝试强制终止 (kill -9)...${NC}"
        kill -9 \$PID
        sleep 1
    fi

    # Final check and cleanup
    if ps -p \$PID > /dev/null 2>&1; then
         echo -e "${RED}错误：无法停止进程 (PID: \$PID)。请手动检查。${NC}"
         return 1 # Failed to stop
    else
         echo -e "${GREEN}Node Exporter 已停止。${NC}"
         rm -f "\$PID_FILE" # Remove PID file on successful stop
         return 0 # Success
    fi
}

# 函数：检查状态
status() {
    if [ ! -f "\$PID_FILE" ]; then
        echo -e "${RED}Node Exporter 未运行 (PID 文件不存在)${NC}"
        return 1 # Not running based on PID file
    fi

    PID=\$(cat "\$PID_FILE")
    if [ -z "\$PID" ]; then
         echo -e "${RED}Node Exporter 未运行 (PID 文件为空)${NC}"
         rm -f "\$PID_FILE" # Clean up empty PID file
         return 1
     fi

    if ps -p \$PID > /dev/null 2>&1; then
        echo -e "${GREEN}Node Exporter 正在运行 (PID: \$PID)${NC}"
        # Optionally show command line: ps -p $PID -o args --no-headers
        return 0 # Running
    else
        echo -e "${RED}Node Exporter 未运行 (PID 文件存在但进程 \$PID 不存在)${NC}"
        echo -e "${YELLOW}移除过期的 PID 文件...${NC}"
        rm -f "\$PID_FILE"
        return 1 # Not running, stale PID file
    fi
}

# --- Main Script Logic ---
case "\$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        echo "正在重启 Node Exporter..."
        stop
        sleep 1
        start
        ;;
    status)
        status
        ;;
    *)
        echo "用法: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit \$? # Exit with the status code of the last command (start/stop/status)
EOF

    chmod 755 "$SERVICE_FILE"

    # Clean up
    echo -e "\n${YELLOW}--- 清理临时文件 ---${NC}"
    # 在删除前先切换到安全的工作目录
    cd "$HOME"
    rm -rf "$TMP_DIR"

    # Start the service using the service script
    echo -e "\n${YELLOW}--- 启动 Node Exporter 服务 ---${NC}"
    "$SERVICE_FILE" start
    start_status=$?

    if [ $start_status -eq 0 ]; then
        echo -e "\n${GREEN}Node Exporter 安装成功并且已启动！${NC}"
        echo -e "${CYAN}端口: ${NC}$USER_PORT"
        if [[ -f "$CONFIG_FILE" ]]; then
            echo -e "${CYAN}配置文件: ${NC}$CONFIG_FILE"
        fi
        echo -e "${CYAN}日志文件: ${NC}$LOG_FILE"
    else
        echo -e "\n${RED}Node Exporter 安装成功但启动失败，请检查日志: $LOG_FILE${NC}"
    fi

    echo -e "\n${CYAN}您可以通过以下命令管理服务:${NC}"
    echo -e "  ${GREEN}$SERVICE_FILE start${NC}    - 启动服务"
    echo -e "  ${GREEN}$SERVICE_FILE stop${NC}     - 停止服务"
    echo -e "  ${GREEN}$SERVICE_FILE restart${NC}  - 重启服务"
    echo -e "  ${GREEN}$SERVICE_FILE status${NC}   - 查看服务状态"

    echo -e "\n${CYAN}您可以通过以下命令卸载 Node Exporter:${NC}"
    echo -e "  ${GREEN}$0 --uninstall${NC}"

    echo -e "\n${CYAN}访问 Node Exporter:${NC}"
    host=$(hostname -I 2>/dev/null | awk '{print $1}' || hostname || echo "localhost")
    protocol="http"
    if [[ -f "$CONFIG_FILE" ]] && grep -q 'tls_server_config:' "$CONFIG_FILE"; then
        protocol="https"
    fi
    echo -e "  ${GREEN}${protocol}://$host:$USER_PORT/metrics${NC}"
}

# Function to uninstall Node Exporter
uninstall_node_exporter() {
    # If not called from interactive mode, show header if needed
    if [ "$OPERATION" != "menu" ]; then
        # Avoid double header if called via --uninstall
        if [ "$OPERATION" != "uninstall" ]; then
            clear
            display_logo
            echo -e "${CYAN}===== 卸载 Node Exporter =====${NC}"
        fi
    fi

    # Determine if we should keep config/log
    KEEP_CONFIG=${1:-0} # 0 = remove, 1 = keep

    # Check if Node Exporter seems installed (at least service file or binary exists)
    if [ ! -f "$BIN_PATH" ] && [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}Node Exporter 未安装或安装不完整。未找到 $BIN_PATH 或 $SERVICE_FILE。${NC}"
        return 1 # Nothing to uninstall effectively
    fi

    # Stop the service if it's running and service file exists
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "${CYAN}停止 Node Exporter 服务...${NC}"
        "$SERVICE_FILE" stop || echo -e "${YELLOW}服务停止失败或未运行。${NC}"
        sleep 1
    else
         echo -e "${YELLOW}服务文件 ($SERVICE_FILE) 不存在，无法自动停止服务。${NC}"
    fi

    # Remove files
    echo -e "${CYAN}移除 Node Exporter 文件...${NC}"

    # Always remove binary and service file
    rm -f "$BIN_PATH"
    rm -f "$SERVICE_FILE"
    # Always remove PID file as it's runtime state
    rm -f "$PID_FILE"


    # Remove config file and log file only if not keeping config
    if [ $KEEP_CONFIG -eq 0 ]; then
        echo "移除配置文件和日志文件..."
        rm -f "$CONFIG_FILE"
        rm -f "$LOG_FILE"

        # Try removing directories if they are empty
        rmdir "$INSTALL_DIR/bin" 2>/dev/null || true # Ignore error if not empty/doesn't exist
        rmdir "$INSTALL_DIR" 2>/dev/null || true    # Ignore error if not empty/doesn't exist

        if [ ! -d "$INSTALL_DIR" ]; then
            echo -e "${GREEN}Node Exporter 已完全卸载 (包括配置文件和日志)。${NC}"
        else
             echo -e "${GREEN}Node Exporter 主要文件已卸载，但安装目录 ($INSTALL_DIR) 包含其他文件未被删除。${NC}"
        fi
    else
        echo -e "${GREEN}Node Exporter 主要文件已卸载，但保留了配置文件和日志。${NC}"
        echo -e "${CYAN}以下文件/目录可能保留:${NC}"
        [ -f "$CONFIG_FILE" ] && echo "  - $CONFIG_FILE (配置文件)"
        [ -f "$LOG_FILE" ] && echo "  - $LOG_FILE (日志文件)"
        [ -d "$INSTALL_DIR" ] && echo "  - $INSTALL_DIR (安装目录)"
    fi
}

# Function to check status
check_status() {
    # Show header only if called from menu
    if [ "$OPERATION" == "menu" ]; then
      clear
      display_logo
      echo -e "${CYAN}===== Node Exporter 状态 =====${NC}"
    fi

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}Node Exporter 未安装或服务文件不存在 ($SERVICE_FILE)。${NC}"
        if [ "$OPERATION" == "menu" ]; then
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
        fi
        return 1
    fi

    # Check service status using the service script
    echo -e "${CYAN}检查服务状态:${NC}"
    "$SERVICE_FILE" status
    status_code=$?

    if [ $status_code -eq 0 ]; then
        # Get PID if running
        PID=$(cat "$PID_FILE" 2>/dev/null)

        # Get port from service file command line
        port=$(grep -oP -- "--web\.listen-address=:\K[0-9]+" "$SERVICE_FILE" || echo "未知")

        # Check if port is open (best effort)
        echo -e "\n${CYAN}端口状态 (:$port):${NC}"
        # Use ss if available, fallback to netstat, else skip
        if command -v ss &>/dev/null; then
            ss -tlpn 2>/dev/null | grep -E ":$port\s" || echo -e "${YELLOW}端口 :$port 未被监听或无法检测。${NC}"
        elif command -v netstat &>/dev/null; then
            netstat -tlpn 2>/dev/null | grep -E ":$port\s" || echo -e "${YELLOW}端口 :$port 未被监听或无法检测。${NC}"
        else
            echo -e "${YELLOW}无法检查端口状态 (需要 netstat 或 ss 工具)${NC}"
        fi

        # Check process resource usage (best effort)
        echo -e "\n${CYAN}进程资源使用情况 (PID: $PID):${NC}"
        if command -v ps &>/dev/null && [ -n "$PID" ]; then
            ps -p "$PID" -o pid,ppid,user,%cpu,%mem,vsz,rss,stat,start,time,command --no-headers || echo -e "${YELLOW}无法获取进程 $PID 的资源使用情况。${NC}"
        else
            echo -e "${YELLOW}无法检查进程资源使用情况 (需要 ps 工具或 PID 无效)${NC}"
        fi

        # Show access URL
        echo -e "\n${CYAN}访问 Node Exporter:${NC}"
        host=$(hostname -I 2>/dev/null | awk '{print $1}' || hostname || echo "localhost")
        protocol="http"
        if [[ -f "$CONFIG_FILE" ]] && grep -q 'tls_server_config:' "$CONFIG_FILE"; then
           protocol="https"
        fi
        echo -e "  ${GREEN}${protocol}://$host:$port/metrics${NC}"

        # Show log file status
        echo -e "\n${CYAN}日志文件:${NC}"
        if [ -f "$LOG_FILE" ]; then
            echo -e "路径: $LOG_FILE"
            echo -e "大小: $(du -h "$LOG_FILE" | cut -f1)"
            echo -e "最后 10 行:"
            echo -e "${YELLOW}-----------------------------${NC}"
            tail -n 10 "$LOG_FILE"
            echo -e "${YELLOW}-----------------------------${NC}"
        else
            echo -e "${YELLOW}日志文件 ($LOG_FILE) 不存在。${NC}"
        fi

        # Show config file status
        echo -e "\n${CYAN}配置文件:${NC}"
        if [ -f "$CONFIG_FILE" ]; then
            echo -e "路径: $CONFIG_FILE"
            echo -e "内容:"
            echo -e "${YELLOW}-----------------------------${NC}"
            cat "$CONFIG_FILE"
            echo -e "${YELLOW}-----------------------------${NC}"
        else
            echo -e "${YELLOW}未使用外部配置文件 ($CONFIG_FILE)。${NC}"
        fi
    fi

    if [ "$OPERATION" == "menu" ]; then
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
    fi

    return $status_code
}

# Function to start Node Exporter
start_node_exporter() {
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}Node Exporter 未安装或服务文件不存在 ($SERVICE_FILE)。${NC}"
        if [ "$OPERATION" == "menu" ]; then
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
        fi
        return 1
    fi

    echo -e "${CYAN}启动 Node Exporter 服务...${NC}"
    "$SERVICE_FILE" start
    status_code=$?

    if [ "$OPERATION" == "menu" ]; then
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
    fi

    return $status_code
}

# Function to stop Node Exporter
stop_node_exporter() {
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}Node Exporter 未安装或服务文件不存在 ($SERVICE_FILE)。${NC}"
        if [ "$OPERATION" == "menu" ]; then
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
        fi
        return 1
    fi

    echo -e "${CYAN}停止 Node Exporter 服务...${NC}"
    "$SERVICE_FILE" stop
    status_code=$?

    if [ "$OPERATION" == "menu" ]; then
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
    fi

    return $status_code
}

# Function to restart Node Exporter
restart_service() {
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}Node Exporter 未安装或服务文件不存在 ($SERVICE_FILE)。${NC}"
        if [ "$OPERATION" == "menu" ]; then
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
        fi
        return 1
    fi

    echo -e "${CYAN}重启 Node Exporter 服务...${NC}"
    "$SERVICE_FILE" restart
    status_code=$?

    if [ "$OPERATION" == "menu" ]; then
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
    fi

    return $status_code
}

# Function to update configuration
update_config() {
    # Assumes USER_PORT, CERT_FILE, CERT_KEY_FILE, USER_NAME, USER_PWD_HASH are set globally
    # either by parse_args or update_config_interactive

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在 ($SERVICE_FILE)。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        return 1
    fi

    # Backup current configuration before making changes
    echo -e "${CYAN}备份当前配置...${NC}"
    backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_dir="$HOME/node_exporter_backup_preupdate_$backup_timestamp"
    backup_config "$backup_dir" || {
        echo -e "${RED}备份失败，取消配置更新。${NC}"
        return 1
    }

    # Stop the service before updating config
    echo -e "${CYAN}停止当前服务以应用配置...${NC}"
    "$SERVICE_FILE" stop || echo -e "${YELLOW}服务停止失败或未运行。${NC}"
    sleep 1

    # Generate new config file based on current settings
    rm -f "$CONFIG_FILE" # Remove old config file
    if [[ -n "$CERT_FILE" || -n "$USER_NAME" ]]; then
        echo -e "${CYAN}生成新的配置文件 $CONFIG_FILE ...${NC}"
        >"$CONFIG_FILE" # Create or truncate the file
        if [[ -n "$CERT_FILE" ]]; then
            cat <<EOF >>"$CONFIG_FILE"
tls_server_config:
  cert_file: $CERT_FILE
  key_file: $CERT_KEY_FILE
EOF
        fi
        if [[ -n "$USER_NAME" ]]; then
             cat <<EOF >>"$CONFIG_FILE"
basic_auth_users:
  $USER_NAME: '$USER_PWD_HASH'
EOF
        fi
        chmod 600 "$CONFIG_FILE" # Restrict permissions for config file
         echo "新配置文件内容:"
         cat "$CONFIG_FILE"
    else
        echo -e "${CYAN}未启用 TLS 或 Basic Auth，不创建外部配置文件。${NC}"
    fi

    # Update the command line in the service file
    echo -e "${CYAN}更新服务文件 ($SERVICE_FILE) 中的启动命令...${NC}"
    # Base command
    new_exec_start="$BIN_PATH --web.listen-address=:$USER_PORT"
    # Add config file argument if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        new_exec_start="$new_exec_start --web.config.file=$CONFIG_FILE"
    fi

    # Use sed to replace the COMMAND line. Using a different delimiter like | for sed.
    # This assumes the COMMAND line format is exactly COMMAND="..."
    sed -i.bak "s|COMMAND=\".*\"|COMMAND=\"$new_exec_start\"|" "$SERVICE_FILE"
    # Check if sed succeeded (simple check: file modified)
    if cmp -s "$SERVICE_FILE" "$SERVICE_FILE.bak"; then
        echo -e "${RED}错误: 更新服务文件失败！恢复备份的服务文件。${NC}"
        mv "$SERVICE_FILE.bak" "$SERVICE_FILE"
        return 1
    else
         echo -e "${GREEN}服务文件更新成功。${NC}"
         rm -f "$SERVICE_FILE.bak" # Remove backup if successful
    fi


    echo -e "${GREEN}配置更新完成。${NC}"
    echo -e "${CYAN}建议重启服务以应用更改。${NC}"

    # Ask if user wants to restart service now
    # Avoid asking if called from command line --config directly, let user manage service
    if [ "$OPERATION" == "menu" ] || [ "$OPERATION" == "config" ]; then # Ask in menu or direct config update
         read -p "是否立即重启服务? (y/n): " restart_now
         if [[ "$restart_now" == "y" || "$restart_now" == "Y" ]]; then
             restart_service
         else
             echo -e "${YELLOW}请记得稍后手动启动服务: $SERVICE_FILE start ${NC}"
         fi
    # else: if called as part of install/restore, the calling function handles restart prompt
    fi
}

# Function to backup configuration
backup_config() {
    backup_dir="$1" # Expect full path like /path/to/backup_timestamp

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 服务文件不存在 ($SERVICE_FILE)。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        return 1
    fi

    echo -e "${CYAN}创建备份目录: ${NC}$backup_dir"
    mkdir -p "$backup_dir" || { echo -e "${RED}创建备份目录失败。${NC}"; return 1; }

    # Backup service file
    echo -e "${CYAN}备份服务文件...${NC}"
    cp -f "$SERVICE_FILE" "$backup_dir/"

    # Backup config file if it exists
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}备份配置文件...${NC}"
        cp -f "$CONFIG_FILE" "$backup_dir/"
    else
        echo -e "${YELLOW}配置文件 ($CONFIG_FILE) 不存在，跳过备份。${NC}"
    fi

    # Create metadata file
    echo -e "${CYAN}创建备份元数据...${NC}"
    current_port=$(grep -oP -- "--web\.listen-address=:\K[0-9]+" "$SERVICE_FILE" || echo "未知")
    cat <<EOF >"$backup_dir/metadata.txt"
Node Exporter Backup (non-root)
Backup Date: $(date)
Script Version: $SCRIPT_VERSION
Node Exporter Version: $NODE_EXPORTER_VERSION
Service File Path: $SERVICE_FILE
Config File Path: $CONFIG_FILE
PID File Path: $PID_FILE
Log File Path: $LOG_FILE
Port: $current_port
Backup Source Dir: $INSTALL_DIR
EOF

    # Create an archive for easy transport
    backup_archive_path="$(dirname "$backup_dir")/$(basename "$backup_dir").tar.gz"
    echo -e "${CYAN}创建备份归档文件: $backup_archive_path ...${NC}"
    # Tar command: create (-c), gzip (-z), file (-f), change to parent dir (-C), archive content of backup_dir
    if tar -czf "$backup_archive_path" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"; then
        echo -e "${GREEN}备份完成!${NC}"
        echo -e "${CYAN}备份目录: ${NC}$backup_dir"
        echo -e "${CYAN}备份归档: ${NC}$backup_archive_path"
        # Optional: Remove the directory after creating archive?
        # read -p "是否删除原始备份目录 $backup_dir? (y/n, default n): " remove_dir
        # if [[ "$remove_dir" == "y" || "$remove_dir" == "Y" ]]; then
        #     rm -rf "$backup_dir"
        #     echo "原始备份目录已删除。"
        # fi
        return 0
    else
        echo -e "${RED}创建备份归档文件失败！${NC}"
        echo -e "${YELLOW}备份文件可能仍保留在目录: $backup_dir ${NC}"
        return 1
    fi
}

# Function to restore configuration
restore_config() {
    backup_file="$1" # Expect path to .tar.gz file

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}错误: 备份文件 '$backup_file' 不存在或无法读取。${NC}"
        return 1
    fi

    # Create a temporary directory for extraction
    TMP_DIR=$(mktemp -d)
    echo -e "${CYAN}使用临时目录进行解压: ${NC}$TMP_DIR"

    # Extract the backup archive
    echo -e "${CYAN}解压备份文件 '$backup_file'...${NC}"
    if ! tar -xzf "$backup_file" -C "$TMP_DIR"; then
        echo -e "${RED}错误: 解压备份文件失败。${NC}"
        rm -rf "$TMP_DIR"
        return 1
    fi

    # Find the backup directory within the extracted files (should be named like node_exporter_backup_*)
    # Use find and head -n 1 just in case there are nested unexpected dirs
    backup_dir_name=$(find "$TMP_DIR" -maxdepth 1 -type d -name "node_exporter_backup_*" | head -n 1)
    if [ -z "$backup_dir_name" ] || [ ! -d "$backup_dir_name" ]; then
        echo -e "${RED}错误: 在解压的备份中无法找到预期的备份目录 (node_exporter_backup_*)。${NC}"
        ls -lA "$TMP_DIR" # Show what was extracted for debugging
        rm -rf "$TMP_DIR"
        return 1
    fi
    echo -e "${CYAN}找到备份内容目录: ${NC}$backup_dir_name"

    # Check if we have the necessary service file in the backup
    restored_service_file="$backup_dir_name/$(basename "$SERVICE_FILE")"
    if [ ! -f "$restored_service_file" ]; then
        echo -e "${RED}错误: 备份中缺少必要的服务文件 ($(basename "$SERVICE_FILE"))。${NC}"
        rm -rf "$TMP_DIR"
        return 1
    fi

    # Backup current config before restoring (safety net)
    echo -e "${CYAN}备份当前配置 (安全起见)...${NC}"
    pre_restore_backup_dir="$HOME/node_exporter_backup_prerestore_$(date +"%Y%m%d_%H%M%S")"
    backup_config "$pre_restore_backup_dir" || echo -e "${YELLOW}无法备份当前配置，恢复将继续...${NC}"


    # Stop the service if it's running
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "${CYAN}停止当前 Node Exporter 服务...${NC}"
        "$SERVICE_FILE" stop || echo -e "${YELLOW}服务停止失败或未运行。${NC}"
        sleep 1
    fi

    # Restore service file
    echo -e "${CYAN}恢复服务文件 ($SERVICE_FILE)...${NC}"
    # Ensure target directory exists
    mkdir -p "$(dirname "$SERVICE_FILE")"
    cp -f "$restored_service_file" "$SERVICE_FILE"
    chmod 755 "$SERVICE_FILE"

    # Restore config file if it exists in backup
    restored_config_file="$backup_dir_name/$(basename "$CONFIG_FILE")"
    if [ -f "$restored_config_file" ]; then
        echo -e "${CYAN}恢复配置文件 ($CONFIG_FILE)...${NC}"
        cp -f "$restored_config_file" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    else
        echo -e "${YELLOW}备份中未找到配置文件 ($basename "$CONFIG_FILE")，跳过恢复。${NC}"
        # Remove existing config file if backup didn't have one? Or leave it? Safer to leave it maybe.
        # rm -f "$CONFIG_FILE"
    fi

    # Clean up temporary directory
    rm -rf "$TMP_DIR"

    echo -e "${GREEN}配置恢复完成。${NC}"

    # Ask if user wants to start service now
    # Avoid asking if called from command line --restore directly
    if [ "$OPERATION" == "menu" ] || [ "$OPERATION" == "restore" ]; then
        read -p "是否立即使用恢复的配置启动服务? (y/n): " start_now
        if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
            start_node_exporter
        else
            echo -e "${YELLOW}请记得稍后手动启动服务: $SERVICE_FILE start ${NC}"
        fi
    fi

    return 0
}

# --- Main Execution ---
main() {
    # Parse command line arguments first
    parse_args "$@"

    # Run the requested operation
    case "$OPERATION" in
    menu)
        show_menu
        ;;
    install)
        # Header and detect_system are handled within install_node_exporter for this case
        install_node_exporter
        ;;
    uninstall)
        clear; display_logo; echo -e "${CYAN}===== 卸载 Node Exporter =====${NC}" # Show header for direct call
        uninstall_node_exporter 0 # 0 means don't keep config
        ;;
    status)
        # Header handled within check_status only if $OPERATION is menu
         if [ "$OPERATION" != "menu" ]; then
              # clear; display_logo; echo -e "${CYAN}===== Node Exporter 状态 =====${NC}" # Show header for direct call
              # Let check_status handle output directly without menu interaction
              check_status
         else
             check_status # Already handles header/menu interaction
         fi
        ;;
    restart)
        clear; display_logo; # Show header for direct call
        restart_service
        ;;
    config)
        clear; display_logo; echo -e "${CYAN}===== 更新 Node Exporter 配置 =====${NC}" # Show header for direct call
        # Assumes necessary --port, --tls*, --auth* args were parsed by parse_args
        update_config
        ;;
    backup)
        clear; display_logo; # Show header for direct call
        backup_dir="$HOME/node_exporter_backup_$(date +"%Y%m%d_%H%M%S")"
        backup_config "$backup_dir"
        ;;
    restore)
        clear; display_logo; echo -e "${CYAN}===== 恢复 Node Exporter 配置 =====${NC}" # Show header for direct call
        # Assumes --file= was parsed by parse_args and stored in BACKUP_FILE
        restore_config "$BACKUP_FILE"
        ;;
    start)
        clear; display_logo; # Show header for direct call
        start_node_exporter
        ;;
    stop)
        clear; display_logo; # Show header for direct call
        stop_node_exporter
        ;;
    *)
        echo -e "${RED}错误: 未知操作 '$OPERATION'${NC}" >&2
        show_help
        exit 1
        ;;
    esac
}

# Call the main function passing all script arguments
main "$@"