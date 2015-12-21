wget https://raw.githubusercontent.com/apache/hadoop/trunk/hadoop-mapreduce-project/hadoop-mapreduce-examples/src/main/java/org/apache/hadoop/examples/WordCount.java
sed -i '/package/d' WordCount.java
export HADOOP_CLASSPATH=$(dirname $(dirname $(dirname $(readlink -f /usr/bin/java))))/lib/tools.jar
rm -rf build WordCount.jar
mkdir build
hadoop com.sun.tools.javac.Main WordCount.java -d build
jar -cvf WordCount.jar -C build .
hadoop jar WordCount.jar WordCount /user/vagrant/WordCount/input /user/vagrant/WordCount/mapreduce-output
