#! /bin/bash
#
# $Id:$
# $Rev:$
#

ZYNGA_LOG_HOME=/zynga/logs

# usage: compress_zlog [last-modified-cutoff-interval]
function compress_zlogs
{
  #default to compress 3+ days old
  ZLOG_CUTOFF_INTEVAL=3  

  if [ -n "$1" ]; then
    ZLOG_CUTOFF_INTEVAL=$1
  fi

  # avoid log rotation that is not rotated by date since it will create conflict
  logger -s "executing - find $ZYNGA_LOG_HOME -mtime +$ZLOG_CUTOFF_INTEVAL -name '*log*' | egrep -v gz$ | egrep '20[0-9][0-9]'"
  ZLOGS=`find $ZYNGA_LOG_HOME -mtime +$ZLOG_CUTOFF_INTEVAL -name '*log*' | egrep -v gz$ | egrep '20[0-9][0-9]'`
  for ZLOG in $ZLOGS
  do
    logger -s "gz-ing $ZLOG"
    nice gzip $ZLOG
  done
}


# usage: list_zlog_files [last-modified-cutoff-interval]
# look for compress log that are under 
function list_zlogs
{
  #default to list gzip'ed files that are 60+ days old
  ZLOG_CUTOFF_INTEVAL=30

  if [ -n "$1" ]; then
    ZLOG_CUTOFF_INTEVAL=$1
  fi

  # avoid log rotation that is not rotated by date since it will create conflict
  find $ZYNGA_LOG_HOME -mtime +$ZLOG_CUTOFF_INTEVAL -name '*log*.gz' | egrep '20[0-9][0-9]'
}

# usage: get_md5 [path-to-file]
# return: md5 hash
function get_md5
{
  if [ -z "$1" ]; then 
    logger -s "missing file path" >&2
    return 1;
  fi
 
  if [ ! -f $1 ]; then
    logger -s "file not exist: $1" >&2
    return 2;
  fi
  
  openssl md5 $1 |  awk ' { print $2 }'
}

function get_hostname
{
  hostname --short
}

# usage: rsync_zlogs [dst-hostname-prefix]
function rsync_zlogs
{
  if [ -z "$1" ]; then
    logger -s "missing destination prefix" >&2
    return 1;
  fi

  HOST_NAME=`hostname | cut -d'.' -f 1`
  DST_HOST_PREFIX=$1

  logger -s "rsync: $HOST_NAME:$ZYNGA_LOG_HOME -> $DST_HOST_PREFIX"
  
  logger -s "rsync -avz --times  --include '*/' --include '*20[0-9][0-9]*.gz'  --exclude '*'  $ZYNGA_LOG_HOME $DST_HOST_PREFIX/$HOST_NAME"
  rsync -avz --times  --include '*/' --include '*20[0-9][0-9]*.gz'  --exclude '*'  $ZYNGA_LOG_HOME $DST_HOST_PREFIX/$HOST_NAME
}

# usage: delete_zlog <path> <md5>
# return 0 if succeeded
# return 1 if missing arguements or other general erros
# return 2 if file does not exist
# return 3 if md5sum does not match
function delete_zlog
{
  if [ -z "$1" -o  -z "$2" ]; then 
    logger -s "missing parameters: $*" >&2
    return 1;
  fi
  
  ZLOG=$1
  ZLOG_MD5=$2

  if [ ! -f $ZLOG ]; then
    logger -s "file not exists:  $ZLOG" >&2
    return 2;
  fi


  MD5_LOCAL=`get_md5 $1`

  if [ "$ZLOG_MD5" = "$MD5_LOCAL" ]; then
    logger -s "deleting $ZLOG"
    rm $ZLOG
  else
    logger -s "md5sum not matches: $ZLOG: $ZLOG_MD5" >&2
    return 1;
  fi
}

case "$SSH_ORIGINAL_COMMAND" in 
  *\&*|*\(*|*\{*|*\;*|*\<*|*\`*|*\|*) 
    logger -s "Rejected: $SSH_ORIGINAL_COMMAND" 
  ;; 
  rsync\ --server* | \
  compress_zlogs*  | \
  list_zlogs*      | \
  get_md5*         | \
  get_hostname*    | \
  rsync_zlogs*     | \
  delete_zlog*)
    $SSH_ORIGINAL_COMMAND
  ;;
  *)
  logger -s "Rejected: $SSH_ORIGINAL_COMMAND" 
  ;; 
esac 