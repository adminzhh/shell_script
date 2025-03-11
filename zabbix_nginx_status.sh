#!/bin/bash
#在nginx服务器上安装zabbix-agent
#在Zabbix-agent的子配置文件中，启用自定义监控功能
#定义一个新的UserParameter，监控脚本
#vim /etc/zabbix/zabbix_agentd.d/nginx_status.conf
#UserParameter=nginx_status[*],/usr/local/bin/nginx_status.sh $1
#编写shell脚本监控Nginx状态
#vim /usr/local/bin/nginx_status.sh

case $1 in
active)
    curl -s http://192.168.88.28/status | awk '/Active/{print $NF}';;
waiting)
    curl -s http://192.168.88.28/status | awk '/Waiting/{print $NF}';;
accepts)
    curl -s http://192.168.88.28/status | awk 'NR==3{print $1}';;
esac
#然后再zabbixui界面里添加自定义监控项，键值输入nginx_status[active]......
