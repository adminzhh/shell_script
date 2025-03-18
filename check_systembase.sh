#!/bin/bash


#查看有哪些账户是无用账户
echo "========正在检查无用账户情况========"
grep -E "/bin/bash" /etc/passwd 
echo -e "\033[31;40m请核对上面的用户是否存在异常，如有异常请做好记录\033[0m"
echo -e """\033[34;40m 需要人工核对，核对无用账户的标准为：
	1. 账户可以登陆 。
	2. 账户无人使用但还存在系统上 。 \033[0m"""

#######################

#查看系统账户策略:密码失效时间90天、密码到期提醒时间14天
echo "========正在检查账户密码失效时间========"
Check_Pass_Poli=`grep  -E "^PASS_MAX_DAYS|^PASS_WARN_AGE"  /etc/login.defs | wc -l`
if  [ $Check_Pass_Poli -lt 2 ];then
    echo -e "\033[31;40m当前系统未对账户密码进行失效时间设置、密码到期提醒设置\033[0m"
else
    PAMAX=`grep  -E "^PASS_MAX_DAYS"  /etc/login.defs | awk -F" " '{ print $2 }'`
    PAWARN=`grep  -E "^PASS_WARN_AGE"  /etc/login.defs | awk -F" " '{ print $2 }'`
    if [ $PAMAX -le 90 ];then     echo -e "\033[32;40m密码失效时间为$PAMAX天，符合标准\033[0m"; else     echo -e "\033[31;40m密码失效时间为$PAMAX天，不符合标准\033[0m"; fi
    if [ $PAWARN -ge 14 ];then    echo -e "\033[32;40m密码到期提醒时间为$PAWARN天，符合标准\033[0m"; else     echo -e "\033[31;40m密码到期提醒时间为$PAWARN天，不符合标准\033[0m"; fi
fi
	
#######################

#查看系统账户策略:密码最小长度12位、密码复杂度为大小写英文字母、数字、特殊字符
echo "========正在检查账户密码策略========"
Check_User_Poli=`grep -E "^minlen|^minclass"  /etc/security/pwquality.conf |wc -l`

if  [ $Check_User_Poli -lt 2 ];then
    echo -e "\033[31;40m当前系统未对账户密码复杂度及密码最小长度设置\033[0m"
else
    PACLS=`grep  -E "^minclass"  /etc/security/pwquality.conf | awk -F"=| " '{ print $NF }'`
    PALEN=`grep  -E "^minlen"   /etc/security/pwquality.conf | awk -F"=| " '{ print $NF }'`
    if [ $PACLS -eq 4 ];then     echo -e "\033[32;40m密码负责度为$PACLS种类型，符合标准\033[0m"; else     echo -e "\033[31;40m密码负责度为$PACLS种类型，不符合标准\033[0m"; fi
    if [ $PALEN -ge 12 ];then    echo -e "\033[32;40m密码长度为$PALEN位，符合标准\033[0m"; else     echo -e "\033[31;40m密码长度为$PALEN位，不符合标准\033[0m"; fi
fi	

#######################

#检查不必要的服务
echo "========正在检查不必要的服务========"
Check_Use_Ser_post=`systemctl  status  postfix | grep Active | grep running | wc -l`
Check_Use_Ser_dhcp=`systemctl  status  dhcpd| grep Active | grep running | wc -l`

if [ $Check_Use_Ser_post -eq 0 ];then     echo -e "\033[32;40m postfix服务 处于关闭状态，符合标准\033[0m"; else     echo -e "\033[31;40m postfix服务 处于开启状态，不符合标准，请检查开启的必要性\033[0m"; fi

if [ $Check_Use_Ser_dhcp -eq 0 ];then     echo -e "\033[32;40m dhcp服务 处于关闭状态，符合标准\033[0m"; else     echo -e "\033[31;40m dhcp服务 处于开启状态，不符合标准，请检查开启的必要性\033[0m"; fi

#######################

#检查用户登陆超时退出时间
echo "========正在检查用户登陆超时退出时间========"
Check_Tty_Timeout=`grep -E "^ClientAliveInterval|^ClientAliveCountMax"  /etc/ssh/sshd_config |wc -l`

if  [ $Check_Tty_Timeout -lt 2 ];then
    echo -e "\033[31;40m当前系统未对用户登陆超时退出设置\033[0m"
else
    USRINT=`grep  -E "^ClientAliveInterval"  /etc/ssh/sshd_config | awk -F"=| " '{ print $NF }'`
    USRCOT=`grep  -E "^ClientAliveCountMax"   /etc/ssh/sshd_config | awk -F"=| " '{ print $NF }'`
    COUNT_time=`expr $USRINT \* $USRCOT`
    if [ $COUNT_time -lt 60 ];then
        echo -e "\033[31;40m 用户登陆超时退出设置为 $COUNT_time，不符合标准 \033[0m"
    elif [ $COUNT_time -le 300 ];then
        echo -e "\033[32;40m 用户登陆超时退出设置正确，符合标准 \033[0m"
    else
        echo -e "\033[31;40m 用户登陆超时退出设置为 $COUNT_time，不符合标准 \033[0m"
    fi
fi	

#######################

#查看连续认证失败次数
echo "========正在检查用户登陆认证失败次数========"
Check_Auth_Failsystem=`grep pam_faillock.so /etc/pam.d/system-auth | wc -l`
Check_Auth_Failpasswd=`grep pam_faillock.so /etc/pam.d/password-auth | wc -l`
if [ $Check_Auth_Failsystem -ge 3 ];then
    if [ $Check_Auth_Failpasswd -ge 3 ];then
	    echo -e "\033[32;40m 用户登陆连续认证失败锁定策略设置成功，符合标准 \033[0m"
	else
	    echo -e "\033[31;40m 用户登陆连续认证失败锁定策略设置不完全，不符合标准 \033[0m"
	fi
else
    echo -e "\033[31;40m 用户登陆连续认证失败锁定策略设置不正确，不符合标准 \033[0m" 
fi	

#######################

#查看snmp 服务状态
echo "========正在检查系统 snmpd服务状态========"
Check_SNmp_Ser=`ss -anplt | grep :199 | grep -v grep | wc -l`
if [ $Check_SNmp_Ser -eq 0 ];then
    echo -e "\033[32;40m 系统snmpd服务处于关闭状态，符合标准 \033[0m"
else
    echo -e "\033[31;40m 系统snmpd服务处于开启状态，不符合标准，请检查开启的必要性 \033[0m"
fi

#######################

#查看日志服务状态
echo "========正在检查系统日志服务状态========"
Check_Log_Ser=`systemctl  status rsyslog | grep Active | grep running | wc -l`
Check_Log_Net=`grep  "172.17.9.200"  /etc/rsyslog.conf | wc -l`

if [ $Check_Log_Ser -ge 1 ];then
    if [ $Check_Log_Net -ge 1 ];then
	    echo -e "\033[32;40m 系统日志服务处于开启状态并配置了远程日志服务器，符合标准 \033[0m"
	else
	    echo -e "\033[31;40m 系统日志服务处于开启状态但未配置远程日志服务器，请做好记录 \033[0m"
    fi
else
    echo -e "\033[31;40m 系统日志服务未开启，不符合标准 ，请及时进行配置 \033[0m"
fi

#######################

#检查ntp服务状态
echo "========正在检查系统时间同步服务状态========"
Check_NTP_Ser=`systemctl  status ntpd | grep Active | grep running | wc -l`
Check_NTP_SerCUT=`grep  -E "^server" /etc/ntp.conf | grep 172.17.8.232 | wc -l`

if [ $Check_NTP_Ser -ge 1 ];then
    if [ $Check_NTP_SerCUT -ge 1 ];then
	    echo -e "\033[32;40m 系统时间同步服务处于开启状态并配置了时间同步服务器，符合标准 \033[0m"
	else
	    echo -e "\033[31;40m 系统时间同步服务处于开启状态但未配置时间同步服务器，请做好记录 \033[0m"
	fi
else
    echo -e "\033[31;40m 系统时间同步服务未开启，不符合标准，请及时进行配置 \033[0m"
fi

