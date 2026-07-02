#!/bin/bash

#   echo "Usage: ./mock_data.sh <database> <table> <records>"
#   echo "Example: bash mock_data.sh test bigsumplus 10000"
#   echo "Example: bash mock_data.sh test bigsumplus 10000 root root"


# Assign database and table name to variables
database=$1
table=$2

# username and password for mariadb if $3 and $4 exist
if [ ! -z $4 ] && [ ! -z $5 ]; then
    username=$4
    password=$5
fi

# Query to show columns of the table
if [ ! -z $username ] && [ ! -z $password ]; then
    result=$(mariadb -u $username -p$password -D $database -e "SHOW COLUMNS FROM $table")
else
    result=$(mariadb -D $database -e "SHOW COLUMNS FROM $table")
fi

# Split result into an array of columns
IFS=$'\n'
columns=($result)
column_names=()
sql_parts=()
sql="INSERT INTO $database.$table "

# Loop to iterate over columns and generate SQL insert
i=0
varchar_cardinality=1000000000;
bigint_cardinality=10000;
int_cardinality=1;
date_range_days_behind_today=365;
records=$3;
check_primary_keys=false


for i in "${columns[@]:1}"; do
    #echo  $i;
    column_name=$(echo $i | awk '{print $1}')
    column_datatype=$(echo $i | awk '{print $2}')
    column_key=$(echo $i | awk '{print $4}')
    column_extra=$(echo $i | awk '{print $6}')
  
    if ( $check_primary_keys && [ $column_key == "PRI" ] ) || [[ $column_extra == *"auto_increment"* ]]; then
        atLeastOneColumnSkipped=1;
        echo "skipping: $column_name because $column_key"
        continue;
    fi;
    column_names+=($column_name);
    
    if [[ $column_datatype == *"bigint("* ]]; then
        sql_parts+=(" ROUND(RAND() * ${bigint_cardinality}, 0)")
    elif [[ $column_datatype == *"tinyint("* ]]; then
        num=$(echo $column_datatype | sed "s/tinyint(//g" | sed "s/)//g" );    
        if [ $num == 1 ] ;then
            sql_parts+=(" ROUND(RAND(), 0)")
        else
            sql_parts+=(" ROUND(RAND() * 127, 0)")
        fi;
    elif [[ $column_datatype == *"smallint("* ]]; then
           sql_parts+=(" ROUND(RAND() * 32000, 0)")
    elif [[ $column_datatype == *"int("* ]]; then
        sql_parts+=("ROUND(RAND() * ${int_cardinality}, 0)")
    elif [[ $column_datatype == *"float"* ]]; then
        sql_parts+=("ROUND(RAND() * 100000, 6)")
    elif [[ $column_datatype == *"dec("* ]]; then
        echo "default not defined: $column_datatype "
    elif [[ $column_datatype == *"double("* ]]; then
        echo "not implemented datatype: $column_datatype "
        exit 1;
    elif [[ $column_datatype == *"double"* ]]; then
        sql_parts+=("ROUND(RAND() * 10000000, 5)")
    elif [[ $column_datatype == *"mediumtext"* ]]; then
        sql_parts+=("CONCAT(REPEAT(MD5(RAND(100000)), 32))")
    elif [[ $column_datatype == *"text"* ]]; then
        sql_parts+=("substring(MD5(RAND() *10000000000000000000 ),1,500)")
    elif [[ $column_datatype == *"timestamp"* ]]; then
        sql_parts+=("CURRENT_TIMESTAMP - INTERVAL FLOOR(RAND() * ${date_range_days_behind_today} * 24 * 60 *60) SECOND")
    elif [[ $column_datatype == *"datetime"* ]]; then
        sql_parts+=("CURRENT_TIMESTAMP - INTERVAL FLOOR(RAND() * ${date_range_days_behind_today} * 24 * 60 *60) SECOND")
    elif [[ $column_datatype == *"date"* ]]; then
        sql_parts+=("CURRENT_DATE - INTERVAL FLOOR(RAND() * ${date_range_days_behind_today}) DAY")
    elif [[ $column_datatype == *"time"* ]]; then
        sql_parts+=("SEC_TO_TIME(FLOOR(RAND() * 86400))")
    elif [[ $column_datatype == *"varchar"* ]]; then
        varcharInt=$(echo $column_datatype | sed "s/varchar(//g" | sed "s/)//g")
        sql_parts+=("substring(MD5(RAND()*$varchar_cardinality),1,$varcharInt)")
    elif [[ $column_datatype == *"char"* ]]; then
        charInt=$(echo $column_datatype | sed "s/char(//g" | sed "s/)//g")
        sql_parts+=("substring(MD5(RAND()),1,$charInt)")
    elif [[ $column_datatype == *"decimal"* ]]; then
        nums=$(echo $column_datatype | sed "s/decimal(//g" | sed "s/)//g" );
        ints=$(echo $nums | awk -F, '{print $1}' )
        round=$(echo $nums | awk -F, '{print $2}' )
        sql_parts+=("ROUND(RAND() * $((10**$(($ints-$round))-1)), $round)")
    elif echo "$i" | grep -qE '[Ee][Nn][Uu][Mm]\('; then
        # Random member from the column's ENUM definition (SHOW COLUMNS Type / COLUMN_TYPE).
        enum_def=$(echo "$i" | grep -oE '[Ee][Nn][Uu][Mm]\([^)]*\)' | head -1)
        [[ -z "$enum_def" ]] && enum_def="$column_datatype"
        if [[ "$enum_def" =~ ^[Ee][Nn][Uu][Mm]\((.*)\)$ ]]; then
            inner="${BASH_REMATCH[1]}"
        else
            echo "could not parse enum from: $enum_def" >&2
            exit 1
        fi
        IFS=',' read -ra enum_parts <<< "$inner"
        elt_n=${#enum_parts[@]}
        if (( elt_n < 1 )); then
            echo "could not parse enum members from: $enum_def" >&2
            exit 1
        fi
        elt_args=""
        for ep in "${enum_parts[@]}"; do
            ev="$ep"
            ev="${ev#\'}"
            ev="${ev%\'}"
            ev="${ev//\'\'/\'}"
            ev="${ev//\'/\'\'}"
            elt_args+="'${ev}',"
        done
        elt_args="${elt_args%,}"
        sql_parts+=("ELT(1 + FLOOR(RAND() * ${elt_n}), ${elt_args})")
    else
        echo "cant match datatype: $column_datatype "
        exit 1;
    fi;

  #echo $column_name $value
done

# Add column names
v=0
if [ ! -z $atLeastOneColumnSkipped ]; then
    sql="$sql ( "
    for col in "${column_names[@]}"
    do
        sql="$sql $col "
        if [ "${column_names[$v+1]+abc}" ] && echo "exists" > /dev/null; then
            sql="$sql,"
        fi;
        ((v++))
    done
    sql="$sql ) "    
fi;

# Construct select statement
sql="$sql SELECT "
j=0
for parts in "${sql_parts[@]}"
do      

    #echo $parts
    sql="$sql $parts"
    if [ "${sql_parts[$j+1]+abc}" ] && echo "exists" > /dev/null; then
        sql="$sql,"
    fi;
    ((j++))
done

sql="$sql FROM seq_1_to_$records;"
echo $sql






