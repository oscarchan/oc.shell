#! /bin/bash
#
# rename the file based on date in the end of the log

for PREFIX in `echo production fb zbillr`
do
  for FILE in `ls $PREFIX.log.[0-9][0-9].gz`
  do
    DATE=`gunzip  -c $FILE | tail -n 80 | grep 2010\- | perl  -ne '/(2010-\d\d-\d\d)/ && print $1."\n"' | tail -n 1 `
    echo "mv $FILE  $PREFIX.$DATE.log.gz"
  done
done


