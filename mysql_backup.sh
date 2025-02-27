#!/bin/bash
db_user="xxx"
db_pass="xxx"
db_name="xxx"
db_host="xxx"
db_port=3306
backup_dir="/mysql_backup"
#backup_file="${db_name}_$(date +%Y%m%d%H%M%S).sql"
backup_file="alldata_$(date +%Y%m%d%H%M%S).sql"

#如果备份没有就创建备份目录
if [ ! -d "$backup_dir" ]; then
    mkdir -p "$backup_dir"
fi

#数据备份
echo -e "\033[34m正在努力备份所有数据，请稍等...\033[0m"
#echo -e "\033[34m正在努力备份${db_name}库中的数据，请稍等...\033[0m"
#mysqldump -h"$db_host" -u"$db_user" -p"$db_pass" -P"$db_port" $db_name > "$backup_dir/$backup_file" &> /dev/null
mysqldump -h"$db_host" -u"$db_user" -p"$db_pass" -P"$db_port" -A > "$backup_dir/$backup_file"

#检查备份是否成功
if [ $? -eq 0 ];then
    echo -e "\033[32m备份成功。\033[0m"
#压缩备份文件
    echo -e "\033[34m正在努力压缩备份文件...\033[0m"
    gzip "$backup_dir/$backup_file"
    #检查压缩备份文件是否成功
if [ $? -eq 0 ];then
    echo -e "\033[32m压缩备份文件成功。\033[0m"
else
    echo -e "\033[31m压缩备份文件失败！！！\033[0m" 
fi

else
    echo -e "\033[31m备份失败！！！\033[0m"
fi
