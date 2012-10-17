#! /bin/bash
#
# $Id:$
# $Rev:$
#

# -------- configuration --------
# SSH Key to use
LOG_MIGRATION_KEY=payment-log-migration-key

# consider moving to a file if this gets too long
#LOG_HOSTS="payment@pmt-stg-svc1 payment@pmt-stg-web1"
#LOG_HOSTS="payment@pmt-stg-svc1"
LOG_HOSTS="deploy@sw17011 deploy@sw17012 deploy@sw17013 deploy@sw17014 deploy@sw17015 deploy@sw19015 deploy@sw19021 deploy@sw19022 deploy@sw19023"
#LOG_HOSTS="deploy@sw17011"

#ZLOG_STORAGE_HOST=deploy@sw1902.sv4.zynga.com
#ZLOG_STORAGE_PATH_PREFIX=~/ochan
ZLOG_STORAGE_HOST=payment@c7-pmt-dd01.corp.zynga.com
ZLOG_STORAGE_PATH_PREFIX=/payments

ZYNGA_SECURE_LOG_STORAGE=$ZLOG_STORAGE_HOST:$ZLOG_STORAGE_PATH_PREFIX

SSH_CMD="ssh"

# -------- codes --------

if [ -n "$LOG_MIGRATION_KEY" ]; then
  if [ -f ~/.ssh/$LOG_MIGRATION_KEY ]; then
    LOG_MIGRATION_KEY=~/.ssh/$LOG_MIGRATION_KEY
  fi

  SSH_CMD="$SSH_CMD -i $LOG_MIGRATION_KEY"
fi

logger -s ssh command: $SSH_CMD

# usage: ssh_cmd <user@host>
function ssh_cmd
{
  if [ -z "$1" ]; then
    logger -s -- missing hostname
    return 1;
  fi
  
  logger -s -- ">" executing $SSH_CMD $*
  OUTPUT=`$SSH_CMD $* 2>&1`
  
  STATUS=$?

  if [ $STATUS -ne 0 ]; then
    logger -s -- $OUTPUT | mail -s "unable to ssh $*: $STATUS: $LOG_HOST -> $ZYNGA_SECURE_LOG_STORAGE" ochan@zynga.com
    logger -s -- "unable to execute: error: $*: $STATUS: $OUTPUT" >&2
    return 1; 
  else
    logger -s -- "<" $OUTPUT
  fi

}

for LOG_HOST in  $LOG_HOSTS
do
  # compress log files
  logger -s -- = $LOG_HOST: compressing log files
  ssh_cmd $LOG_HOST compress_zlogs

  # rysnc log files
  logger -s -- = $LOG_HOST: rsync-ing log files 
  ssh_cmd $LOG_HOST rsync_zlogs  $ZYNGA_SECURE_LOG_STORAGE

  # get host name
  logger -s -- = $LOG_HOST: $SSH_CMD $LOG_HOST get_hostname
  LOG_HOST_ALIAS=`$SSH_CMD $LOG_HOST get_hostname`

  logger -s -- = $LOG_HOST: $SSH_CMD $LOG_HOST list_zlogs
  LOG_FILES=`$SSH_CMD $LOG_HOST list_zlogs`
#  echo = $LOG_HOST: $LOG_FILES
  if [ -n "$LOG_FILES" ]; then
    for LOG_FILE in $LOG_FILES
    do
      # convert /zyngz/logs --> /payment/sw17011/logs
      DST_PATH=`echo $LOG_FILE | sed "s|/zynga/logs|$ZLOG_STORAGE_PATH_PREFIX/$LOG_HOST_ALIAS/logs|g"`
      logger -s -- = $LOG_HOST: comparing: src=$LOG_FILE: dst=$DST_PATH

      logger -s -- $SSH_CMD $ZLOG_STORAGE_HOST get_md5 $DST_PATH
      DST_MD5=`$SSH_CMD $ZLOG_STORAGE_HOST get_md5 $DST_PATH`

      if [ $? -eq 0 -a -n "$DST_MD5" ]; then
        ssh_cmd $LOG_HOST delete_zlog $LOG_FILE $DST_MD5
      else
        logger -s -- = $LOG_HOST skipping $LOG_FILE : $? : $DST_MD5 
      fi

    done
  fi
done

