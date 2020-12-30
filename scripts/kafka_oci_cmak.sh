#!/bin/bash
#ociintance的数量
INIT_COUNT=${count}
#第一台oci intance的机器名
INIT_DNS="${name}0.${name}.${name}.oraclevcn.com"
#当前节点的机器名
NODE_DNS=$(hostname -f)
#MASTER_PRIVATE_IP=$(host "$INIT_DNS" | awk '{ print $4 }')
#当前节点的内网IP
PRIVATE_IP=$(host "$NODE_DNS" | awk '{ print $4 }')
#所有机器的私网IP地址 空格分开
NODE_IPS="${private_ips}"
KAFKA_MGMT_PASSWORD=${kafka_mgmt_password}


#kafka的一些初始化变量
KAFKA_PORT=9092
KAFKA_DIR=/opt/oci_kafka
CMAK_DIR=/opt/oci_cmak
KAFKA_CONFIG_FILE="$KAFKA_DIR/config/server.properties"
ZOOKEEPER_CONFIG_FILE="$KAFKA_DIR/config/zookeeper.properties"
ZOOKEEPER_PORT=2181
CMAK_PORT=9000

#计算出zookeeper.connect
ZOOKEEPERCONNSTR=""
for keystr  in $NODE_IPS 
do
        if [ "$ZOOKEEPERCONNSTR" == "" ] ; then
        	ZOOKEEPERCONNSTR="$keystr:$ZOOKEEPER_PORT"
        else
        	ZOOKEEPERCONNSTR="$ZOOKEEPERCONNSTR,$keystr:$ZOOKEEPER_PORT"
        fi
done



#
sudo yum update -y ;sudo yum install git unzip zip -y;

if [[ $INIT_DNS == $NODE_DNS ]]; then
cd ~
git clone https://github.com/yahoo/CMAK.git
cd ~/CMAK/
./sbt clean dist
cd ~/CMAK/target/universal
mkdir $CMAK_DIR
unzip -d $CMAK_DIR cmak-3.0.0.5.zip
#/opt/oci_cmak/cmak-3.0.0.5/bin
cd $CMAK_DIR/cmak-3.0.0.5/bin
cat > $CMAK_DIR/cmak-3.0.0.5/bin/oci_cmak.sh << EOF
#!/bin/bash
export KAFKA_MANAGER_AUTH_ENABLED=true;
export KAFKA_MANAGER_USERNAME="ocikafkaadmin" ;
export KAFKA_MANAGER_PASSWORD="$KAFKA_MGMT_PASSWORD" ;
export ZK_HOSTS="$ZOOKEEPERCONNSTR"  
$CMAK_DIR/cmak-3.0.0.5/bin/cmak 

EOF
chmod 755 $CMAK_DIR/cmak-3.0.0.5/bin/oci_cmak.sh

fi




#设置system service
cat > /etc/systemd/system/cmak.service << EOF
[Unit]
Requires=kafka.service
After=kafka.service

[Service]
Type=simple
#User=opc
ExecStart=/opt/oci_cmak/cmak-3.0.0.5/bin/oci_cmak.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

EOF


#sudo systemctl enable cmak
#sudo systemctl start cmak

