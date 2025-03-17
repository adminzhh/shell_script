#!/bin/bash
# 定义颜色
CLOR_A="\033[32;1m"
CLOR_B="\033[0m"
# 指定三台主机IP、指定Master节点网卡
# 获取这主机网卡名称
NET_CARD=`ifconfig | grep "192" -B 1 | sed -nr '/^e/s/(.*)(:.*)/\1/p'`

# 主节点IP
IP_MASTER="192.168.10.5"

# 本机IP
IP_HOST=`ip addr |sed -rn '/inet 192/s/(^.* )([0-9.]+)(\/.*$)/\2/p'`

# 基于发行版本类型,判断是否使用yum还是apt命令
RELEASE_TYPE=$(cat /etc/os-release |awk -F '=' '/ID_LIKE/{ print $2 }')

#  说明 ：IP 后空格紧跟主机名
entries=(
    "192.168.10.5 Master"
    "192.168.10.6 node-01"
)

#
##################### 函数体部分 ######################
function Docker(){
    # install docker
if [[ -e docker-27.4.1.tgz ]];then
	tar -zxvf docker-27.4.1.tgz && \cp -rf docker/* /usr/local/bin/
else    
	wget https://mirrors.aliyun.com/docker-ce/linux/static/stable/x86_64/docker-27.4.1.tgz > /dev/null
	tar -zxvf docker-27.4.1.tgz && \cp -rf docker/* /usr/local/bin/
fi
cat >/etc/systemd/system/docker.service <<-EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
 
[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker

ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
 
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/docker.socket <<EOF
[Unit]
Description=Docker Socket for the API

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

# 配置docker加速器，工作目录
mkdir -p /etc/docker && mkdir -p /data/docker
echo -e "\n配置docker加速器\n"
cat > /etc/docker/daemon.json <<-"EOF"
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
      "https://docker.1panel.live",
      "https://docker.1panel.dev",
      "https://docker.fxxk.dedyn.io",
      "https://docker.zhai.cm",
      "https://docker.5z5f.com",
      "https://a.ussh.net",
      "https://docker.m.daocloud.io"
  ],
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
      "max-size": "100m",
      "max-file": "10"
   },
  "default-shm-size": "128M",
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "debug": false,
  "experimental": true,
  "features": {
       "buildkit": true
  },
  "data-root": "/data/docker"
}
EOF
echo -e "启动容器服务\n"
systemctl daemon-reload
systemctl enable docker.socket --now docker.socket
systemctl enable docker.service --now docker.service
}

# 编写 Cri-dockerd 函数
function CriDokerd(){
echo -e "安装 cri-dockerd" 
	
if [[ -e "cri-dockerd-0.3.16.amd64.tgz" ]]; then
    echo -e "cri-dockerd-0.3.16.amd64.tgz文件已存在!"
else
    wget https://mirrors.chenby.cn/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.16/cri-dockerd-0.3.16.amd64.tgz
    # wget https://sourceforge.net/projects/cri-dockerd.mirror/files/v0.3.16/cri-dockerd-0.3.16.amd64.tgz
fi	
	
    tar -zxvf cri-dockerd-0.3.16.amd64.tgz
    \cp -rf cri-dockerd/cri-dockerd /usr/local/bin/
	
# 配置启动文件
cat > /etc/systemd/system/cri-docker.service <<-"EOF"
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket
	 
[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.10
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
	 
StartLimitBurst=3 
StartLimitInterval=60s
	 
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
	 
TasksMax=infinity
Delegate=yes
KillMode=process
	 
[Install]
WantedBy=multi-user.target
EOF
	
# 配置 socket 文件
cat > /etc/systemd/system/cri-docker.socket <<-EOF
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service

[Socket]
ListenStream=%t/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

# 开机启动  
systemctl daemon-reload
systemctl enable cri-docker --now cri-docker
echo -e "\n查看状态"
systemctl is-active cri-docker

}	

##################### 程序部分 ######################

echo -e "\n*******************************\n"
echo -e "请输入您要操作的序号~\n
\t1、部署kubernetes\n
\t2、部署 Calico-3.29.1 网络插件\n
\t3、初始化重置\n
\t4、重新生成 token\n
\t5、退出脚本"
echo -e "\n*******************************\n"
#
read num
#
case $num in
1) 

    echo -e "\n需要初始化的IP、主机名分别为：\n"
    for i in "${entries[@]}"; do
	echo "$i"
    done

echo ""
read -p "确认以上IP地址，确定初始化请按y,否则请按其他键~  " sure
if [[ "$sure" != "y" ]]; then
	echo -e "您已取消初始化操作！\n"
else
    # 基于发行版类型选择安装命令
    if [[ $RELEASE_TYPE = debian ]];then
	    COMMAND=apt
	    echo -e "\n1、关闭防火墙"
	    # 配置 k8s-1.28及以上的镜像源
	    systemctl stop ufw && systemctl disable ufw
	    # apt-transport-https 可能是一个虚拟包（dummy package）；如果是的话，你可以跳过安装这个包
	    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
	    #下载用于 Kubernetes 软件包仓库的公共签名密钥。	   
  	    # 如果 `/etc/apt/keyrings` 目录不存在，则应在 curl 命令之前创建它，请阅读下面的注释。
	    sudo mkdir -p -m 755 /etc/apt/keyrings
   	    #下载用于 Kubernetes 软件包仓库的公共签名密钥。
	    # 添加阿里云的APT密钥
	    curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/deb/Release.key |gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg	      # 添加阿里云的Kubernetes源
	    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list 	    
    else
	    COMMAND=yum
	    echo -e "\n1、关闭防火墙"
	    systemctl stop firewalld && systemctl disable firewalld
	    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
	    # 配置 k8s 镜像源
		cat <<-EOF | tee /etc/yum.repos.d/kubernetes.repo
		[kubernetes]
		name=Kubernetes
		baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/rpm/
		enabled=1
		gpgcheck=1
		gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/rpm/repodata/repomd.xml.key
		EOF
    fi

    echo -e "\n2、关闭selinux"
    setenforce 0

    # 安装基础软件包
    echo -e "\n3、安装基础软件包、更新apt源，升级系统"
    $COMMAND -y install git wget curl tar lrzsz tree vim chrony zip unzip net-tools telnet  psmisc lvm2 conntrack ipvsadm ipset bash-completion
    if [[ "$RELEASE_TYPE" = "debian" ]] ;then
	    $COMMAND install -y network-manager selinux-utils
    fi
    # 取消授权注册、或者将配置apt仓库的时候，修改gpgcheck=0,subscription-manager这个需要安装apt-utils
    sed -i '/enabled=1/s/1/0/g' /etc/apt/pluginconf.d/subscription-manager.conf 2> /dev/null
    sudo \cp -rf /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d &>/dev/null
    $COMMAND autoremove -y 2> /dev/null
    $COMMAND clean all && $COMMAND update -y &>/dev/null
    $COMMAND upgrade -y 2> /dev/null

    echo -e "\n4、禁用swap"
    sed -ri 's@^.*swap.*@# &@' /etc/fstab
    sudo swapoff -a
    echo -e "根据 k8s 要求禁用交换内存\n"

    echo -e "5、删除系统之前10网段的映射地址\n"
    sed -ri '/10\./d' /etc/hosts

    echo -e "6、配置主机映射\n"
    # 配置新的
    for i in "${entries[@]}"; do
        # 检查条目是否已经存在于 /etc/hosts
        if ! grep -qF -- "$i" /etc/hosts; then
            echo "$i" >> /etc/hosts
    	else
            echo "Entry '$i' already exists in /etc/hosts"
        fi
    done
    
    cat /etc/hosts
    
    echo -e "\n7、配置对容器虚拟网络的支持"

	cat >/etc/sysctl.conf <<-EOF
	net.bridge.bridge-nf-call-iptables = 1
	net.bridge.bridge-nf-call-ip6tables = 1
	net.ipv4.ip_forward = 1
	vm.swappiness = 0
	EOF

    # 永久生效
    echo net.ipv4.ip_forward=1 >>/etc/sysctl.conf
    
    # 添加网桥过滤和地址转发功能，转发IPv4并让iptables看到桥接流量
	cat >/etc/modules-load.d/k8s.conf <<-EOF
	overlay
	br_netfilter
	EOF
    
    systemctl restart systemd-modules-load.service
    echo -e "/etc/modules-load.d/k8s.conf 已配置"
    
    # 生效
    modprobe overlay
    modprobe br_netfilter

    sysctl --system >/dev/null 2>&1

    echo -e "\n查看（重启后）br_netfilter和 overlay模块是否加载成功\n"
    lsmod | egrep  "br_netfilter|overlay"

    # 安装ipset和ipvsadm，加载进内核，主要是对ipvs进行传递参数的或者管理的
    echo -e "\n配置ipvs\n"
    mkdir -p /etc/sysconfig/modules
	cat > /etc/sysconfig/modules/ipvs.modules <<-EOF
	#!/bin/bash
	ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_vip ip_vs_sed ip_vs_ftp nf_conntrack"
	for kernel_module in $ipvs_modules; 
	do
        	/sbin/modinfo -F filename $kernel_module >/dev/null 2>&1
        if [ $? -eq 0 ]; then
                /sbin/modprobe $kernel_module
        fi
	done
	chmod 755 /etc/sysconfig/modules/ipvs.modules
	EOF
    bash /etc/sysconfig/modules/ipvs.modules
    # 查看 ipvs 对应的模块是否加载成功,Linux kernel 4.19 版本已经将nf_conntrack_ipv4 更新为 nf_conntrack
    chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack 
    echo ""
    # 开机加载内核模块
    systemctl enable --now systemd-modules-load
    
    echo -e "\n8、同步同步aliyun时钟服务\n"
    # 设置时区为上海
    timedatectl set-timezone Asia/Shanghai

    # 将当前的 UTC 时间写入硬件时钟
    timedatectl set-local-rtc 0

    # 重启依赖于系统时间的服务（定时任务）
    systemctl restart cron 2> /dev/null crond 2>/dev/null
    
    # 同步阿里时钟（N读取同步第一个匹配行，也就是第一次，满足我的要求）
    mkdir -p /var/log/chrony    
    sed -i.bak '/^pool\|^server/{N;s/^pool.*/pool ntp.aliyun.com/;s/^server.*/pool ntp.aliyun.com/;}' /etc/chrony.conf
    
    # 强制手动同步
    chronyc makestep

    # 查看时钟同步状态、重启服务
    chronyc sources -v > /dev/null
    systemctl restart chronyd 2>/dev/null chrony 2>/dev/null
    systemctl enable chronyd 2>/dev/null chrony 2>/dev/null
    
    # 优化系统，设置句柄数
    echo -e "\n9、优化系统，设置句柄数~"
    if ! grep -qF -- '65535' /etc/sysctl.conf;then	
	echo 'fs.file-max=655350' >> /etc/sysctl.conf
    fi
    
    echo -e "\n已经修改句柄数为：$(sysctl -p | awk -F '=' '/file-max/{ print $2}')"
    echo -e "\n10、关闭postfix邮件服务"
    systemctl stop postfix 2>/dev/null && systemctl disable postfix 2>/dev/null

    echo -e "\n11、安装docker\n"
    # 启动docker并设置开机自启
    groupadd docker
    sudo usermod -aG docker $USER
    Docker
    
    # 调用启动函数 cri-dockerd
    CriDokerd
  
    # Docker buildx 是 Docker 官方维护的一个 CLI 插件，它基于 BuildKit 引擎,支持跨平台,用来构建容器镜像
    if [[ -e buildx-v0.19.3.linux-amd64 ]];then
	    echo ""
    else 
	    wget https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-amd64
    fi
    mkdir -p /usr/libexec/docker/cli-plugins	    
    chmod a+x buildx-v0.19.3.linux-amd64
    mv buildx-v0.19.3.linux-amd64 /usr/libexec/docker/cli-plugins/docker-buildx

    # 验证
    systemctl status docker | grep -o "Active: active (running)"

    echo -e "\n检查docker管理方式是否为systemd\n"
    docker info| grep "Cgroup Driver" && echo ""
    docker buildx version 
    
    #安装1.32 版本的k8s 
    echo -e "\n开始安装kubelet kubeadm kubectl,保持版本一致！\n"    
    #查看可安装的k8s版本
    yum list kubeadm --showduplicates 2>/dev/null | sort -r | grep "kubeadm.x86_64" && echo ""
    apt-cache policy kubeadm 2>/dev/null | sort -r | grep "kubeadm.x86_64"

    # 安装
    $COMMAND install -y kubelet kubeadm kubectl
    echo -e "\n使用kubeadm命令、查看当前k8s所需的镜像版本\n"
    kubeadm config images list && echo ""
    \cp -rf config.yaml /var/lib/kubelet
    # sed -ir "/$/s#ExecStart=/usr/bin/kubelet#& --container-runtime-endpoint unix:///run/crio-docker.sock#g" /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
    
    # 解决docker与k8s兼容性问题
	cat > /etc/sysconfig/kubelet <<-EOF
	KUBELET_EXTRA_ARGS="--runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice"
	KUBE_PROXY_MODE="ipvs"
	EOF
    systemctl restart kubelet && systemctl enable kubelet
    
    # 命令补全
    source /usr/share/bash-completion/bash_completion
    
    if ! grep "kubectl completion bash" ~/.bashrc;then 
        source <(kubectl completion bash)
        echo "source <(kubectl completion bash)" >> ~/.bashrc
    fi
    
    echo -e "\n\t$CLOR_A========= 系统环境初始化已完成 =========$CLOR_B\n"
fi
##################### Mster节点初始化 ######################

    echo -e "K8S初始化 ~\n"
    # 初始化系统所需镜像,部分镜像需要Master节点，有些在node节点也需要（要不然初始化狂报错）
    init_images=(kube-apiserver:v1.32.0
	kube-controller-manager:v1.32.0
	kube-scheduler:v1.32.0
	kube-proxy:v1.32.0
	coredns:v1.11.3
	pause:3.10
	etcd:3.5.16-0)

    echo -e "加载 Calico-3.29.1 网络插件容器镜像\n"

    # 删除 Calico 的残留文件
    rm -rf /etc/cni/net.d/*
    rm -rf /var/lib/calico /var/lib/cni

    # 提前拉取 calico-3.29.1 网络镜像
    # calico_images=(docker.io/calico/cni:v3.29.1
    #	docker.io/calico/node:v3.29.1
    #	docker.io/calico/kube-controllers:v3.29.1)
    # for imageName in ${images[@]} ; do
    #    docker pull $imageName
    # done

    # 离线加载镜像 
    tar -zxvf calico_v3_29_1.tar.gz
    calico_images=(cni.tar node.tar kube-controllers.tar)
    for imageName in ${calico_images[@]}; do
        docker load -i calico_v3.29.1/$imageName
    done
 
    if [[ $IP_MASTER != $IP_HOST ]];then
	docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v1.32.0
	docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:v1.11.3
	docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.10
	echo -e "\n检测到本机为非主节点，退出脚本！\n"
	exit
    else
    # 初始化方式一 
    # 生成初始化默认配置文件
    echo ""
    for imageName in ${init_images[@]} ; do
        docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
    done
	
    echo -e "\n生成初始化配置文件~\n" 
    kubeadm config print init-defaults > kubeadm.yaml
	cat >> kubeadm.yaml <<-EOF
	---
	apiVersion: kubeproxy.config.k8s.io/v1alpha1
	kind: KubeProxyConfiguration
	mode: ipvs
	---
	apiVersion: kubelet.config.k8s.io/v1beta1
	kind: KubeletConfiguration
	cgroupDriver: systemd
	EOF
    
    # 修改参数（主节点IP、主机名，开启ipvs,镜像加速器）
    sed -i "s#1.2.3.4#$IP_MASTER#" kubeadm.yaml
    sed -i 's#containerd/containerd.sock#cri-dockerd.sock#' kubeadm.yaml
    sed -i "s#name: node#name: $(hostname)#" kubeadm.yaml
    sed -i 's#registry.k8s.io#registry.cn-hangzhou.aliyuncs.com/google_containers#' kubeadm.yaml
    if ! grep podSubnet kubeadm.yaml;then
    	sed -i "/serviceSubnet/i\  podSubnet: 10.244.0.0/16" kubeadm.yaml
    fi
    
    # 初始化方式二
    function Init_k8s(){
    echo -e "\n kubeadm 初始化\n"
    kubeadm init \
    	--apiserver-advertise-address=$IP_MASTER \
	--kubernetes-version=v1.32.0 \
	--cri-socket=unix:///run/cri-dockerd.sock \
	--pod-network-cidr=10.224.0.0/16 \
	--service-cidr=10.96.0.0/12 \
	--image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers
    }
    
    systemctl restart kubelet
    # 初始化
    # Init_k8s |tee init_k8s.txt &
    kubeadm init --config=kubeadm.yaml | tee init_k8s.txt & 
    echo ""
    wait
    
    cat init_k8s.txt |grep "successfully"
    if [[ $? -eq 0 ]];then
	mkdir -p $HOME/.kube
	sudo \cp -rf /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config
	export KUBECONFIG=/etc/kubernetes/admin.conf
	echo -e "\n\t$CLOR_A========= 恭喜，k8s 初始化成功，请继续后续步骤！=========$CLOR_B\n"
        echo -e "\t如需加入集群，请在node节点执行如下命令：\n"
	echo -e "$CLOR_A$(sed -n 'N;$!D;$s#$#--cri-socket=unix:///run/cri-dockerd.sock#p' init_k8s.txt)$CLOR_B\n"
    else
	echo -e "\n\t========= k8s 初始化失败！=========\n"
    fi
fi
;;

2)
    echo -e "\n安装 Calico-3.29.1 网络插件\n"
    # 下载清单
    if [[ -e calico.yaml ]];then
	echo -e "\n\tCalico-3.29.1 yaml配置文件已经存在，开始修改配置，注意版本号~\n"
    else	
	# 需要代理才能下载
	curl https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml -O
    fi	

    # 通过使用这个参数，可以将特定的接口排除在 NetworkManager 的管理范围之外，以便其他工具或进程可以独立地管理和配置这些接口。
    # 表示以 "cali"和 "tunl" 开头的接口名称被排除在 NetworkManager 管理之外,例如，"cali0", "cali1","tunl0", "tunl1" 等接口不受 NetworkManager 管理。
    # 方式一
	cat > /etc/NetworkManager/conf.d/calico.conf <<-EOF
	[keyfile]
	unmanaged-devices=interface-name:cali*;interface-name:tunl*
	EOF
    
    # 方式二
    # systemctl disable --now NetworkManager
    # systemctl start network && systemctl enable network    
    
    systemctl restart NetworkManager

    # 修改calico配置参数
	sed -i '6246s/name: IP/name: IP_AUTODETECTION_METHOD/g' calico.yaml
	sed -i "6247s/autodetect/interface=$NET_CARD/g" calico.yaml
	
	kubectl apply -f calico.yaml
	echo -e "\n请过1~2分钟再检查 pod 节点网络运行状态\n\n\t运行命令为：${CLOR_A}kubectl get pods -A$CLOR_B\n"
	kubectl get pods -A
	echo ""
;;

3)
    ps -ef| egrep  kuber |grep -v grep | awk '{ print $2 }' |xargs -r kill -9
    # 初始化失败后可以重置
    sudo kubeadm reset --cri-socket=unix:///var/run/cri-dockerd.sock
    rm -rf /etc/kubernetes/*
    echo ""
    ;;
4)
    echo ""
    kubeadm token create --print-join-command
    echo ""
    ;;
5)    
    exit
    ;;
esac

