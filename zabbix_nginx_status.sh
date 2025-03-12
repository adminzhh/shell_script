#!/bin/bash
# 接受脚本的第一个参数
# 由于nginx的status状态太多，写为一个接受参数的key
NGINX_COMMAND=$1
CACHEFILE="/tmp/nginx_status.log"

CMD="/usr/bin/curl http://127.0.0.1/nginx_status"

# 判断是否有status日志文件
if [ ! -f $CACHEFILE ];then
    $CMD >$CACHEFILE 2>/dev/null
fi


# 检查status日志有效期，限定状态文件在60秒内
# 记录最后一次status日志的生成时间（秒），是距离unix时间的秒数
STATUS_TIME=$(stat -c %Y $CACHEFILE)

# 以unix时间计算，seconds since 1970-01-01 00:00:00 UTC
# 获取当前系统距离unix时间的秒数
TIMENOW=$(date +%s)

# 当前系统时间减去日志时间，推算，是否超过60秒，超过就立即重新生成，确保日志是拿到的是最新的数据
if [  $[ $TIMENOW - $STATUS_TIME ]  -gt 60 ];then
    rm -f $CACHEFILE
fi

if [ ! -f $CACHEFILE ];then
    $CMD > $CACHEFILE 2>/dev/null 
fi

# 定义多个函数，方便下面case语句调用，不定义也行，但是不专业啊
nginx_active(){
    grep 'Active' $CACHEFILE |awk '{print $NF}'
    exit 0;
}

nginx_reading(){
    grep 'Reading' $CACHEFILE |awk '{print $2}'
    exit 0;
}

nginx_writing(){
    grep 'Writing' $CACHEFILE |awk '{print $4}'
    exit 0;
}

nginx_waiting(){
    grep 'Waiting' $CACHEFILE |awk '{print $6}'
    exit 0;
}

nginx_accepts(){
    awk NR==3 $CACHEFILE|awk '{print $2}'
    exit 0;
}

nginx_handled(){
    awk NR==3 $CACHEFILE|awk '{print $2}'
    exit 0;
}

nginx_requests(){
    awk NR==3 $CACHEFILE|awk '{print $3}'
    exit 0;
}


# 对脚本传入参数判断，调用上面定义的函数
# 最后的结果都是nginx的链接状态
case $NGINX_COMMAND in 
    active)
        nginx_active ;;
    reading)
        nginx_reading;;
    writing)
        nginx_writing;;
    waiting)
        nginx_waiting;;
    accepts)
        nginx_accepts;;
    handled)
        nginx_handled;;
    requests)
        nginx_requests;;
    *)
        echo "Invalid arguments" 
        exit 2
        ;;
esac

#在nginx服务器上安装zabbix-agent
#在Zabbix-agent的子配置文件中，启用自定义监控功能
#定义一个新的UserParameter，监控脚本
#vim /etc/zabbix/zabbix_agentd.d/nginx_status.conf
#UserParameter=nginx_status[*],/usr/local/bin/nginx_status.sh $1
#然后再zabbixui界面里添加自定义监控项，键值输入nginx_status[active]......
