#!/bin/bash
# 判断用户权限
uid=$(id -u)
if [ "$uid" != 0 ]; then
    echo "当前脚本未以root权限运行"
    exit 1
fi
echo "现在是root权限,开始部署"
 
#安装Zabbix存储库
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu22.04_all.deb
dpkg -i zabbix-release_latest_7.0+ubuntu22.04_all.deb
rm -f zabbix-release_latest_7.0+ubuntu22.04_all.deb
apt update
 
#安装Zabbix server，Web前端，agent
apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent -y
 
#安装mysql
apt install mariadb-server -y
systemctl enable mariadb
 
# 配置数据库
mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
mysql -e "create user zabbix@localhost identified by '000000';"		#这六个0为zabbix的数据库密码可以自行修改
mysql -e "grant all privileges on zabbix.* to zabbix@localhost;"
mysql -e "set global log_bin_trust_function_creators = 1;"
 
#导入初始架构和数据，系统将提示您输入新创建的密码
echo "接下来将导入 Zabbix 初始架构和数据,系统会提示您输入之前创建的数据库用户(zabbix)的密码,请按提示操作"
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix
 
# 禁用log_bin_trust_function_creators选项
mysql -e "set global log_bin_trust_function_creators = 0;"
 
# 配置Zabbix服务器
echo "配置Zabbix服务器..."
sed -i 's/# DBPassword=/DBPassword=000000/' /etc/zabbix/zabbix_server.conf
 
#设置中文
apt install language-pack-zh-hans -y
update-locale LANG=zh_CN.UTF-8
export  LANG=zh_CN.UTF-8
 
#处理乱码
add-apt-repository universe
apt update
apt install fonts-wqy-microhei -y
cp /usr/share/fonts/truetype/wqy/wqy-microhei.ttc /usr/share/zabbix/assets/fonts/graphfont.ttf
 
#重启服务并设置开机自启用
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2
 
echo -e "\033[34mZabbix安装完成!\033[0m"
echo -e "\033[34m请访问 http://your-server-ip/zabbix 完成Web配置\033[0m"
echo -e "\033[34m默认用户名: Admin\033[0m"
echo -e "\033[34m默认密码: zabbix\033[0m"
