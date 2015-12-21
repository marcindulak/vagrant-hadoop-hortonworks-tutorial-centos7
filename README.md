-----------
Description
-----------

A CentOS 7 Hortonworks Hadoop / java-1.8.0-openjdk cluster consisting of a master, two slave nodes and a gateway.
The basic setup (HDFS, MapReduce, Tez, Pig, Ambari Metrics, Zookeeper) without
high availability is fully automated thanks to Ambari's Blueprints.
A basic usage of the cluster is demonstrated by running a word count MapReduce and Pig example.

Tested on Ubuntu 14.04 host.

**Note**: you need at least 4GB RAM and 30 GB disk space on your host.

![ambari-vagrant.png](https://raw.github.com/marcindulak/vagrant-hadoop-hortonworks-tutorial-centos7/master/screenshots/ambari-vagrant.png)

----------------------
Configuration overview
----------------------

The private 192.168.10.0/24 network is associated with the Vagrant eth1 interfaces.
eth0 is used by Vagrant.  Vagrant reserves eth0 and this cannot be currently changed
(see https://github.com/mitchellh/vagrant/issues/2093).


                                                    ---------------------
                                                    | gateway0          |
                                                    |                   |
                                                    | AMBARI_SERVER     |
                                                    | HDFS_CLIENT       |
                                                    | MAPREDUCE2_CLIENT |
                                                    | METRICS_COLLECTOR |
                                                    | METRICS_MONITOR   |
                                                    | NFS_GATEWAY       |
                                                    | PIG               |
                                                    | TEZ_CLIENT        |
                                                    | YARN_CLIENT       |
                                                    ---------------------
                                                     |     |
                                                 eth1| eth0|
                                       192.168.10.100|     |
                 ----------------------------------------------------------------------------------
                 |                                  Vagrant HOST                                  |
                 ----------------------------------------------------------------------------------
                  |     |                                         |     |                  |     |
              eth1| eth0|                                     eth1| eth0|              eth1| eth0|
     192.168.10.10|     |                            192.168.10.20|     |     192.168.10.2N|     |
                 -----------------------                         -------------------      -----------
                 | master0             |                         | slave0          |      | slaveN  |
                 |                     |                         |                 | ...  |         |
                 | APP_TIMELINE_SERVER |                         | DATANODE        |      | same as |
                 | HISTORYSERVER       |                         | METRICS_MONITOR |      | slave0  |
                 | METRICS_MONITOR     |                         | NODEMANAGER     |      -----------
                 | NAMENODE            |                         -------------------              |
                 | RESOURCEMANAGER     |                             |                        ------------
                 | SECONDARY_NAMENODE  |                         ---------------------------  | /dev/sdb |
                 | ZOOKEEPER_CLIENT    |                         | /dev/sdb block device   |  ------------
                 | ZOOKEEPER_SERVER    |                         | with ext4 used for HDFS |
                 -----------------------                         | hdfs.datanode.data.dir  |
                                                                 ---------------------------
------------
Sample Usage
------------

Install VirtualBox https://www.virtualbox.org/ and Vagrant
https://www.vagrantup.com/downloads.html

Start the virtual machines with::

        $ git clone https://github.com/marcindulak/vagrant-hadoop-hortonworks-tutorial-centos7.git
        $ cd vagrant-hadoop-hortonworks-tutorial-centos7
        $ vagrant up

The setup follows loosely the instructions from
http://docs.hortonworks.com/HDPDocuments/Ambari-2.1.2.1/bk_Installing_HDP_AMB/content/index.html
The machines have SSH key-based authentication configured for the *root* user,
java-1.8.0-openjdk is installed, ambari yum repo is configured, ambari-agent is installed, configured and started,
and the ntp service started. The actual Hadoop installation and configuration is performed below.

- prepare the `/hdfs-vagrant/data` mount points for `hdfs.datanode.data.dir` on the **slaves**::

            $ vagrant ssh slave0 -c "sudo su - -c 'mkfs.ext4 -F /dev/sdb'"
            $ vagrant ssh slave0 -c "sudo su - -c 'echo /dev/sdb /hdfs-vagrant/data ext4 defaults,noatime >> /etc/fstab'"
            $ vagrant ssh slave0 -c "sudo su - -c 'mkdir -p /hdfs-vagrant/data'"
            $ vagrant ssh slave0 -c "sudo su - -c 'mount /hdfs-vagrant/data'"

            $ vagrant ssh slave1 -c "sudo su - -c 'mkfs.ext4 -F /dev/sdb'"
            $ vagrant ssh slave1 -c "sudo su - -c 'echo /dev/sdb /hdfs-vagrant/data ext4 defaults,noatime >> /etc/fstab'"
            $ vagrant ssh slave1 -c "sudo su - -c 'mkdir -p /hdfs-vagrant/data'"
            $ vagrant ssh slave1 -c "sudo su - -c 'mount /hdfs-vagrant/data'"

  These /dev/sdb volumes are 2 GBytes large. This is way below HDFS defaults and therefore the settings
  need to be changed (see [vagrant-cluster.json](vagrant-cluster.json)): `dfs.datanode.du.reserved` used to set
  aside the memory required for non DFS activities is set to 1 GByte (the default is 10 GBytes); and
  `dfs.blocksize` the default block size for files stored in HDFS is set to 1 MByte (the default is 128 MBytes).
  On production systems make sure you have enough space in `hdfs.datanode.data.dir` because HDFS will fill
  this space in anyway if it has to, independently of the `dfs.datanode.du.reserved` setting. 

- create users and groups which own `hdfs.datanode.data.dir`. They are normally created by
  Ambari, but they are needed now in order to change the ownership of `/hdfs-vagrant/data` before
  Ambari starts the installation. Ambari itself won't change the ownership of these directories::

            $ vagrant ssh master0 -c "sudo su - -c 'groupadd hadoop&& useradd -g hadoop hdfs'"
            $ vagrant ssh slave0 -c "sudo su - -c 'groupadd hadoop&& useradd -g hadoop hdfs'"
            $ vagrant ssh slave1 -c "sudo su - -c 'groupadd hadoop&& useradd -g hadoop hdfs'"
            $ vagrant ssh gateway0 -c "sudo su - -c 'groupadd hadoop&& useradd -g hadoop hdfs'"

- fix the `hdfs.datanode.data.dir` ownership discussed above::

            $ vagrant ssh slave0 -c "sudo su - -c 'chown -R hdfs:hadoop /hdfs-vagrant/data'"
            $ vagrant ssh slave1 -c "sudo su - -c 'chown -R hdfs:hadoop /hdfs-vagrant/data'"

- setup Apache Ambari server on the **gateway0**.
  For the purpose of this tutorial decrease ambari-server's JVM memory allocation pools:

            $ vagrant ssh gateway0 -c "sudo su - -c 'yum -y install ambari-server'"
            $ vagrant ssh gateway0 -c "sudo su - -c \"sed -i 's|-Xms[0-9]*m |-Xms128m |' /var/lib/ambari-server/ambari-env.sh\""
            $ vagrant ssh gateway0 -c "sudo su - -c \"sed -i 's|-Xmx[0-9]*m |-Xmx128m |' /var/lib/ambari-server/ambari-env.sh\""
            $ vagrant ssh gateway0 -c "sudo su - -c 'ambari-server setup -sv -j \$(dirname \$(dirname \$(readlink -f /usr/bin/java)))'"
            $ vagrant ssh gateway0 -c "sudo su - -c 'systemctl enable ambari-server.service'"
            $ vagrant ssh gateway0 -c "sudo su - -c 'systemctl start ambari-server.service'"
            $ sleep 120  # wait for ambari-server to start

Now you can configure the cluster based on Ambari Blueprint. You could also launch instead the Ambari Wizard
installation by accessing `localhost:8080` in a host browser with `admin`/`admin` credentials::

- list the hosts known by ambari-server::

            $ curl -H "X-Requested-By: ambari" -X GET -u admin:admin http://localhost:8080/api/v1/hosts

- register Blueprint with Ambari::

            $ curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://localhost:8080/api/v1/blueprints/vagrant -d @vagrant-blueprint.json

- verify the Blueprint has been registered::

            $ curl -H "X-Requested-By: ambari" -X GET -u admin:admin http://localhost:8080/api/v1/blueprints

- create the cluster instance::

            $ curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://localhost:8080/api/v1/clusters/vagrant -d @vagrant-cluster.json
            $ sleep 3000  # wait for the installation to finish

- check if there are any failures (with the state: not *OK*)::

            $ curl -H "X-Requested-By: ambari" -X GET -u admin:admin http://localhost:8080/api/v1/clusters/c1/alerts?Alert/state!=OK

- verify the available HDFS space::

            $ vagrant ssh gateway0 -c "sudo su - hdfs -c 'hdfs dfsadmin -report'"

- create the *mapreduce.jobtracker.staging.root.dir* HDFS directory for the **vagrant** user::

            $ vagrant ssh gateway0 -c "sudo su - hdfs -c 'hadoop fs -mkdir -p /user/vagrant'"
            $ vagrant ssh gateway0 -c "sudo su - hdfs -c 'hadoop fs -chown vagrant:vagrant /user/vagrant'"

- install `tools.jar`::

            $ vagrant ssh gateway0 -c "sudo su - -c 'yum -y install java-1.8.0-openjdk-devel'"

Normally one would run Hadoop smoke tests http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.3.0/bk_upgrading_hdp_manually/content/run-hadoop-tests-21.html , but this will fail in this setup due to overloading of the
slaves with yarn processes. One would run the smoke tests like this (don't do this!):

            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'hadoop jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-mapreduce-examples.jar randomwriter -Dtest.randomwrite.total_bytes=10000000 test-after-upgrade'"

Instead run a small MapReduce word count example https://hadoop.apache.org/docs/current/hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html , counting the words in the LICENSE file belonging to this project::

            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'wget https://raw.githubusercontent.com/marcindulak/vagrant-hadoop-hortonworks-tutorial-centos7/master/LICENSE'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'hadoop fs -mkdir -p /user/vagrant/WordCount/input'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'hadoop fs -put LICENSE /user/vagrant/WordCount/input'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'hadoop fs -cat /user/vagrant/WordCount/input/*'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'wget https://raw.githubusercontent.com/marcindulak/vagrant-hadoop-hortonworks-tutorial-centos7/master/WordCount.sh'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'sh WordCount.sh'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'hadoop fs -cat /user/vagrant/WordCount/mapreduce-output/*'"

- run Pig word count example (the code taken from https://github.com/hortonworks/hadoop-tutorials/blob/master/Community/T03_Word_Counting_With_Pig.md)::

            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'wget https://raw.githubusercontent.com/marcindulak/vagrant-hadoop-hortonworks-tutorial-centos7/master/wc.pig'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'pig wc.pig'"
            $ vagrant ssh gateway0 -c "sudo su - vagrant -c 'hadoop fs -cat /user/vagrant/WordCount/pig-mapreduce-output/*'"

When done, destroy the test machines with::

        $ vagrant destroy -f


------------
Dependencies
------------

None


-------
License
-------

BSD 2-clause


----
Todo
----
