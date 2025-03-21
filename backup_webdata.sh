#!/bin/bash
sou_path=/var/www/html
tar_path=/opt/backup_data
date=$(date +%Y-%m-%d)
tar -zcf ${tar_path}/web_file_${date}.tar.gz --exclude=*.tmp ${sou_path} &> /dev/null # 过滤*.tmp的文件
file_total=$(ls ${tar_path} | wc -l) # 统计备份目录里的备份数据的数量
echo "${date}的文件已打tar包放入${tar_path}，目前备份文件总数是${file_total}个"
if [ $file_total -ge 5 ];then
        scp ${tar_path}/*.tar.gz root@192.168.88.36:/backup_webdata &> /dev/null
        if [ $? -eq 0 ];then
                echo "上传成功"
                rm -fr ${tar_path}/web_file*
        else
                echo "上传失败!!!"
        fi
fi
