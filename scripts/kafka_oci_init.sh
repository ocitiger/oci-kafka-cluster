#!/bin/bash
#ociintance的数量
INIT_COUNT=${count}
#当前第几个oci的instance
NODE_INDEX=$1
#第一台oci intance的机器名
INIT_DNS="${name}0.${name}.${name}.oraclevcn.com"
#当前节点的机器名
NODE_DNS=$(hostname -f)
#MASTER_PRIVATE_IP=$(host "$INIT_DNS" | awk '{ print $4 }')
#当前节点的内网IP
PRIVATE_IP=$(host "$NODE_DNS" | awk '{ print $4 }')
#所有机器的私网IP地址 空格分开
NODE_IPS="${private_ips}"

#kafka的一些初始化变量
KAFKA_PORT=9092
KAFKA_DIR=/opt/oci_kafka
KAFKA_CONFIG_FILE="$KAFKA_DIR/config/server.properties"
ZOOKEEPER_CONFIG_FILE="$KAFKA_DIR/config/zookeeper.properties"
ZOOKEEPER_DATA_DIR="$KAFKA_DIR/config/zookeeperdata"
ZOOKEEPER_PORT=2181
ZOOKEEPER_PEER_PORT=2888
ZOOKEEPER_LEADER_PORT=3888
CMAK_PORT=9000

#防火墙设置
firewall-offline-cmd  --zone=public --add-port=$KAFKA_PORT/tcp
firewall-offline-cmd  --zone=public --add-port=$ZOOKEEPER_PORT/tcp
firewall-offline-cmd  --zone=public --add-port=$ZOOKEEPER_PEER_PORT/tcp
firewall-offline-cmd  --zone=public --add-port=$ZOOKEEPER_LEADER_PORT/tcp
firewall-offline-cmd  --zone=public --add-port=$CMAK_PORT/tcp
systemctl restart firewalld

#安装JDK 
sudo yum update -y ;sudo yum install java-11-openjdk.x86_64 -y;
#sudo yum install java-11-openjdk.x86_64 -y;
#从官网下载kafaka
rm $KAFKA_DIR -f ;mkdir $KAFKA_DIR;wget http://apache.mirror.cdnetworks.com/kafka/2.6.0/kafka_2.13-2.6.0.tgz -O $KAFKA_DIR/kafka.tgz;cd $KAFKA_DIR; tar -xvzf $KAFKA_DIR/kafka.tgz --strip 1;rm kafka.tgz -f;
#配置相关文件
cp $KAFKA_CONFIG_FILE $KAFKA_CONFIG_FILE.orig



#计算出zookeeper.connect
ZOOKEEPERCONNSTR=""
#keystrIndex=0
#for keystr  in $NODE_IPS 
#do
#        echo "server.$keystrIndex=$keystr:2888:3888" >> $ZOOKEEPER_CONFIG_FILE
#        if [ "$ZOOKEEPERCONNSTR" == "" ] ; then
#        	ZOOKEEPERCONNSTR="$keystr:$ZOOKEEPER_PORT"
#        else
#        	ZOOKEEPERCONNSTR="$ZOOKEEPERCONNSTR,$keystr:$ZOOKEEPER_PORT"
#        fi
#        keystrIndex = keystrIndex +1
#done

init_count_index=0 #${name}0.${name}.${name}.oraclevcn.com
for (( init_count_index=0 ; init_count_index < $INIT_COUNT ; init_count_index++ ))
do
 	keystr="${name}$init_count_index.${name}.${name}.oraclevcn.com"
	echo "server.$init_count_index=$keystr:$ZOOKEEPER_PEER_PORT:$ZOOKEEPER_LEADER_PORT" >> $ZOOKEEPER_CONFIG_FILE
        if [ "$ZOOKEEPERCONNSTR" == "" ] ; then
               ZOOKEEPERCONNSTR="$keystr:$ZOOKEEPER_PORT"
        else
               ZOOKEEPERCONNSTR="$ZOOKEEPERCONNSTR,$keystr:$ZOOKEEPER_PORT"
        fi
done


sed -i "s/^broker.id=0/broker.id=$NODE_INDEX/g" $KAFKA_CONFIG_FILE
sed -i "s/^#listeners=PLAINTEXT:\/\/:9092/listeners=PLAINTEXT:\/\/$NODE_DNS:$KAFKA_PORT/g" $KAFKA_CONFIG_FILE
sed -i "s/^#advertised.listeners=PLAINTEXT:\/\/your.host.name:9092/advertised.listeners=PLAINTEXT:\/\/$NODE_DNS:$KAFKA_PORT/g" $KAFKA_CONFIG_FILE
sed -i "s/^zookeeper.connect=localhost:2181/zookeeper.connect=$ZOOKEEPERCONNSTR/g" $KAFKA_CONFIG_FILE
#sed -i "s/^dataDir=\/tmp\/zookeeper/dataDir=$ZOOKEEPER_DATA_DIR/g" $ZOOKEEPER_CONFIG_FILE
sed -i "s/^dataDir=\/tmp\/zookeeper/dataDir=\/opt\/oci_kafka\/config\/zookeeperdata/g" $ZOOKEEPER_CONFIG_FILE

mkdir -p $ZOOKEEPER_DATA_DIR
echo "$NODE_INDEX" > $ZOOKEEPER_DATA_DIR/myid

cat >> $ZOOKEEPER_CONFIG_FILE << EOF
tickTime=2000
initLimit=10
syncLimit=5
EOF

#设置system service
cat > /etc/systemd/system/zookeeper.service << EOF
[Unit]
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
#User=opc
ExecStart=/opt/oci_kafka/bin/zookeeper-server-start.sh /opt/oci_kafka/config/zookeeper.properties
ExecStop=/opt/oci_kafka/bin/zookeeper-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

EOF

cat > /etc/systemd/system/kafka.service << EOF
[Unit]
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple
#User=opc
ExecStart=/opt/oci_kafka/bin/kafka-server-start.sh /opt/oci_kafka/config/server.properties
ExecStop=/opt/oci_kafka/bin/kafka-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target

EOF

