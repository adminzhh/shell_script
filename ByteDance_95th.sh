#!/bin/bash

API_BASE="http://*******/api/historicdata.csv"
USERNAME="**"
PASSHASH="***"
SENSOR_IDS=("***" "***")
AVG="300"
COLUMNS="datetime,value,value_raw,coverage"
DINGTALK_WEBHOOK="https://oapi.dingtalk.com/robot/send?access_token=***********************"

# 获取当前日期
CURRENT_YEAR=$(date +%Y)
CURRENT_MONTH=$(date +%m)
CURRENT_DAY=$(date +%d)
current_hour=$(date +%H)

# 计算当月第一天和最后一天
FIRST_DAY="${CURRENT_YEAR}-${CURRENT_MONTH}-01"
LAST_DAY=$(date -d "${FIRST_DAY} +1 month -1 day" +%Y-%m-%d)
LAST_DAY_DAY=$(date -d "${FIRST_DAY} +1 month -1 day" +%d)
SDATE="${FIRST_DAY}-00-00-00"

# 设置查询时间范围
if [ "$current_hour" -gt 16 ];then
  EDATE="${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}-17-00-00"
else
  EDATE="${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}-09-00-00"
fi
# 临时文件
CSV_FILES=()
TXT_FILES=()
RESULT_FILE="sum.txt"

#echo "采集时间范围: ${SDATE} 到 ${EDATE}"

# 获取传感器数据
for i in "${!SENSOR_IDS[@]}"; do
    SENSOR_ID=${SENSOR_IDS[$i]}
    CSV_FILE="$((i+1)).csv"
    TXT_FILE="$((i+1)).txt"
    
    CSV_FILES+=("$CSV_FILE")
    TXT_FILES+=("$TXT_FILE")
    
    # 构建API请求URL
    API_URL="${API_BASE}?id=${SENSOR_ID}&avg=${AVG}&sdate=${SDATE}&edate=${EDATE}&username=${USERNAME}&passhash=${PASSHASH}&columns=${COLUMNS}"
    
 #   echo "获取传感器 ${SENSOR_ID} 数据..."
    curl -s -k "$API_URL" > "$CSV_FILE"
    
    # 处理CSV文件，提取value_raw数据
    sed '1d;$d;N;$d' "$CSV_FILE" | awk -F \" '{print $24}' > "$TXT_FILE"
    
    if [ ! -s "$TXT_FILE" ]; then
        echo "警告: 传感器 ${SENSOR_ID} 未获取到数据"
    fi
done

# 检查文件是否存在且非空
if [ ! -s "${TXT_FILES[0]}" ] || [ ! -s "${TXT_FILES[1]}" ]; then
    echo "错误: 数据文件为空，无法继续处理"
    rm -f "${CSV_FILES[@]}" "${TXT_FILES[@]}" "$RESULT_FILE" 2>/dev/null
    exit 1
fi

# 合并并计算总和
paste "${TXT_FILES[0]}" "${TXT_FILES[1]}" | awk '{ 
    sum = 0 
    for(i=1; i<=NF; i++) sum += $i 
    printf "%.3f\n", sum 
}' > "$RESULT_FILE"

# 计算统计信息
TOTAL_POINTS=$(wc -l < "$RESULT_FILE")
DAILY_95_POINT=$(echo "$TOTAL_POINTS" | awk '{result = $1 * 0.05; print (result == int(result)) ? result : int(result) + 1}')

# 计算最大值
MAX_VALUE=$(sort -nr "$RESULT_FILE" | head -1)
MAX_VALUE_GBIT=$(echo "$MAX_VALUE * 8 / 1000000000" | bc -l | awk '{printf "%.4f", $1}')

# 查找最大值所在的行
MAX_LINE_NUM=$(grep -n "^${MAX_VALUE}$" "$RESULT_FILE" | cut -d: -f1 | head -1)

# 获取最大值的时间点
if [ -n "$MAX_LINE_NUM" ]; then
    # 注意：CSV文件中的行号需要调整，因为我们去除了第一行和最后两行
    # 实际CSV中的行号 = MAX_LINE_NUM + 1 (跳过标题行)
    CSV_LINE_NUM=$((MAX_LINE_NUM + 1))
    MAX_TIMESTAMP=$(awk -F \" "NR==${CSV_LINE_NUM} {print \$2}" "${CSV_FILES[0]}")
else
    MAX_TIMESTAMP="未知"
fi

# 计算当天95值
DAILY_95_VALUE=$(sort -nr "$RESULT_FILE" | awk "NR == $DAILY_95_POINT {printf \"%.4f\", \$1 * 8 / 1000000000}")

# 计算433点位95值
if [ "$TOTAL_POINTS" -ge 433 ]; then
    VALUE_433=$(sort -nr "$RESULT_FILE" | awk "NR == 433 {printf \"%.4f\", \$1 * 8 / 1000000000}")
else
    VALUE_433="N/A (数据点不足433个)"
fi

# 输出结果
echo "采集时间范围: $SDATE 到 $EDATE" >> /root/autocal95/prtg/ByteDance_95th.log
echo "总共采集点数: $TOTAL_POINTS" >> /root/autocal95/prtg/ByteDance_95th.log
echo "当前95点位: $DAILY_95_POINT，95值: ${DAILY_95_VALUE} Gbit/s" >> /root/autocal95/prtg/ByteDance_95th.log
echo "当月最大值: ${MAX_VALUE_GBIT} Gbit/s，时间点: ${MAX_TIMESTAMP}" >> /root/autocal95/prtg/ByteDance_95th.log
echo "当前433点位95值: ${VALUE_433} Gbit/s" >> /root/autocal95/prtg/ByteDance_95th.log

# 发送到钉钉机器人
send_to_dingtalk() {
    local message="$1"
    # 构建JSON数据
    local json_data=$(cat <<EOF
{
    "msgtype": "markdown",
    "markdown": {
        "title": "*****95计算-PRTG",
        "text":  "## *****95计算-PRTG\n\n🕐采集时间范围: <font color=\"red\">${SDATE}</font> 到 <font color=\"red\">${EDATE}</font>\n\n📊总共采集点数: <font color=\"red\">${TOTAL_POINTS}</font>\n\n🔢当前95点位: <font color=\"red\">${DAILY_95_POINT}</font>\n\n📈当前95值: <font color=\"red\">${DAILY_95_VALUE}</font> Gbit/s\n\n🚀当月最大值: <font color=\"red\">${MAX_VALUE_GBIT}</font> Gbit/s\n\n🕐最大值时间点: <font color=\"red\">${MAX_TIMESTAMP}</font>\n\n📈当前433点位95值: <font color=\"red\">${VALUE_433}</font> Gbit/s"
    }
}
EOF
)
    
    # 发送请求到钉钉机器人
    curl -s -k -H "Content-Type: application/json" -X POST -d "$json_data" "$DINGTALK_WEBHOOK" > /dev/null
    
    # 检查是否发送成功
    if [ $? -eq 0 ]; then
        echo "消息已成功发送到钉钉" >> /root/autocal95/prtg/ByteDance_95th.log
        echo >> /root/autocal95/prtg/ByteDance_95th.log
        echo >> /root/autocal95/prtg/ByteDance_95th.log
    else
        echo "发送消息到钉钉失败" >> /root/autocal95/prtg/ByteDance_95th.log
        echo >> /root/autocal95/prtg/ByteDance_95th.log
        echo >> /root/autocal95/prtg/ByteDance_95th.log
    fi
}

# 调用函数发送消息
send_to_dingtalk
# 清理临时文件
rm -f "${CSV_FILES[@]}" "${TXT_FILES[@]}" "$RESULT_FILE" 2>/dev/null
