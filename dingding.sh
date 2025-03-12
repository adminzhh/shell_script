#!/bin/bash
# about zabbix bash script
# Author： www.yuchaoit.cn


#webhook 地址 webhook=''
#接受者的手机号，由 zabbix 传入 
user=$1
#报警邮件标题，由 zabbix 传入 
title=$2
#报警邮件内容，由 zabbix 传入
message=$3

# 构造语句执行发送动作
# bash就是用curl 构造json数据发出去而已，注意引号的细节就好
# 通过API返回的数据，来确认是否发送正确

curl -s -H "Content-Type: application/json" -X POST "https://oapi.dingtalk.com/robot/send?access_token=9b297f0fd752d837eff1a49a95a86b33874d5bbc28dec0b**************" -d '{"msgtype":"text","text":{"content":"'"${title}\n\n${message}\n\nzabbix报警啦！速速处理！！！"'"},"at":{"atMobiles":["'"${user}"'"],"isAtAll":false}}' 


#将报警信息写入日志文件
echo -e "\n 报警时间:$(date +%F-%H:%M)\n 报警标题:${title}\n 报警内容:${message}" >> /tmp/ding_bash.log

# 命令行测试： bash dingding.sh 1669139**** agent1出故障了  快来啊！

# 钉钉报警有一定要记得再内容里添加在钉钉里自定义的关键词

# 创建媒介类型脚本参数如下：
# {ALERT.SENDTO}
# {ALERT.SUBJECT}
# {ALERT.MESSAGE}

# 消息模板如下：
# 消息类型：问题
# 主题：服务器{HOSTNAME1}，发生故障{TRIGGER.STATUS}: {TRIGGER.NAME}！
# 消息：=======发生了如下的报警问题================
# 关键字：zabbix
# 告警主机：{HOSTNAME1} 
# 告警主机IP：{HOST.IP}
# 告警时间：{EVENT.DATE}-{EVENT.TIME}
# 告警等级：{TRIGGER.SEVERITY}
# 告警信息：{TRIGGER.NAME}
# 告警项目：{TRIGGER.KEY1}
# 问题详情：{ITEM.NAME} : {ITEM.VALUE}
# 当前状态：{TRIGGER.STATUS} : {ITEM.VALUE1}
# 事件ID：{EVENT.ID}　　
# ===========================================

# 消息类型：问题恢复
# 主题： 服务器{HOSTNAME1}，故障已恢复{TRIGGER.STATUS}: {TRIGGER.NAME}已恢复!
# 消息：=================恢复信息===============
# 关键字：zabbix
# 告警主机：{HOSTNAME1}
# 告警主机IP：{HOST.IP}
# 告警时间：{EVENT.DATE}-{EVENT.TIME}
# 告警等级：{TRIGGER.SEVERITY}
# 告警信息：{TRIGGER.NAME}
# 告警项目：{TRIGGER.KEY1}
# 问题详情：{ITEM.NAME} : {ITEM.VALUE}
# 当前状态：{TRIGGER.STATUS} : {ITEM.VALUE1}
# 事件ID：{EVENT.ID}
# =========================================


# 最后在zabbixui界面里添加媒介，脚本执行，再给用户添加报警媒介，再改触发器动作添加定义的企业微信报警
# 把脚本发到zabbix-server的/usr/lib/zabbix/alertscripts目录里，因为主配置文件有定义，必须把脚本放在这
# 最后就是特别要注意权限的问题，chown zabbix.zabbix weixin.sh 再把脚本所关联的日志也设置为zabbix用户权限
