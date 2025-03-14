#!/bin/bash

# MySQL连接配置
MYSQL_USER="xxxx"    # MySQL用户名
MYSQL_PASS="xxxx"    # MySQL密码
MYSQL_HOST="xxxx"    # MySQL主机地址
MYSQL_PORT="3306"    # MySQL端口

# 检查MySQL复制状态（定义函数）
#check_replication_status() {
    # 使用mysql命令行工具获取复制状态（SHOW SLAVE STATUS）
    REPL_STATUS=$(mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASS -e "SHOW SLAVE STATUS\G" 2> /dev/null | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master") 

    # 检查IO线程和SQL线程状态
    IO_RUNNING=$(echo "$REPL_STATUS" | grep "Slave_IO_Running" | awk '{print $2}')
    SQL_RUNNING=$(echo "$REPL_STATUS" | grep "Slave_SQL_Running" | awk '{print $2}')

    # 检查复制延迟
    SECONDS_BEHIND_MASTER=$(echo "$REPL_STATUS" | grep "Seconds_Behind_Master" | awk '{print $2}')
#echo $IO_RUNNING
#echo $SQL_RUNNING
    # 输出结果（根据SHOW SLAVE STATUS命令的输出结果，判断状态）
    if [ "$IO_RUNNING" == "Yes" ] && [ "$SQL_RUNNING" == "Yes
Replica" ]; then
        echo "OK: MySQL replication is running."
        echo "OK: Replication delay is $SECONDS_BEHIND_MASTER seconds"
    else
        echo "CRITICAL: MySQL replication is not running. IO: $IO_RUNNING, SQL: $SQL_RUNNING"
    fi
#}

# 执行检查并输出结果（执行前面定义的函数）
#check_replication_status
