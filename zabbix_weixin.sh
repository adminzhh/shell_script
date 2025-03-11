#!/bin/bash
#需要将下列信息修改为自己注册的企业微信信息


#企业ID 
corpid='ww85c033dee1*****'


#微信创建的应用ID
agentid='1000002'

#微信创建的应用的密钥，secretID
corpsecret='m6yErkQAUpW5Tq9lel6Jh73Gf9EU1A***********' 


#接受者的账户，由zabbix传入 
# 针对报警信息，发送给某单个人
#user=$1


#报警邮件标题，由zabbix传入 
# 该变量接受邮件标题的数据，
title=$2 

#报警邮件内容，由zabbix传入 
message=$3

# 接收信息的组
# 消息发给哪个组
# linux0224小分队，组id是 1 
group=$1 


#获取token信息，需要在链接里带入ID
# 如下2段代码，需要结合着跑
#这段代码是获取身份校验值，代表这个客户端是有权限和微信API通信的
# -s 安静执行
# -X GET 制定GET请求访问
# "https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=${corpid}&corpsecret=${corpsecret}"
# 这就是一个url，但是url是变量替换的一个字符串
# 你发送你的企业id号，和应用id号，发给微信的服务器，微信服务器会返回给你一个身份令牌字符串
# 下一步，你就可以用这个字符串代表你的身份，是有权限和微信的公众号通信了

token=$(curl -s -X GET "https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=${corpid}&corpsecret=${corpsecret}"|awk -F \" '{print $10}')


#构造语句执行发送动作，发送http请求
# 这个curl的作用详解
# 1.发送json类型的一堆数据
# 2.传入 部门id得值，脚本的第一个参数
# 3. 传入微信创建的应用的id
# 4. 传入text，消息数据体，分别是  title 和俩换行 和 message数据体

curl -s -H "Content-Type: application/json" -X POST "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=${token}" -d' {
   "toparty" : "'"${group}"'",
   "msgtype" : "text",
   "agentid" : "'"${agentid}"'",
   "text" : {
       "content" : "'"${title}\n\n${message}"'"
   },
   "safe":0
}' >> /tmp/weixin_bash.log

#将报警信息写入日志文件
echo -e "\n报警时间:$(date +%F-%H:%M)\n报警标题:${title}\n报警内容:${message}\n\n" >> /tmp/weixin_bash.log
