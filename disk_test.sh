#!/bin/bash
echo -e "\e[32m==============本机器的磁盘使用情况如下:=================\e[0m"
lsblk
echo
echo -e "\e[32m==============本机器的NVMe硬盘列表如下:==============\e[0m"
if ! command -v nvme &> /dev/null;then
  echo -e "\e[34m未检测到有nvme相关命令，尝试安装 nvme-cli...\e[0m"  
  yum -y install nvme-cli > /dev/null 2>&1
  if [ $? -ne 0 ];then
    echo -e "\e[34m安装失败，准备更换镜像源...\e[0m"
    # 备份原配置
    backup=/etc/yum.repos.d/`date +%F-%T`.backup
    mkdir -p $backup
    sudo mv /etc/yum.repos.d/*.repo $backup  &>/dev/null   
    # 添加CentOS-7镜像源
    sudo curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null
    sudo curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo &> /dev/null
    echo -e "\e[34m尝试通过新镜像源安装nvme-cli...\e[0m"
    yum clean all &> /dev/null  && yum makecache &> /dev/null
    yum -y install nvme-cli &> /dev/null
    if [ $? -ne 0 ];then
      echo -e "\e[31m错误：无法安装nvme-cli，请检查网络连接或手动安装\e[0m"
      exit 1
    else
      echo -e "\e[34me-cli安装成功\e[0m"
    fi
  else 
    echo -e "\e[34mnvme-cli安装成功\e[0m"
  fi 
fi
nvme list
sn=`nvme list | awk '/\/dev\//{print $2}'`
echo "$sn" | while read -r num; do
  echo
  # 创建和sn号相同名称的目录
  dir=~/"$num"_test
  if [ ! -d "$dir" ];then
    echo -e "\e[32m============正在测试SN:"$num" 的NVMe固态硬盘=============\e[0m"
    # 定义一个dev变量，值是通过awk过滤sn号来抓取的硬盘路径
    mkdir $dir  && dev=`nvme list | awk -v target_sn="$num" '$0 ~ target_sn {print $1}'` 
    # 把dev变量里的设备路径对应的硬盘设备格式化成ext4文件系统，并挂载
    mkfs.ext4 $dev &> /dev/null && mount $dev $dir
    if [ $? -ne 0 ];then
      echo -e "\e[31m错误：格式化硬盘或挂载目录时出现了问题。\e[0m"
      exit 1
    else
      echo -e "\e[34mSN:"$num" 的NVMe固态硬盘挂载到了"$dir"目录中进行测试\e[0m"
      cd $dir 
      echo -e "\e[34m正在执行dd命令来创建测试文件... \e[0m"
      dd if=/dev/zero of=test.test bs=1G count=100 &> /dev/null
      if [ $? -ne 0 ];then
        echo -e "\e[31m错误：执行dd命令来创建测试文件时失败\e[0m"
        exit 1
      fi
      echo -e "\e[34m测试文件已创建，正在使用fio命令来测试硬盘的读写速度，请稍等... \e[0m"
      if ! command -v fio &> /dev/null;then
        yum -y install fio &> /dev/null
      fi
      fio -filename=test.test -direct=0 -iodepth 1 -thread -rw=randrw -rwmixread=80 -ioengine=psync -bs=256k -size=10G -numjobs=1 -runtime=180 -group_reporting -name=randrw_80read_256k > ./test.log
      if [ ! -f ~/disk_test.log ];then
        touch ~/disk_test.log
      fi
      echo
      echo -e "\e[32m==============================SN:"$num"测试结果如下：===================================== \e[0m" | tee -a ~/disk_test.log
      cat ./test.log | awk '/read: /{print $0}' | tee -a  ~/disk_test.log
      cat ./test.log | awk '/write: /{print $0}' | tee -a ~/disk_test.log
      read=`cat ./test.log  | awk -F '[=,]' '/read: /{print $2}'`
      write=`cat ./test.log  | awk -F '[=,]' '/write: /{print $2}'`
      if [ $read -gt 1000 ];then
        echo  "测试合格，该盘可以正常使用!!!" | tee -a ~/disk_test.log
      else 
        echo -e "\e[31m测试不合格，该盘不能正常使用\e[0m" | tee -a ~/disk_test.log
      fi
    fi
  else
    old_dev=`cat ~/disk_test.log | grep -i "$num" -A3 | grep -v "$num"`
    echo -e "\e[32m=================================SN:"$num"的NVMe固态硬盘已测试过，测试结果如下：===================================\e[0m"
    echo "$old_dev"
  fi
done 
