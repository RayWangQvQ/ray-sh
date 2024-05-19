#!/bin/bash
set -e
set -u
set -o pipefail

# 自定义变量，需要修改
DOWNLOADURL="https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz"
CERT_FILE="" #/etc/letsencrypt/live/test.com/fullchain.pem
CERT_KEY_FILE="" #/etc/letsencrypt/live/test.com/privkey.pem
PORT=""
USER_NAME=""
USER_PWD=""

read -p "请输入cert file全路径(如/etc/letsencrypt/live/test.com/fullchain.pem):" CERT_FILE
read -p "请输入cert key file全路径(如/etc/letsencrypt/live/test.com/privkey.pem):" CERT_KEY_FILE
read -p "请输入端口号(如9100):" PORT
read -p "请输入用户名(如ray):" USER_NAME
read -p "请输入bcrypt后的密码，在线网站（https://bfotool.com/zh/bcrypt-hash-generator），10 rounds(如\$2y\$05\$ssakquqAoyrQRAz1dx5ZsOJrirdCJ1SHI7W6a9zyVx4yMWRmGa3MW):" USER_PWD
USER_PWD="${USER_PWD//\$/\\$}"


# 定义服务文件路径和配置文件目录
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
CONFIG_DIR="/opt/node_exporter"


# 下载
echo -e "\n---开始下载---"
if [ $(ls | grep -c 'node_exporter-.*.linux-amd64.tar.gz') -eq 0 ]; then
    wget $DOWNLOADURL
fi
tar xvfz node_exporter-*.*.tar.gz
cd node_exporter-*.*-amd64
ls -l


# 创建node_exporter用户和组，如果它们不存在
echo -e "\n---开始设置用户权限---"
if ! id "node_exporter" &>/dev/null; then
    useradd --no-create-home --shell /bin/false node_exporter
fi


# 创建或更新配置文件
echo -e "\n---开始新增配置---"
mkdir -p $CONFIG_DIR
chown -R node_exporter:node_exporter $CONFIG_DIR
touch $CONFIG_DIR/config.yml
cat <<EOF | sudo tee $CONFIG_DIR/config.yml
tls_server_config:
  cert_file: $CERT_FILE
  key_file: $CERT_KEY_FILE

basic_auth_users:
  $USER_NAME: "$USER_PWD"
EOF


# 复制node_exporter可执行文件到/usr/local/bin/并更改所有权
echo -e "\n---开始复制二进制文件---"
cp -f ./node_exporter /usr/local/bin/node_exporter
chown node_exporter:node_exporter /usr/local/bin/node_exporter


# 设置证书所有权
echo -e "\n---开始设置证书权限---"
chmod 755 $CERT_FILE
chmod 755 $CERT_KEY_FILE
chown node_exporter:node_exporter $CERT_FILE
chown node_exporter:node_exporter $CERT_KEY_FILE


# 创建或更新服务文件
echo -e "\n---开始设置服务---"
cat <<EOF | sudo tee $SERVICE_FILE
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:$PORT --web.config.file=$CONFIG_DIR/config.yml

[Install]
WantedBy=multi-user.target
EOF


# 重新加载systemd，启动并启用node_exporter服务
echo -e "\n---开始启动服务---"
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter


# 检测服务状态
sleep 3s
echo -e "\n---监控服务状态---"
echo "listening ports:\n"
netstat -tunlp | grep $PORT
echo "service status:\n"
sudo systemctl status node_exporter