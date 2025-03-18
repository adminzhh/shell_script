#!/bin/bash

#######################
Date_Time=`date +%Y%m%d`
function Check_Password_Policy(){
    #查看系统账户策略:密码失效时间90天、密码到期提醒时间14天
    echo "========正在检查账户密码失效时间========"
    Check_Pass_Poli=`grep  -E "^PASS_MAX_DAYS|^PASS_WARN_AGE"  /etc/login.defs | wc -l`
    cp  /etc/login.defs{,_bak$Date_Time}
    if  [ $Check_Pass_Poli -lt 2 ];then
        echo -e "\033[31;40m当前系统未对账户密码进行失效时间设置、密码到期提醒设置\033[0m"
        sed -i  '$iPASS_MAX_DAYS   90'  /etc/login.defs && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        sed -i  '$iPASS_WARN_AGE   14'  /etc/login.defs && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    else
        PAMAX=`grep  -E "^PASS_MAX_DAYS"  /etc/login.defs | awk -F" " '{ print $2 }'`
        PAWARN=`grep  -E "^PASS_WARN_AGE"  /etc/login.defs | awk -F" " '{ print $2 }'`
        if [ $PAMAX -le 90 ];then     
            echo -e "\033[32;40m密码失效时间为$PAMAX天，符合标准\033[0m"; 
        else     
            echo -e "\033[31;40m密码失效时间为$PAMAX天，不符合标准\033[0m"; 
            sed -i  's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/'  /etc/login.defs && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        fi
        if [ $PAWARN -ge 14 ];then    
            echo -e "\033[32;40m密码到期提醒时间为$PAWARN天，符合标准\033[0m"; 
        else     
            echo -e "\033[31;40m密码到期提醒时间为$PAWARN天，不符合标准\033[0m"; 
            sed -i  's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/'  /etc/login.defs && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        fi
    fi
    #chage --warndays  14 root && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    #chage --maxdays 90 root && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
}
#######################

function Check_User_Policy(){
    #查看系统账户策略:密码最小长度12位、密码复杂度为大小写英文字母、数字、特殊字符
    echo "========正在检查账户密码策略========"
    Check_User_Poli=`grep -E "^minlen|^minclass"  /etc/security/pwquality.conf |wc -l`
    cp  /etc/security/pwquality.conf{,_bak$Date_Time}
    if  [ $Check_User_Poli -lt 2 ];then
        echo -e "\033[31;40m当前系统未对账户密码复杂度及密码最小长度设置\033[0m"
        sed -i  '$iminlen = 12'  /etc/security/pwquality.conf && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        sed -i  '$iminclass = 4'  /etc/security/pwquality.conf && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    else
        PACLS=`grep  -E "^minclass"  /etc/security/pwquality.conf | awk -F"=| " '{ print $NF }'`
        PALEN=`grep  -E "^minlen"   /etc/security/pwquality.conf | awk -F"=| " '{ print $NF }'`
        if [ $PACLS -eq 4 ];then     
            echo -e "\033[32;40m密码负责度为$PACLS种类型，符合标准\033[0m"; 
        else     
            echo -e "\033[31;40m密码负责度为$PACLS种类型，不符合标准\033[0m"; 
            sed -i  's/^minclass.*/minclass = 4/'  /etc/login.defs && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        fi
        if [ $PALEN -ge 12 ];then    
            echo -e "\033[32;40m密码长度为$PALEN位，符合标准\033[0m"; 
        else     
            echo -e "\033[31;40m密码长度为$PALEN位，不符合标准\033[0m"; 
            sed -i  's/^minlen.*/minlen = 12/'  /etc/login.defs && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        fi
    fi
}
#######################

function Check_Useless_Service(){
    #检查不必要的服务
    echo "========正在检查不必要的服务========"
    Check_Use_Ser_post=`systemctl  status  postfix | grep Active | grep running | wc -l`
    Check_Use_Ser_dhcp=`systemctl  status  dhcpd| grep Active | grep running | wc -l`

    if [ $Check_Use_Ser_post -eq 0 ];then     
        echo -e "\033[32;40m postfix服务 处于关闭状态，符合标准\033[0m"; 
    else     
        echo -e "\033[31;40m postfix服务 处于开启状态，不符合标准，请检查开启的必要性\033[0m"; 
        systemctl stop postfix ; systemctl disable postfix  && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    fi

    if [ $Check_Use_Ser_dhcp -eq 0 ];then     
        echo -e "\033[32;40m dhcp服务 处于关闭状态，符合标准\033[0m"; 
    else     
        echo -e "\033[31;40m dhcp服务 处于开启状态，不符合标准，请检查开启的必要性\033[0m"; 
        systemctl stop dhcpd ; systemctl disable dhcpd && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    fi
}
#######################

function Check_Tty_Timeout(){
    #检查用户登陆超时退出时间
    echo "========正在检查用户登陆超时退出时间========"
    Check_Tty_Timeout=`grep -E "^ClientAliveInterval|^ClientAliveCountMax"  /etc/ssh/sshd_config |wc -l`
    cp  /etc/ssh/sshd_config{,_bak$Date_Time}
    if  [ $Check_Tty_Timeout -lt 2 ];then
        echo -e "\033[31;40m当前系统未对用户登陆超时退出设置\033[0m"
        sed -i  '$iClientAliveInterval   60'  /etc/ssh/sshd_config && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        sed -i  '$iClientAliveCountMax   3'  /etc/ssh/sshd_config && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    else
        USRINT=`grep  -E "^ClientAliveInterval"  /etc/ssh/sshd_config | awk -F"=| " '{ print $NF }'`
        USRCOT=`grep  -E "^ClientAliveCountMax"   /etc/ssh/sshd_config | awk -F"=| " '{ print $NF }'`
        COUNT_time=`expr $USRINT \* $USRCOT`
        if [ $USRINT -lt 60 ];then
            echo -e "\033[31;40m 用户登陆超时退出设置为 $COUNT_time，不符合标准 \033[0m"
            sed -i  's/^ClientAliveInterval.*/ClientAliveInterval  60/'  /etc/ssh/sshd_config && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        elif [ $COUNT_time -le 300 ];then
            echo -e "\033[32;40m 用户登陆超时退出设置正确，符合标准 \033[0m"
        else
            echo -e "\033[31;40m 用户登陆超时退出设置为 $COUNT_time，不符合标准 \033[0m"
            sed -i  's/^ClientAliveCountMax.*/ClientAliveCountMax  3/'  /etc/ssh/sshd_config && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        fi
    fi    
    systemctl  restart  sshd
}
#######################

function Check_Auth_Failed(){
    echo "========正在检查用户登陆认证失败次数========"
    Check_Auth_Failsystem=`grep pam_faillock.so /etc/pam.d/system-auth | wc -l`
    Check_Auth_Failpasswd=`grep pam_faillock.so /etc/pam.d/password-auth | wc -l`
    cp  /etc/pam.d/system-auth{,_bak$Date_Time}
    cp  /etc/pam.d/password-auth{,_bak$Date_Time}
    if [ $Check_Auth_Failsystem -ge 3 ];then
        if [ $Check_Auth_Failpasswd -ge 3 ];then
            echo -e "\033[32;40m 用户登陆连续认证失败锁定策略设置成功，符合标准 \033[0m"
        else
            echo -e "\033[31;40m 用户登陆连续认证失败锁定策略设置不完全，不符合标准 \033[0m"
        fi
    else
        echo -e "\033[31;40m 用户登陆连续认证失败锁定策略设置不正确，不符合标准 \033[0m" 
        sed -i '/auth        required      pam_env.so/i auth required pam_faillock.so preauth audit silent deny=5 unlock_time=900'  /etc/pam.d/system-auth
        sed -i '/auth        required      pam_deny.so/a auth [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900'  /etc/pam.d/system-auth
        sed -i '/account     required      pam_unix.so/i account required pam_faillock.so' /etc/pam.d/system-auth
        sed -i '/auth        required      pam_env.so/i auth required pam_faillock.so preauth audit silent deny=5 unlock_time=900'  /etc/pam.d/password-auth
        sed -i '/auth        required      pam_deny.so/a auth [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900'  /etc/pam.d/password-auth
        sed -i '/account     required      pam_unix.so/i account required pam_faillock.so' /etc/pam.d/password-auth
    fi    
}

#######################

function Check_SNmp_Service(){
    #查看snmp 服务状态
    echo "========正在检查系统 snmpd服务状态========"
    Check_SNmp_Ser=`ss -anplt | grep :199 | grep -v grep | wc -l`
    if [ $Check_SNmp_Ser -eq 0 ];then
        echo -e "\033[32;40m 系统snmpd服务处于关闭状态，符合标准 \033[0m"
    else
        echo -e "\033[31;40m 系统snmpd服务处于开启状态，不符合标准，请检查开启的必要性 \033[0m"
        systemctl stop  snmpd ; systemctl disable snmpd && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    fi
}

#######################

function Check_Log_Service(){
    #查看日志服务状态
    echo "========正在检查系统日志服务状态========"
    Check_Log_Ser=`systemctl  status rsyslog | grep Active | grep running | wc -l`
    Check_Log_Net=`grep  "172.17.9.200"  /etc/rsyslog.conf | wc -l`
    LogPATH=`grep PROMPT_COMMAND  /etc/profile | grep -vE "^#" |wc -l`
    cp  /etc/rsyslog.conf{,_bak$Date_Time}
    if [ $Check_Log_Ser -ge 1 ];then
        if [ $Check_Log_Net -ge 1 ];then
            echo -e "\033[32;40m 系统日志服务处于开启状态并配置了远程日志服务器，符合标准 \033[0m"
        else
            echo -e "\033[31;40m 系统日志服务处于开启状态但未配置远程日志服务器，请做好记录 \033[0m"
            echo '*.info;mail.none;authpriv.none;cron.none        @172.17.9.200' >> /etc/rsyslog.conf
            echo 'authpriv.*      @172.17.9.200' >> /etc/rsyslog.conf && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
            systemctl  restart rsyslog && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        fi
    else
        echo -e "\033[31;40m 系统日志服务未开启，不符合标准 ，请及时进行配置 \033[0m"
        echo '*.info;mail.none;authpriv.none;cron.none        @172.17.9.200' >> /etc/rsyslog.conf
        echo 'authpriv.*      @172.17.9.200' >> /etc/rsyslog.conf 
        systemctl  restart rsyslog && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
    fi
    
    if [ $LogPATH -eq 1 ];then
        echo -e "\033[32;40m 系统日志命令记录到messages中配置成功，符合标准 \033[0m"
    else
        echo -e "\033[31;40m 系统日志命令记录到messages中未配置，请做好记录 \033[0m"
        echo "export PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });logger -p local2.info \"euid=\$(whoami)\" \$(who am i) \`pwd\` \"\$msg\"; }'" >> /etc/profile
    fi
}
#######################

function Check_NTP_Service(){
    echo "========正在检查系统时间同步服务状态========"
    Check_NTP_Ser=`systemctl  status ntpd | grep Active | grep running | wc -l`
    Check_NTP_SerCUT=`grep  -E "^server" /etc/ntp.conf | grep 172.17.8.232 | wc -l`
    cp  /etc/ntp.conf{,_bak$Date_Time}
    
    if [ $Check_NTP_Ser -ge 1 ];then
        if [ $Check_NTP_SerCUT -ge 1 ];then
            echo -e "\033[32;40m 系统时间同步服务处于开启状态并配置了时间同步服务器，符合标准 \033[0m"
        else
            echo -e "\033[31;40m 系统时间同步服务处于开启状态但未配置时间同步服务器，请做好记录 \033[0m"
            echo 'server 172.17.8.232 iburst' >> /etc/ntp.conf
            systemctl restart ntpd && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
        fi
    else
        echo -e "\033[31;40m 系统时间同步服务未开启，不符合标准，请及时进行配置 \033[0m"
        yum install ntp -y
        echo 'server 172.17.8.232 iburst' >> /etc/ntp.conf
        systemctl restart ntpd && echo -e "\033[32;40m 修改成功 \033[0m" || echo -e "\033[31;40m 修改失败 \033[0m"
		systemctl enable  ntpd
    fi
#检查ntpd服务状态
ntpq -pn
}

Check_Password_Policy
Check_User_Policy
Check_Useless_Service
Check_Tty_Timeout
Check_Auth_Failed
Check_SNmp_Service
Check_Log_Service
Check_NTP_Service

echo "将重新检查一次系统相关漏洞情况，请稍等"
sleep  3
###################################################################################################################
#查看系统账户策略:密码失效时间90天、密码到期提醒时间14天
Check_Pass_Poli=`grep  -E "^PASS_MAX_DAYS|^PASS_WARN_AGE"  /etc/login.defs | wc -l`
if  [ $Check_Pass_Poli -lt 2 ];then
    echo -e "\033[31;40m当前系统未对账户密码进行失效时间设置、密码到期提醒设置\033[0m"
else
    PAMAX=`grep  -E "^PASS_MAX_DAYS"  /etc/login.defs | awk -F" " '{ print $2 }'`
    PAWARN=`grep  -E "^PASS_WARN_AGE"  /etc/login.defs | awk -F" " '{ print $2 }'`
    if [ $PAMAX -le 90 ];then     echo -e "\033[32;40m密码失效时间为$PAMAX天，符合标准\033[0m"; else     echo -e "\033[31;40m密码失效时间为$PAMAX天，不符合标准\033[0m"; fi
    if [ $PAWARN -ge 14 ];then    echo -e "\033[32;40m密码到期提醒时间为$PAWARN天，符合标准\033[0m"; else     echo -e "\033[31;40m密码到期提醒时间为$PAWARN天，不符合标准\033[0m"; fi
fi


#查看系统账户策略:密码最小长度12位、密码复杂度为大小写英文字母、数字、特殊字符
Check_User_Poli=`grep -E "^minlen|^minclass"  /etc/security/pwquality.conf |wc -l`

if  [ $Check_User_Poli -lt 2 ];then
    echo -e "\033[31;40m当前系统未对账户密码复杂度及密码最小长度设置\033[0m"
else
    PACLS=`grep  -E "^minclass"  /etc/security/pwquality.conf | awk -F"=| " '{ print $NF }'`
    PALEN=`grep  -E "^minlen"   /etc/security/pwquality.conf | awk -F"=| " '{ print $NF }'`
    if [ $PACLS -eq 4 ];then     echo -e "\033[32;40m密码负责度为$PACLS种类型，符合标准\033[0m"; else     echo -e "\033[31;40m密码负责度为$PACLS种类型，不符合标准\033[0m"; fi
    if [ $PALEN -ge 12 ];then    echo -e "\033[32;40m密码长度为$PALEN位，符合标准\033[0m"; else     echo -e "\033[31;40m密码长度为$PALEN位，不符合标准\033[0m"; fi
fi	

#检查不必要的服务
Check_Use_Ser_post=`systemctl  status  postfix | grep Active | grep running | wc -l`
Check_Use_Ser_dhcp=`systemctl  status  dhcpd| grep Active | grep running | wc -l`

if [ $Check_Use_Ser_post -eq 0 ];then     echo -e "\033[32;40m postfix服务 处于关闭状态，符合标准\033[0m"; else     echo -e "\033[31;40m postfix服务 处于开启状态，不符合标准，请检查开启的必要性\033[0m"; fi

if [ $Check_Use_Ser_dhcp -eq 0 ];then     echo -e "\033[32;40m dhcp服务 处于关闭状态，符合标准\033[0m"; else     echo -e "\033[31;40m dhcp服务 处于开启状态，不符合标准，请检查开启的必要性\033[0m"; fi

#检查用户登陆超时退出时间
Check_Tty_Timeout=`grep -E "^ClientAliveInterval|^ClientAliveCountMax"  /etc/ssh/sshd_config |wc -l`

if  [ $Check_Tty_Timeout -lt 2 ];then
    echo -e "\033[31;40m当前系统未对用户登陆超时退出设置\033[0m"
else
    USRINT=`grep  -E "^ClientAliveInterval"  /etc/ssh/sshd_config | awk -F"=| " '{ print $NF }'`
    USRCOT=`grep  -E "^ClientAliveCountMax"   /etc/ssh/sshd_config | awk -F"=| " '{ print $NF }'`
    COUNT_time=`expr $USRINT \* $USRCOT`
    if [ $USRINT -lt 60 ];then
        echo -e "\033[31;40m 用户登陆超时退出设置为 $COUNT_time，不符合标准 \033[0m"
    elif [ $COUNT_time -le 300 ];then
        echo -e "\033[32;40m 用户登陆超时退出设置正确，符合标准 \033[0m"
    else
        echo -e "\033[31;40m 用户登陆超时退出设置为 $COUNT_time，不符合标准 \033[0m"
    fi
fi	

#查看连续认证失败次数
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

#查看snmp 服务状态
Check_SNmp_Ser=`ss -anplt | grep :199 | grep -v grep | wc -l`
if [ $Check_SNmp_Ser -eq 0 ];then
    echo -e "\033[32;40m 系统snmpd服务处于关闭状态，符合标准 \033[0m"
else
    echo -e "\033[31;40m 系统snmpd服务处于开启状态，不符合标准，请检查开启的必要性 \033[0m"
fi

#查看日志服务状态
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

#检查日志记录到messages中的配置是否成功
LogPATH=`grep PROMPT_COMMAND  /etc/profile | grep -vE "^#" |wc -l`
if [ $LogPATH -eq 1 ];then
    echo -e "\033[32;40m 系统日志命令记录到messages中配置成功，符合标准 \033[0m"
else
    echo -e "\033[31;40m 系统日志命令记录到messages中未配置，请做好记录 \033[0m"
fi

#检查ntp服务状态
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


