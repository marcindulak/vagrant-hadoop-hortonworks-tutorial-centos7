a = load '/user/vagrant/WordCount/input/LICENSE';
b = foreach a generate flatten(TOKENIZE((chararray)$0)) as word;
c = group b by word;
d = foreach c generate COUNT(b), group;
store d into '/user/vagrant/WordCount/pig-mapreduce-output';
