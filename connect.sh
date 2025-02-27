#/bin/bash
# 获取TCP连接数  
tcp_count=$(ss -an | grep ^tcp | wc -l)  
# 获取UDP连接数  
udp_count=$(ss -an | grep ^udp | wc -l)  
# 输出结果  
echo "TCP 连接数: $tcp_count"  
echo "UDP 连接数: $udp_count"
