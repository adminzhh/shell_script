#!/bin/bash
yum list kernel --showduplicates
#如果list中有需要的版本可以直接执行 update 升级，多数是没有的，所以要按以下步骤操作
 
#导入ELRepo软件仓库的公共秘钥
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
 
#Centos7系统安装ELRepo
yum -y install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
#Centos8系统安装ELRepo
#yum -y install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
 
#查看ELRepo提供的内核版本
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
 
#kernel-lt：表示longterm，即长期支持的内核；当前为5.4.
#kernel-ml：表示mainline，即当前主线的内核；当前为5.17.
#安装主线内核
yum --enablerepo=elrepo-kernel install kernel-ml.x86_64 -y
 
#查看系统可用内核，并设置启动项
sudo awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
 
#0 : CentOS Linux (5.17.1-1.el7.elrepo.x86_64) 7 (Core)
#1 : CentOS Linux (3.10.0-1160.53.1.el7.x86_64) 7 (Core)
#2 : CentOS Linux (3.10.0-1160.el7.x86_64) 7 (Core)
#3 : CentOS Linux (0-rescue-20220208145000711038896885545492) 7 (Core)
 
#指定开机启动内核版本
grub2-set-default 0 # 或者 grub2-set-default 'CentOS Linux (5.17.1-1.el7.elrepo.x86_64) 7 (Core)'
 
#生成 grub 配置文件
grub2-mkconfig -o /boot/grub2/grub.cfg
 
#查看当前默认启动的内核
grubby --default-kernel
 
#重启系统，验证
uname -r
