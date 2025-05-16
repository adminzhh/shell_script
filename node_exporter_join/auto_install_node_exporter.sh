#!/bin/bash

# 配置参数
USER="root"
PASSWORD="Zkbr@2020!@.."
TAR_FILE="node_exporter-1.8.2.tar.gz"
IP_FILE="ip.txt"
REMOTE_DIR="/tmp"

# 检查必要文件
if [ ! -f "$TAR_FILE" ]; then
    echo "错误：找不到tar文件 $TAR_FILE"
    exit 1
fi

if [ ! -f "$IP_FILE" ]; then
    echo "错误：找不到IP列表文件 $IP_FILE"
    exit 1
fi

# 检查sshpass是否安装
if ! command -v sshpass &> /dev/null; then
    echo "请先安装sshpass：yum install -y sshpass 或 apt-get install -y sshpass"
    exit 1
fi

# 禁用SSH严格主机检查
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# 处理每个IP
while read -r ip; do
    echo "========================================"
    echo "正在处理服务器 $ip"
    
    # 1. 分发tar包
    echo "传输文件到服务器..."
    sshpass -p "$PASSWORD" scp $SSH_OPTS "$TAR_FILE" $USER@$ip:$REMOTE_DIR/
    if [ $? -ne 0 ]; then
        echo "[错误] 文件传输失败"
        continue
    fi

    # 2. 解压并执行安装脚本
    echo "执行安装脚本..."
    sshpass -p "$PASSWORD" ssh $SSH_OPTS $USER@$ip \
        "cd $REMOTE_DIR && \
        tar xzf $TAR_FILE && \
        cd node_exporter-1.8.2 && \
        chmod +x install_node_exporter.sh && \
        ./install_node_exporter.sh i"
    
    if [ $? -eq 0 ]; then
        echo "[成功] $ip 安装完成"
    else
        echo "[错误] $ip 安装过程中出现错误"
    fi

done < "$IP_FILE"

# 恢复默认的退出行为（可选）
set -e

echo "========================================"
echo "所有操作已完成！"
