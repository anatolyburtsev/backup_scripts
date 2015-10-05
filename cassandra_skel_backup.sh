
#commands from history

#backup
cassandra_host=""; 
for i in `echo -e "DESCRIBE KEYSPACES;\n" | cqlsh $cassandra_host`; do 
    echo $i; 
    echo -e "use $i;\nDESCRIBE KEYSPACE;\n" | cqlsh $cassandra_host > ${i}.dump; 
done

#restore

cassandra_host=""; 
for i in *.dump; do 
    cqlsh $cassandra_host -f $i; 
done
