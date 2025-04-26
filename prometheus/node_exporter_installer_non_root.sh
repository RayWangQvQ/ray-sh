#!/bin/bash
###
 # @Author: Ray
 # @Date: 2024-05-19 12:34:11
 # @LastEditors: Ray
 # @LastEditTime: 2025-04-26
 # @Description: Manages Node Exporter - install, uninstall, status check, and configuration.
 # @Modified: 支持非root用户安装
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
    echo -e "  ${GREEN}--restore${NC}          恢复配置备份"
    echo -e "  ${GREEN}--start${NC}            启动 Node Exporter"
    echo -e "  ${GREEN}--stop${NC}             停止 Node Exporter"
    echo -e "\n${CYAN}安装选项:${NC}"
    echo -e "  ${GREEN}--port=PORT${NC}        指定端口号 (默认: $DEFAULT_PORT，非root用户需要 >1024)"
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
        
        # Check port permissions
        check_port_permissions "$USER_PORT" || exit 1
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
    read -p "请输入端口号 (默认 $DEFAULT_PORT，非root用户请使用 >1024 的端口): " USER_PORT_INPUT
    USER_PORT=${USER_PORT_INPUT:-$DEFAULT_PORT}
    
    # Check port permissions
    check_port_permissions "$USER_PORT" || {
        read -p "请重新输入端口号 (>1024): " USER_PORT
        check_port_permissions "$USER_PORT" || {
            echo -e "${RED}端口选择无效，返回主菜单${NC}"
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
            return
        }
    }
    
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
        echo -e "${RED}错误: Node Exporter 配置文件不存在。${NC}"
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
    
    # Check port permissions
    check_port_permissions "$USER_PORT" || {
        read -p "请重新输入端口号 (>1024): " USER_PORT
        check_port_permissions "$USER_PORT" || {
            echo -e "${RED}端口选择无效，返回主菜单${NC}"
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
            return
        }
    }
    
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
        echo -e "${RED}错误: Node Exporter 配置文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        read -p "按 Enter 键返回主菜单..." dummy
        show_menu
        return
    fi
    
    # Let user specify backup directory
    read -p "请输入备份文件保存路径 (默认: $HOME/node_exporter_backup): " backup_dir
    backup_dir=${backup_dir:-"$HOME/node_exporter_backup"}
    
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
        
        # Check port permissions 
        check_port_permissions "$USER_PORT" || exit 1
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

    # Create installation directory
    echo -e "\n${YELLOW}--- 开始创建目录结构 ---${NC}"
    mkdir -p "$INSTALL_DIR/bin"
    
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
        chmod 600 "$CONFIG_FILE" # Restrict permissions for config file
    else
        echo -e "${CYAN}未启用 TLS 或 Basic Auth，不创建配置文件。${NC}"
    fi

    # Copy node_exporter binary
    echo -e "\n${YELLOW}--- 开始复制二进制文件 ---${NC}"
    cp -f ./node_exporter "$BIN_PATH"
    chmod 755 "$BIN_PATH"

    # Create start script
    echo -e "\n${YELLOW}--- 创建启动脚本 ---${NC}"
    
    # Base ExecStart command
    EXEC_START="$BIN_PATH --web.listen-address=:$USER_PORT"
    # Add config file argument if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        EXEC_START="$EXEC_START --web.config.file=$CONFIG_FILE"
    fi
    
    cat <<EOF > "$SERVICE_FILE"
#!/bin/bash
# Node Exporter 启动脚本
# 版本: ${NODE_EXPORTER_VERSION}
# 安装日期: $(date +"%Y-%m-%d %H:%M:%S")

# 命令参数
COMMAND="$EXEC_START"
PID_FILE="$PID_FILE"
LOG_FILE="$LOG_FILE"

# 函数：启动服务
start() {
    # 确保PID目录存在
    mkdir -p "\$(dirname "\$PID_FILE")" 2>/dev/null
    mkdir -p "\$(dirname "\$LOG_FILE")" 2>/dev/null
    
    if [ -f "\$PID_FILE" ]; then
        PID=\$(cat "\$PID_FILE")
        if ps -p \$PID > /dev/null 2>&1; then
            echo "Node Exporter 已经在运行 (PID: \$PID)"
            return 1
        else
            rm -f "\$PID_FILE"
        fi
    fi
    
    echo "启动 Node Exporter..."
    nohup \$COMMAND > "\$LOG_FILE" 2>&1 &
    echo \$! > "\$PID_FILE"
    echo "Node Exporter 已启动 (PID: \$(cat "\$PID_FILE"))"
    return 0
}

# 函数：停止服务
stop() {
    if [ ! -f "\$PID_FILE" ]; then
        echo "PID文件不存在，Node Exporter 可能没有运行"
        return 1
    fi
    
PID=$(cat "$PID_FILE")
    if ! ps -p $PID > /dev/null 2>&1; then
        echo "进程不存在，移除 PID 文件"
        rm -f "$PID_FILE"
        return 1
    fi
    
    echo "停止 Node Exporter (PID: $PID)..."
    kill $PID
    sleep 2
    
    if ps -p $PID > /dev/null 2>&1; then
        echo "尝试强制终止进程..."
        kill -9 $PID
        sleep 1
    fi
    
    rm -f "$PID_FILE"
    echo "Node Exporter 已停止"
    return 0
}

# 函数：检查状态
status() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Node Exporter 未运行"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        echo "Node Exporter 正在运行 (PID: $PID)"
        return 0
    else
        echo "PID 文件存在但进程不存在，清理 PID 文件"
        rm -f "$PID_FILE"
        return 1
    fi
}

# 解析命令行参数
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 2
        start
        ;;
    status)
        status
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
EOF

    chmod 755 "$SERVICE_FILE"

    # Clean up
    echo -e "\n${YELLOW}--- 清理临时文件 ---${NC}"
    # 在删除前先切换到安全的工作目录
    cd "$HOME"
    rm -rf "$TMP_DIR"

    # Start the service
    echo -e "\n${YELLOW}--- 启动 Node Exporter 服务 ---${NC}"

    # 直接执行命令而不是调用服务文件
    echo "启动 Node Exporter..."
    nohup "$BIN_PATH" --web.listen-address=:$USER_PORT > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2  # 给进程一点启动时间

    # 检查是否成功启动
    if ps -p $(cat "$PID_FILE" 2>/dev/null) > /dev/null 2>&1; then
        echo -e "\n${GREEN}Node Exporter 安装成功并且已启动！${NC}"
        echo -e "${CYAN}端口: ${NC}$USER_PORT"
        if [[ -f "$CONFIG_FILE" ]]; then
            echo -e "${CYAN}配置文件: ${NC}$CONFIG_FILE"
        fi
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
    host=$(hostname -I 2>/dev/null | awk '{print $1}' || hostname)
    echo -e "  ${GREEN}http://$host:$USER_PORT/metrics${NC}"
}

# Function to uninstall Node Exporter
uninstall_node_exporter() {
    # If not called from interactive mode, show header
    if [ "$OPERATION" != "menu" ]; then
        clear
        display_logo
        echo -e "${CYAN}===== 卸载 Node Exporter =====${NC}"
    fi
    
    # Determine if we should keep config
    KEEP_CONFIG=${1:-0}
    
    # Check if Node Exporter is installed
    if [ ! -f "$BIN_PATH" ] && [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}Node Exporter 未安装或安装不完整。${NC}"
        return 1
    fi
    
    # Stop the service if it's running
    echo -e "${CYAN}停止 Node Exporter 服务...${NC}"
    if [ -f "$SERVICE_FILE" ]; then
        "$SERVICE_FILE" stop
    fi
    
    # Remove files
    echo -e "${CYAN}移除 Node Exporter 文件...${NC}"
    
    # Always remove binary
    rm -f "$BIN_PATH"
    
    # Remove service file
    rm -f "$SERVICE_FILE"
    
    # Remove config file and other files if not keeping config
    if [ $KEEP_CONFIG -eq 0 ]; then
        rm -f "$CONFIG_FILE"
        rm -f "$PID_FILE"
        rm -f "$LOG_FILE"
        
        # Remove installation directory if it's empty
        rmdir --ignore-fail-on-non-empty "$INSTALL_DIR/bin"
        rmdir --ignore-fail-on-non-empty "$INSTALL_DIR"
        
        echo -e "${GREEN}Node Exporter 已完全卸载。${NC}"
    else
        echo -e "${GREEN}Node Exporter 已卸载，但保留了配置文件。${NC}"
        echo -e "${CYAN}以下文件保留:${NC}"
        [ -f "$CONFIG_FILE" ] && echo "  - $CONFIG_FILE"
        [ -f "$LOG_FILE" ] && echo "  - $LOG_FILE"
    fi
}

# Function to check status
check_status() {
    clear
    display_logo
    echo -e "${CYAN}===== Node Exporter 状态 =====${NC}"
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}Node Exporter 未安装或安装不完整。${NC}"
        if [ "$OPERATION" == "menu" ]; then
            read -p "按 Enter 键返回主菜单..." dummy
            show_menu
        fi
        return 1
    fi
    
    # Check service status
    echo -e "${CYAN}检查服务状态:${NC}"
    "$SERVICE_FILE" status
    status_code=$?
    
    if [ $status_code -eq 0 ]; then
        # Get PID
        PID=$(cat "$PID_FILE")
        
        # Get port
        port=$(grep -oP -- "--web.listen-address=:\K[0-9]+" "$SERVICE_FILE" || echo "$DEFAULT_PORT")
        
        # Check if port is open
        echo -e "\n${CYAN}端口状态:${NC}"
        if command -v netstat &> /dev/null; then
            netstat -tuln | grep -E ":$port\s"
        elif command -v ss &> /dev/null; then
            ss -tuln | grep -E ":$port\s"
        else
            echo -e "${YELLOW}无法检查端口状态 (需要 netstat 或 ss 工具)${NC}"
        fi
        
        # Check process resource usage
        echo -e "\n${CYAN}进程资源使用情况:${NC}"
        if command -v ps &> /dev/null; then
            ps -p $PID -o pid,ppid,user,pcpu,pmem,vsz,rss,stat,start,time,comm
        else
            echo -e "${YELLOW}无法检查进程资源使用情况 (需要 ps 工具)${NC}"
        fi
        
        # Show access URL
        echo -e "\n${CYAN}访问 Node Exporter:${NC}"
        host=$(hostname -I 2>/dev/null | awk '{print $1}' || hostname)
        echo -e "  ${GREEN}http://$host:$port/metrics${NC}"
        
        # Show log file status
        echo -e "\n${CYAN}日志文件:${NC}"
        if [ -f "$LOG_FILE" ]; then
            echo -e "日志文件: $LOG_FILE"
            echo -e "文件大小: $(du -h "$LOG_FILE" | cut -f1)"
            echo -e "最后 10 行日志:"
            echo -e "${YELLOW}-----------------------------${NC}"
            tail -n 10 "$LOG_FILE"
            echo -e "${YELLOW}-----------------------------${NC}"
        else
            echo -e "${YELLOW}日志文件不存在${NC}"
        fi
        
        # Show config file status
        echo -e "\n${CYAN}配置文件:${NC}"
        if [ -f "$CONFIG_FILE" ]; then
            echo -e "配置文件: $CONFIG_FILE"
            echo -e "配置内容:"
            echo -e "${YELLOW}-----------------------------${NC}"
            cat "$CONFIG_FILE"
            echo -e "${YELLOW}-----------------------------${NC}"
        else
            echo -e "${YELLOW}未使用配置文件${NC}"
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
        echo -e "${RED}Node Exporter 未安装或安装不完整。${NC}"
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
        echo -e "${RED}Node Exporter 未安装或安装不完整。${NC}"
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
        echo -e "${RED}Node Exporter 未安装或安装不完整。${NC}"
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
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 配置文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        return 1
    fi
    
    # Backup current configuration
    echo -e "${CYAN}备份当前配置...${NC}"
    backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_dir="$HOME/node_exporter_backup_$backup_timestamp"
    backup_config "$backup_dir"
    
    # Get current command
    current_cmd=$(grep -oP "COMMAND=\"\K[^\"]*" "$SERVICE_FILE")
    
    # Update port
    echo -e "${CYAN}更新端口配置...${NC}"
    new_cmd=$(echo "$current_cmd" | sed -E "s/--web\.listen-address=:[0-9]+/--web.listen-address=:$USER_PORT/")
    
    # Update or remove config file reference
    if [[ -n "$CERT_FILE" || -n "$USER_NAME" ]]; then
        echo -e "${CYAN}更新 TLS/Auth 配置...${NC}"
        
        # Create or update config file
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
        chmod 600 "$CONFIG_FILE" # Restrict permissions for config file
        
        # Add or update config file parameter
        if [[ "$new_cmd" == *"--web.config.file="* ]]; then
            new_cmd=$(echo "$new_cmd" | sed -E "s|--web\.config\.file=[^ ]*|--web.config.file=$CONFIG_FILE|")
        else
            new_cmd="$new_cmd --web.config.file=$CONFIG_FILE"
        fi
    else
        # Remove config file parameter if no TLS/Auth
        echo -e "${CYAN}禁用 TLS/Auth 配置...${NC}"
        new_cmd=$(echo "$new_cmd" | sed -E "s|--web\.config\.file=[^ ]*||")
        # Remove config file
        if [ -f "$CONFIG_FILE" ]; then
            rm -f "$CONFIG_FILE"
        fi
    fi
    
    # Update service file
    echo -e "${CYAN}更新服务文件...${NC}"
    sed -i "s|COMMAND=\".*\"|COMMAND=\"$new_cmd\"|" "$SERVICE_FILE"
    
    echo -e "${GREEN}配置更新完成。${NC}"
    echo -e "${CYAN}需要重启服务以应用更改。${NC}"
    
    # Ask if user wants to restart service now
    if [ "$OPERATION" != "menu" ]; then
        read -p "是否立即重启服务? (y/n): " restart_now
        if [[ "$restart_now" == "y" || "$restart_now" == "Y" ]]; then
            restart_service
        fi
    else
        read -p "是否立即重启服务? (y/n): " restart_now
        if [[ "$restart_now" == "y" || "$restart_now" == "Y" ]]; then
            restart_service
        fi
    fi
}

# Function to backup configuration
backup_config() {
    backup_dir=${1:-"$HOME/node_exporter_backup_$(date +"%Y%m%d_%H%M%S")"}
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}错误: Node Exporter 配置文件不存在。${NC}"
        echo -e "${YELLOW}请先安装 Node Exporter。${NC}"
        return 1
    fi
    
    echo -e "${CYAN}创建备份目录: ${NC}$backup_dir"
    mkdir -p "$backup_dir"
    
    # Backup service file
    echo -e "${CYAN}备份服务文件...${NC}"
    cp -f "$SERVICE_FILE" "$backup_dir/"
    
    # Backup config file if it exists
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}备份配置文件...${NC}"
        cp -f "$CONFIG_FILE" "$backup_dir/"
    fi
    
    # Create metadata file
    echo -e "${CYAN}创建备份元数据...${NC}"
    cat <<EOF > "$backup_dir/metadata.txt"
Node Exporter Backup
Date: $(date)
Version: $NODE_EXPORTER_VERSION
Service File: $SERVICE_FILE
Config File: $CONFIG_FILE
PID File: $PID_FILE
Log File: $LOG_FILE
EOF
    
    # Create an archive for easy transport
    echo -e "${CYAN}创建备份归档文件...${NC}"
    backup_archive="$HOME/node_exporter_backup_$(date +"%Y%m%d_%H%M%S").tar.gz"
    tar -czf "$backup_archive" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"
    
    echo -e "${GREEN}备份完成!${NC}"
    echo -e "${CYAN}备份目录: ${NC}$backup_dir"
    echo -e "${CYAN}备份归档: ${NC}$backup_archive"
    
    return 0
}

# Function to restore configuration
restore_config() {
    backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}错误: 备份文件 '$backup_file' 不存在。${NC}"
        return 1
    fi
    
    # Create a temporary directory for extraction
    TMP_DIR=$(mktemp -d)
    echo -e "${CYAN}使用临时目录: ${NC}$TMP_DIR"
    
    # Extract the backup archive
    echo -e "${CYAN}解压备份文件...${NC}"
    tar -xzf "$backup_file" -C "$TMP_DIR"
    
    # Find the backup directory within the extracted files
    backup_dir=$(find "$TMP_DIR" -type d -name "node_exporter_backup_*" | head -n 1)
    if [ -z "$backup_dir" ]; then
        echo -e "${RED}错误: 无法找到备份目录。${NC}"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    # Check if we have necessary files
    if [ ! -f "$backup_dir/$(basename "$SERVICE_FILE")" ]; then
        echo -e "${RED}错误: 备份中缺少必要的服务文件。${NC}"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    # Stop the service if it's running
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "${CYAN}停止 Node Exporter 服务...${NC}"
        "$SERVICE_FILE" stop
    fi
    
    # Restore service file
    echo -e "${CYAN}恢复服务文件...${NC}"
    cp -f "$backup_dir/$(basename "$SERVICE_FILE")" "$SERVICE_FILE"
    chmod 755 "$SERVICE_FILE"
    
    # Restore config file if it exists in backup
    if [ -f "$backup_dir/$(basename "$CONFIG_FILE")" ]; then
        echo -e "${CYAN}恢复配置文件...${NC}"
        cp -f "$backup_dir/$(basename "$CONFIG_FILE")" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
    
    # Clean up temporary directory
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}配置恢复完成。${NC}"
    
    # Ask if user wants to start service now
    if [ "$OPERATION" != "menu" ]; then
        read -p "是否立即启动服务? (y/n): " start_now
        if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
            start_node_exporter
        fi
    else
        read -p "是否立即启动服务? (y/n): " start_now
        if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
            start_node_exporter
        fi
    fi
    
    return 0
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Run the requested operation
    case "$OPERATION" in
        menu)
            show_menu
            ;;
        install)
            install_node_exporter
            ;;
        uninstall)
            uninstall_node_exporter 0
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
            backup_dir="$HOME/node_exporter_backup_$(date +"%Y%m%d_%H%M%S")"
            backup_config "$backup_dir"
            ;;
        restore)
            restore_config "$BACKUP_FILE"
            ;;
        start)
            start_node_exporter
            ;;
        stop)
            stop_node_exporter
            ;;
        *)
            echo -e "${RED}错误: 未知操作 '$OPERATION'${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Call the main function
main "$@"