#! /bin/bash

# Does not work. Always freezes on calling: londiste conf/londiste_db4.ini compare --force
# The problem is in method Syncer.lock_table_branch - force_tick in paused provider doesn't correctly propagate to the consumer,
# so it's stuck in infinite loop waiting for the tick

source ../testlib.sh

../zstop.sh

source ./init.sh

v='-q'
v=''
nocheck=1

db_list="db1 db2 db3 db4 db5"

kdb_list=`echo $db_list | sed 's/ /,/g'`

#( cd ../..; make -s install )

do_check() {
  test $nocheck = 1 || ../zcheck.sh
}

title Compare test

# create ticker conf
cat > conf/pgqd.ini <<EOF
[pgqd]
database_list = $kdb_list
logfile = log/pgqd.log
pidfile = pid/pgqd.pid
EOF

# londiste configs
for db in $db_list; do
cat > conf/londiste_$db.ini <<EOF
[londiste]
db = dbname=$db
queue_name = replika
logfile = $LOG_DIR/%(job_name)s.log
pidfile = pid/%(job_name)s.pid
batch_save_dir = $BATCH_SAVE_DIR

pgq_autocommit = 1
pgq_lazy_fetch = 0
EOF
done

for db in $db_list; do
  cleardb $db
done

clearlogs

set -e

msg "Basic config"
run cat conf/pgqd.ini
run cat conf/londiste_db1.ini

msg "Install londiste and initialize nodes"
run londiste $v conf/londiste_db1.ini create-root node1 'dbname=db1'
run londiste $v conf/londiste_db2.ini create-branch node2 'dbname=db2' --provider='dbname=db1'
run londiste $v conf/londiste_db3.ini create-branch node3 'dbname=db3' --provider='dbname=db2'
run londiste $v conf/londiste_db4.ini create-branch node4 'dbname=db4' --provider='dbname=db3'
run londiste $v conf/londiste_db5.ini create-branch node5 'dbname=db5' --provider='dbname=db4'

msg "Run ticker"
run pgqd $v -d conf/pgqd.ini
run sleep 5

msg "See topology"
run londiste $v conf/londiste_db1.ini status

msg "Run londiste daemon for each node"
for db in $db_list; do
  run psql -d $db -c "update pgq.queue set queue_ticker_idle_period='2 secs'"
  run londiste $v -d conf/londiste_$db.ini worker
done

msg "Create table on root node and fill couple of rows"
run psql -d db1 -c "create table mytable (id serial primary key, data text)"
for n in 1 2 3 4; do
  run psql -d db1 -c "insert into mytable (data) values ('row$n')"
done

run psql -d db1 -c "create table mytable_rows (id serial primary key, main_id int4 references mytable, extra text)"
for n in 1 2 3 4; do
  run psql -d db1 -c "insert into mytable_rows (main_id, extra) values (1, 'row$n')"
done

msg "Register table on root node"
run londiste $v conf/londiste_db1.ini add-table mytable
run londiste $v conf/londiste_db1.ini add-seq mytable_id_seq
run londiste $v conf/londiste_db1.ini add-table mytable_rows
run londiste $v conf/londiste_db1.ini add-seq mytable_rows_id_seq

msg "Register table on other node with creation"
for db in db2 db3 db4 db5; do
  run psql -d $db -c "create table mytable (id serial primary key, data text)"
  run psql -d $db -c "create table mytable_rows (id serial primary key, main_id int4 references mytable, extra text)"
  run londiste $v conf/londiste_$db.ini add-seq mytable_id_seq
  run londiste $v conf/londiste_$db.ini add-seq mytable_rows_id_seq
  #run londiste $v conf/londiste_$db.ini add-table mytable
  #run londiste $v conf/londiste_$db.ini add-table mytable_rows
done

for db in db5 db2 db4 db3; do
  msg "Add tables to $db and wait for sync"
  run londiste $v conf/londiste_$db.ini add-table --all --find-copy-node
  run londiste conf/londiste_$db.ini wait-sync

  msg "Run compare and repair"
  run londiste conf/londiste_$db.ini compare --force
  run londiste conf/londiste_$db.ini repair --force
done

