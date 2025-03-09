#!/bin/bash
# 定义虚拟机配置文件和镜像文件的目录
CONF_DIR="/etc/libvirt/qemu"   # 虚拟机配置文件存放目录
IMG_DIR="/var/lib/libvirt/images"  # 虚拟机镜像文件存放目录
CONF_FILE="/var/lib/libvirt/images/node_base.xml"  # 基础虚拟机配置文件
IMG_FILE="/var/lib/libvirt/images/node_base.qcow2"  # 基础镜像文件
export LANG=C  # 设置语言环境为英文
. /etc/init.d/functions  # 引入系统函数库，用于调用echo_success和echo_warning等函数

# 定义创建虚拟机的函数
function create_vm(){
    # 检查虚拟机镜像文件是否存在
    if  [ -e ${IMG_DIR}/${1}.img ];then
        echo_warning  # 输出警告信息
        echo "vm ${1}.img is exists"  # 提示虚拟机镜像文件已存在
        return 1  # 返回错误码1
    else
        # 创建基于基础镜像的虚拟机镜像文件，大小为20G
        qemu-img create -b ${IMG_FILE} -F qcow2 -f qcow2 ${IMG_DIR}/${1}.img 20G &>/dev/null
        # 替换配置文件中的占位符，并生成新的虚拟机配置文件
        sed -re "s,#{5},${1}," ${CONF_FILE} >${CONF_DIR}/${1}.xml
        # 定义虚拟机
        sudo virsh define ${CONF_DIR}/${1}.xml &>/dev/null
        echo_success  # 输出成功信息
        echo "vm ${1} create"  # 提示虚拟机创建成功
    fi
}

# 定义删除虚拟机的函数
function remove_vm(){
    # 获取虚拟机的磁盘镜像路径
    read _ img <<<$(sudo virsh domblklist $1 2>/dev/null |awk 'NR==3{print}')
    # 检查镜像文件是否存在
    if [ -e "${img}" ];then
        # 关闭虚拟机
        sudo virsh destroy  $1 &>/dev/null
        # 删除虚拟机定义
        sudo virsh undefine $1 &>/dev/null
        # 删除虚拟机镜像文件
        rm -f ${img}
        echo_success  # 输出成功信息
        echo "vm ${1} delete"  # 提示虚拟机删除成功
    fi
}

# 主逻辑部分
case "$1" in
    create|remove)  # 判断用户输入的命令是create还是remove
    CMD=${1}  # 将命令赋值给变量CMD
    while ((${#} > 1));do  # 循环处理所有虚拟机名称参数
        shift  # 移动参数
        ${CMD}_vm ${1}  # 调用对应的函数处理虚拟机
    done
    ;;
    *)  # 如果输入的命令不是create或remove
    echo "${0##*/} {create|remove} vm1 vm2 vm3 ... .."  # 输出使用说明
    ;;
esac
exit $?  # 退出脚本并返回状态码
