#! /bin/bash

for CLASS in `cat ~/tmp/spring-class.txt`
do
  echo comparing $CLASS
  grep $CLASS  ~/tmp/zynga-class.txt  > /dev/null
  
  if [ $? -ne 0 ]; then

    echo missing $CLASS
  fi
done