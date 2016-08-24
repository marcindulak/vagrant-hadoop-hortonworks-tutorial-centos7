# -*- mode: ruby -*-
# vi: set ft=ruby :

AMBARI_VER = '2.2.2.0'
AMBARI_USER = 'root'

hosts = {
  'master0' => {'hostname' => 'master0', 'ip' => '192.168.10.10', 'mac' => '080027001010'},
  'slave0' => {'hostname' => 'slave0', 'ip' => '192.168.10.20', 'mac' => '080027001020'},
  'slave1' => {'hostname' => 'slave1', 'ip' => '192.168.10.21', 'mac' => '080027001021'},
  'gateway0' => {'hostname' => 'gateway0', 'ip' => '192.168.10.100', 'mac' => '080027010100', 'http_port' => 8080},
}

Vagrant.configure(2) do |config|
  hosts.keys.sort.each do |host|
    if host.start_with?("master")
      config.vm.define hosts[host]['hostname'] do |master|
        master.vm.box = 'centos/7'
        master.vm.box_url = 'centos/7'
        master.vm.synced_folder '.', '/home/vagrant/sync', disabled: true
        master.vm.network 'private_network', ip: hosts[host]['ip'], mac: hosts[host]['mac'], auto_config: false
        master.vm.provider 'virtualbox' do |v|
          v.memory = 768
          v.cpus = 1
          # disable VBox time synchronization and use ntp
          v.customize ['setextradata', :id, 'VBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled', 1]
        end
      end
    end
  end
  hosts.keys.sort.each do |host|
    if host.start_with?("slave")
      config.vm.define hosts[host]['hostname'] do |slave|
        slave.vm.box = 'centos/7'
        slave.vm.box_url = 'centos/7'
        slave.vm.synced_folder '.', '/home/vagrant/sync', disabled: true
        slave.vm.network 'private_network', ip: hosts[host]['ip'], mac: hosts[host]['mac'], auto_config: false
        slave.vm.provider 'virtualbox' do |v|
          v.memory = 512
          v.cpus = 1
          # disable VBox time synchronization and use ntp
          v.customize ['setextradata', :id, 'VBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled', 1]
          # local block device for hdfs.datanode.data.dir
          disk = hosts[host]['hostname'] + "sdb.vdi"
          if !File.exist?(disk)
            v.customize ["createhd", "--filename", disk, "--size", 2048, "--variant", "Fixed"]
            v.customize ["modifyhd", disk, "--type", "writethrough"]
          end
          v.customize ["storageattach", :id, "--storagectl", "IDE Controller", "--port", 0, "--device", 1, "--type", "hdd", "--medium", disk]
        end
      end
    end
  end
  hosts.keys.sort.each do |host|
    if host.start_with?("gateway")
      config.vm.define hosts[host]['hostname'] do |gateway|
        gateway.vm.box = 'centos/7'
        gateway.vm.box_url = 'centos/7'
        gateway.vm.synced_folder '.', '/home/vagrant/sync', disabled: true
        gateway.vm.network 'private_network', ip: hosts[host]['ip'], mac: hosts[host]['mac'], auto_config: false
        gateway.vm.network 'forwarded_port', guest: 8080, host: hosts[host]['http_port']
        gateway.vm.provider 'virtualbox' do |v|
          v.memory = 768
          v.cpus = 1
          # disable VBox time synchronization and use ntp
          v.customize ['setextradata', :id, 'VBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled', 1]
        end
      end
    end
  end
  # disable IPv6 on Linux
  $linux_disable_ipv6 = <<SCRIPT
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
SCRIPT
  # setenforce 0
  $setenforce_0 = <<SCRIPT
if test `getenforce` = 'Enforcing'; then setenforce 0; fi
#sed -Ei 's/^SELINUX=.*/SELINUX=Permissive/' /etc/selinux/config
SCRIPT
  # stop firewalld
  $systemctl_stop_firewalld = <<SCRIPT
systemctl stop firewalld.service
SCRIPT
  # common settings on all machines
  $etc_hosts = <<SCRIPT
echo "$*" >> /etc/hosts
SCRIPT
  $ambari_el7 = <<SCRIPT
yum -y install wget
wget --retry-connrefused --waitretry=5 http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/$1/ambari.repo -O /etc/yum.repos.d/ambari.repo
SCRIPT
  $ambari_agent = <<SCRIPT
yum -y install ambari-agent
sed -i "s/hostname=.*/hostname=$1/" /etc/ambari-agent/conf/ambari-agent.ini
systemctl enable ambari-agent.service
systemctl start ambari-agent.service
SCRIPT
  # key-based ssh using vagrant keys
  $key_based_ssh = <<SCRIPT
home=`getent passwd $1 | cut -d: -f6`
rm -rf ${home}/.ssh
ls -al ~vagrant ${home}
cp -rp ~vagrant/.ssh ${home}
yum -y install wget
wget --retry-connrefused --waitretry=5 --no-check-certificate https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O ${home}/.ssh/authorized_keys
SCRIPT
  # .ssh config
  $dotssh_config = <<SCRIPT
home=`getent passwd $1 | cut -d: -f6`
user=$1
sudo su - -c "cat << EOF > ${home}/.ssh/config
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    User $user
EOF"
sudo su - -c "chmod 600 ${home}/.ssh/config"
SCRIPT
  # .ssh permission
  $dotssh_chmod_600 = <<SCRIPT
home=`getent passwd $1 | cut -d: -f6`
sudo su - -c "chmod -R 600 ${home}/.ssh"
sudo su - -c "chmod 700 ${home}/.ssh"
SCRIPT
  # .ssh ownership
  $dotssh_chown = <<SCRIPT
home=`getent passwd $1 | cut -d: -f6`
sudo su - -c "chown -R $1:$2 ${home}/.ssh"
SCRIPT
  # configure the second vagrant eth interface
  $ifcfg = <<SCRIPT
IPADDR=$1
NETMASK=$2
DEVICE=$3
TYPE=$4
cat <<END >> /etc/sysconfig/network-scripts/ifcfg-$DEVICE
NM_CONTROLLED=no
BOOTPROTO=none
ONBOOT=yes
IPADDR=$IPADDR
NETMASK=$NETMASK
DEVICE=$DEVICE
PEERDNS=no
TYPE=$TYPE
END
ARPCHECK=no /sbin/ifup $DEVICE 2> /dev/null
SCRIPT
  hosts.keys.sort.each do |host|
    config.vm.define hosts[host]['hostname'] do |server|
      server.vm.provision :shell, :inline => 'hostname ' + hosts[host]['hostname'], run: 'always'
      server.vm.provision :shell, :inline => 'echo ' + hosts[host]['hostname'] + ' > /etc/hostname'
      hosts.keys.sort.each do |k|
        server.vm.provision 'shell' do |s|
          s.inline = $etc_hosts
          s.args   = [hosts[k]['ip'], hosts[k]['hostname']]
        end
      end
      server.vm.provision :shell, :inline => $setenforce_0, run: 'always'
      server.vm.provision 'shell' do |s|
        s.inline = $ambari_el7
        s.args   = [AMBARI_VER]
      end
      # configure key-based ssh for ceph user using vagrant's keys
      server.vm.provision :file, source: '~/.vagrant.d/insecure_private_key', destination: '~vagrant/.ssh/id_rsa'
      server.vm.provision 'shell' do |s|
        s.inline = $key_based_ssh
        s.args   = [AMBARI_USER]
      end
      server.vm.provision 'shell' do |s|
        s.inline = $dotssh_chmod_600
        s.args   = [AMBARI_USER]
      end
      server.vm.provision 'shell' do |s|
        s.inline = $dotssh_config
        s.args   = [AMBARI_USER]
      end
      server.vm.provision 'shell' do |s|
        s.inline = $dotssh_chown
        s.args   = [AMBARI_USER, AMBARI_USER]
      end
      server.vm.provision 'shell' do |s|
        s.inline = $ifcfg
        s.args   = [hosts[host]['ip'], '255.255.255.0', 'eth1', 'Ethernet']
      end
      server.vm.provision :shell, :inline => 'ifup eth1', run: 'always'
      # restarting network fixes RTNETLINK answers: File exists
      server.vm.provision :shell, :inline => 'systemctl restart network'
      server.vm.provision :shell, :inline => $linux_disable_ipv6, run: 'always'
      server.vm.provision :shell, :inline => 'yum -y install java-1.8.0-openjdk'
      # install and start ambari-agent; gateway0 is the Ambari server
      server.vm.provision 'shell' do |s|
        s.inline = $ambari_agent
        s.args   = ['gateway0']
      end
      # install and enable ntp
      server.vm.provision :shell, :inline => 'yum -y install ntp'
      server.vm.provision :shell, :inline => 'systemctl enable ntpd'
      server.vm.provision :shell, :inline => 'systemctl start ntpd'
    end
  end
end
