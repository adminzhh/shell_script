#!/bin/bash

# 定义日志文件路径
LOG_FILE="/root/autocal95/prtg/Auto_eachnode_95th.log"

# 创建日志目录（如果不存在）
mkdir -p "$(dirname "$LOG_FILE")"

# 将所有输出重定向到日志文件
exec > "$LOG_FILE" 2>&1

PRTG_SERVER="*****"
USERNAME="*****"
PASSHASH="****6"
DINGTALK_WEBHOOK="https://oapi.dingtalk.com/robot/send?access_token=******************"

# 记录脚本开始时间
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# 节点配置数组 - 在这里管理所有节点
NODES=(
    "郑州联通金闲100G:5003"
    "濮阳联通金闲70G:5028,5029,5030,5031,5032,5033,5034"
    "辽宁鞍山30G:4887"
    "郑州联通金晚50G:5008,5009,5010,5011,5012"
    "濮阳联通金晚50G:5021,5022,5023,5024,5025"
    "濮阳联通30G_04节点:3671,3672,3673"
    "濮阳联通30G_05节点:3678,3679,3680"
    "字节跳动200G:4296,4297"
    "金闲50G_任一鹏:4828,4829,4830,4831,4832"
)

# 获取上个月的年份和月份
get_previous_month() {
    CURRENT_DATE=$(date +%Y-%m-%d)
    PREVIOUS_MONTH_FIRST_DAY=$(date -d "$CURRENT_DATE -1 month" +%Y-%m-01)
    PREVIOUS_YEAR=$(date -d "$PREVIOUS_MONTH_FIRST_DAY" +%Y)
    PREVIOUS_MONTH=$(date -d "$PREVIOUS_MONTH_FIRST_DAY" +%m)
    PREVIOUS_MONTH_LAST_DAY=$(date -d "$PREVIOUS_MONTH_FIRST_DAY +1 month -1 day" +%d)
    PREVIOUS_MONTH_DAYS=$((10#$PREVIOUS_MONTH_LAST_DAY))
    
    echo "$PREVIOUS_YEAR $PREVIOUS_MONTH $PREVIOUS_MONTH_DAYS"
}

# 计算月95值（特殊节点专用方法）
calculate_monthly_95() {
    local sensor_ids=("$@")
    local year="$1"
    local month="$2"
    local days="$3"
    
    # 移除前三个参数（年份、月份、天数）
    shift 3
    sensor_ids=("$@")
    
    START_DATE="${year}-${month}-01-00-00-00"
    END_DATE="${year}-${month}-${days}-23-59-59"
    
    # 获取所有传感器的数据
    local i=1
    for sensor_id in "${sensor_ids[@]}"; do
        curl -s -k "http://${PRTG_SERVER}/api/historicdata.json?id=${sensor_id}&avg=300&sdate=${START_DATE}&edate=${END_DATE}&username=${USERNAME}&passhash=${PASSHASH}&columns=datetime,value,value_raw,coverage" | \
        grep -o '"value_raw":[0-9.]*' | sed 's/"value_raw"://' | awk "NR % 8 == 5" > "temp_sensor${i}.txt"
        i=$((i+1))
    done
    
    # 合并计算
    local paste_cmd="paste"
    for ((j=1; j<i; j++)); do
        paste_cmd="$paste_cmd temp_sensor${j}.txt"
    done
    
    eval "$paste_cmd" | awk '{
        sum = 0
        for(i=1; i<=NF; i++) sum += $i
        printf "%.3f\n", sum 
    }' > temp_sum.txt
    
    # 计算95值
    local total_points=$(wc -l < temp_sum.txt)
    local position=$(echo "$total_points" | awk '{result = $1 * 0.05; print (result == int(result)) ? result : int(result) + 1}')
    local monthly_95=$(sort -nr temp_sum.txt | awk "NR == $position {printf \"%.4f\", \$1 * 8 / 1000000000}")
    
    # 清理临时文件
    rm -f temp_sensor*.txt temp_sum.txt
    
    echo "$monthly_95"
}

# 获取上个月信息
read -r YEAR MONTH DAYS_IN_MONTH <<< "$(get_previous_month)"

echo "================================================"
echo "📊 PRTG日95值自动计算报告"
echo "================================================"
echo "📅 计算月份: $YEAR年$MONTH月 ($DAYS_IN_MONTH天)"
echo "⏰ 计算开始时间: $START_TIME"
echo "🔢 节点数量: ${#NODES[@]}个"
echo "================================================"
echo ""

# 创建结果表格头
printf "%-25s %-15s %-15s\n" "节点名称" "月95值(Gbit/s)" "加价后(Gbit/s)"
printf "%-25s %-15s %-15s\n" "-------------------------" "---------------" "---------------"

# 存储所有节点结果的关联数组
declare -A NODE_RESULTS

# 处理每个节点
for NODE_CONFIG in "${NODES[@]}"; do
    # 解析节点配置
    IFS=':' read -r NODE_NAME SENSOR_IDS <<< "$NODE_CONFIG"
    IFS=',' read -ra SENSOR_ID_ARRAY <<< "$SENSOR_IDS"
    
    # 特殊处理字节跳动200G和金闲50G_任一鹏节点
    if [[ "$NODE_NAME" == "字节跳动200G" || "$NODE_NAME" == "金闲50G_任一鹏" ]]; then
        MONTHLY_95=$(calculate_monthly_95 "$YEAR" "$MONTH" "$DAYS_IN_MONTH" "${SENSOR_ID_ARRAY[@]}")
        if [[ -n "$MONTHLY_95" && "$MONTHLY_95" != "0.0000" ]]; then
            # 字节跳动加1.5%，其他加2%
            if [[ "$NODE_NAME" == "字节跳动200G" ]]; then
                MONTHLY_95_PLUS=$(echo "scale=4; $MONTHLY_95 * 1.015" | bc -l)
            else
                MONTHLY_95_PLUS=$(echo "scale=4; $MONTHLY_95 * 1.02" | bc -l)
            fi
            printf "%-25s %-15.4f %-15.4f\n" "$NODE_NAME" "$MONTHLY_95" "$MONTHLY_95_PLUS"
            
            # 存储结果到关联数组
            NODE_RESULTS["${NODE_NAME}_95"]="$MONTHLY_95"
            NODE_RESULTS["${NODE_NAME}_plus"]="$MONTHLY_95_PLUS"
        else
            printf "%-25s %-15s %-15s\n" "$NODE_NAME" "无数据" "无数据"
            # 存储无数据结果
            NODE_RESULTS["${NODE_NAME}_95"]="无数据"
            NODE_RESULTS["${NODE_NAME}_plus"]="无数据"
        fi
        continue
    fi
    
    # 存储每天的95值
    DAILY_VALUES=()
    
    # 循环处理每一天
    for day in $(seq -w 1 $DAYS_IN_MONTH); do
        START_DATE="${YEAR}-${MONTH}-${day}-00-00-00"
        END_DATE="${YEAR}-${MONTH}-${day}-23-59-59"
        
        # 获取每个传感器的数据
        TEMP_FILES=()
        for i in "${!SENSOR_ID_ARRAY[@]}"; do
            SENSOR_ID="${SENSOR_ID_ARRAY[$i]}"
            TEMP_FILE="temp_${NODE_NAME}_${i}_${day}.txt"
            TEMP_FILES+=("$TEMP_FILE")
            
            # 构建API URL并获取数据
            API_URL="http://${PRTG_SERVER}/api/historicdata.json?id=${SENSOR_ID}&avg=300&sdate=${START_DATE}&edate=${END_DATE}&username=${USERNAME}&passhash=${PASSHASH}&columns=datetime,value,value_raw,coverage"
            
            curl -s -k "$API_URL" 2>/dev/null | \
            grep -o '"value_raw":[0-9.]*' | \
            sed 's/"value_raw"://' | \
            awk "NR % 8 == 5" > "$TEMP_FILE"
            
            sleep 0.2
        done
        
        # 合并计算（多传感器求和）
        if [[ ${#SENSOR_ID_ARRAY[@]} -gt 1 ]]; then
            paste "${TEMP_FILES[@]}" 2>/dev/null | awk '{ 
                sum = 0 
                for(i=1; i<=NF; i++) sum += $i 
                printf "%.3f\n", sum 
            }' > "temp_daily_sum_${NODE_NAME}_${day}.txt"
            DAILY_FILE="temp_daily_sum_${NODE_NAME}_${day}.txt"
        else
            DAILY_FILE="${TEMP_FILES[0]}"
        fi
        
        # 计算日95值
        if [[ -s "$DAILY_FILE" ]]; then
            DAILY_95TH=$(sort -nr "$DAILY_FILE" 2>/dev/null | awk "NR == 15 {printf \"%.4f\", \$1 * 8 / 1000000000}" 2>/dev/null)
            if [[ -n "$DAILY_95TH" && "$DAILY_95TH" != "0.0000" ]]; then
                DAILY_VALUES+=("$DAILY_95TH")
            fi
        fi
        
        # 清理临时文件
        rm -f "${TEMP_FILES[@]}" "temp_daily_sum_${NODE_NAME}_${day}.txt" 2>/dev/null
    done
    
    # 计算月统计
    if [[ ${#DAILY_VALUES[@]} -gt 0 ]]; then
        # 计算平均值
        SUM=0
        for value in "${DAILY_VALUES[@]}"; do
            SUM=$(echo "$SUM + $value" | bc -l 2>/dev/null)
        done
        MONTH_AVG=$(echo "scale=4; $SUM / ${#DAILY_VALUES[@]}" | bc -l 2>/dev/null)
        MONTH_AVG_PLUS=$(echo "scale=4; $MONTH_AVG * 1.02" | bc -l 2>/dev/null)
        
        # 输出结果
        printf "%-25s %-15.4f %-15.4f\n" "$NODE_NAME" "$MONTH_AVG" "$MONTH_AVG_PLUS"
        
        # 存储结果到关联数组
        NODE_RESULTS["${NODE_NAME}_95"]="$MONTH_AVG"
        NODE_RESULTS["${NODE_NAME}_plus"]="$MONTH_AVG_PLUS"
    else
        printf "%-25s %-15s %-15s\n" "$NODE_NAME" "无数据" "无数据"
        # 存储无数据结果
        NODE_RESULTS["${NODE_NAME}_95"]="无数据"
        NODE_RESULTS["${NODE_NAME}_plus"]="无数据"
    fi
done

# 记录脚本完成���间
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo ""
echo "================================================"
echo "✅ 计算完成!"
echo "📅 数据月份: $YEAR年$MONTH月"
echo "⏰ 开始时间: $START_TIME"
echo "⏰ 完成时间: $END_TIME"
echo "================================================"

# 计算执行时长
calculate_duration() {
    local start_seconds=$(date -d "$START_TIME" +%s)
    local end_seconds=$(date -d "$END_TIME" +%s)
    local duration=$((end_seconds - start_seconds))
    
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}小时${minutes}分钟${seconds}秒"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}分钟${seconds}秒"
    else
        echo "${seconds}秒"
    fi
}

DURATION=$(calculate_duration)

# 发送到钉钉机器人
send_to_dingtalk() {
    # 生成动态消息内容
    local message="## $YEAR年$MONTH月各节点95播报\\n\\n"
    message+="🕐 数据月份: <font color=\\\"#FF0001\\\">$YEAR</font>年<font color=\\\"#FF0001\\\">$MONTH</font>月 (<font color=\\\"#FF0001\\\">$DAYS_IN_MONTH</font>天)\\n\\n"
    message+="🕐 计算开始: <font color=\\\"#FF0001\\\">$START_TIME</font>\\n\\n"
    message+="🔢 节点数量: <font color=\\\"#FF0001\\\">${#NODES[@]}</font>个\\n\\n"
    message+="-----------------------------\\n\\n"
    
    # 动态添加每个节点的信息
    for NODE_CONFIG in "${NODES[@]}"; do
        IFS=':' read -r NODE_NAME SENSOR_IDS <<< "$NODE_CONFIG"
        
        # 获取节点结果
        local node_95="${NODE_RESULTS["${NODE_NAME}_95"]}"
        local node_plus="${NODE_RESULTS["${NODE_NAME}_plus"]}"
        
        # 确定节点类型和显示文本
        local value_type="日95月平均值"
        if [[ "$NODE_NAME" == "字节跳动200G" || "$NODE_NAME" == "金闲50G_任一鹏" ]]; then
            value_type="月95值"
        fi
        
        # 添加节点信息到消息
        message+="**${NODE_NAME}**\\n\\n"
        message+="📈 ${value_type}: <font color=\\\"#FF0001\\\">${node_95}</font> Gbit/s\\n\\n"
        
        # 确定加价比例
        local plus_text="加2%值"
        if [[ "$NODE_NAME" == "字节跳动200G" ]]; then
            plus_text="加1.5%值"
        fi
        
        message+="📈 ${plus_text}: <font color=\\\"#FF0001\\\">${node_plus}</font> Gbit/s\\n\\n"
        message+="-----------------------------\\n\\n"
    done
    
    message+="✅ 计算完成!\\n\\n"
    message+="🕐 数据月份: <font color=\\\"#FF0001\\\">$YEAR</font>年<font color=\\\"#FF0001\\\">$MONTH</font>月\\n\\n"
    message+="🕐 完成时间: <font color=\\\"#FF0001\\\">$END_TIME</font>\\n\\n"
    message+="⏰ 执行时长: <font color=\\\"#FF0001\\\">$DURATION</font>\\n\\n"
    message+=" @156***5126"
    
    # 构建JSON数据
    local json_data=$(cat <<EOF
{
    "msgtype": "markdown",
    "markdown": {
        "title": "PRTG-计算各节点每月95值",
        "text": "$message"
    },
    "at": {
        "atMobiles": [
            "156***85126"
        ],
        "isAtAll": false
    }
}
EOF
)
    
    # 发送请求到钉钉机器人
    echo "正在发送钉钉消息..."
    curl_response=$(curl -s -k -H "Content-Type: application/json" -X POST -d "$json_data" "$DINGTALK_WEBHOOK")
    
    # 检查是否发送成功
    if echo "$curl_response" | grep -q '"errcode":0'; then
        echo "✅ 钉钉消息发送成功"
    else
        echo "❌ 钉钉消息发送失败: $curl_response"
    fi
}

# 调用函数发送消息
send_to_dingtalk

# 在日志文件末尾添加两个空行
echo ""
echo ""
