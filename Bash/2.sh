#!/bin/bash

exit_func(){
	local message=$1
    local exitcode=$2
    if ! [ -z "${message}" ]; then
            1>&2 echo "$message"
    fi
    exit $exitcode
}

errormessage="Usage: $0 bytes walltime sampling commands files"

# se la lunghezza dell'array è minore di 2 -> errore
 if [ "${#@}" -lt "3" ]; then
	exit_func "$errormessage" 15
fi

# prendo il primo
numbytes=$1

# se $1 non è un numero -> errore
if [ -z "$numbytes" ] || [ ! "$numbytes" -eq "$numbytes" ] 2>/dev/null; then
  exit_func "$errormessage" 15
fi

shift

# prendo il secondo
walltime=$1
	
# se $2 non è un numero -> errore
if [ -z "$walltime" ] || [ ! "$walltime" -eq "$walltime" ] 2>/dev/null; then
  exit_func "$errormessage" 15
fi

shift

# prendo il terzo
sampletime=$1
	
# se $3 non è un numero -> errore
if [ -z "$sampletime" ] || [ ! "$sampletime" -eq "$sampletime" ] 2>/dev/null; then
  exit_func "$errormessage" 15
fi

shift

str="$@"

declare -a commands
declare -a files

# parso i processi

i=0

IFS=";;"
for proc in ${str%;;;*}; do
	if [ -n "${proc//' '/}" ]; then
		commands[$i]=$(echo "$proc" | sed -E "s,\s?,,")
		i=$((i + 1))
	fi
done

# se ho 0 comandi -> errore
if [ "${#commands[@]}" = "0" ]; then
	exit_func "$errormessage" 15
fi


# parso i file

i=0

IFS=" "
for proc in ${str#*;;;}; do
	if [ -n "${proc//' '/}" ]; then
		files[$i]="$(echo "$proc" | sed -E "s,\s?,,")"
		i=$((i + 1))
	fi
done

# se ho 0 comandi -> errore
if [ "${#files[@]}" = "0" ]; then
	exit_func "$errormessage" 15
fi


# se numfiles != 2*numcommands -> errore

if [ "$(expr ${#commands[@]} \* 2)" != "${#files[@]}" ] || [ "$(expr ${#files[@]} / 2)" != "${#commands[@]}" ]; then
	exit_func "$errormessage" 30
fi

# itera ed avvia i processi

i=0
processi=""
count=0

while [ "$i" -lt "${#commands[@]}" ]; do

	file=${commands[$i]%% *}
	
	# se il file esiste ed è eseguibile oppure è un comando esistente
	if [ -f "$file" ] && [ -x "$file" ] || [ -n "$(which $file)" ]; then 
		file_err_id=$(expr ${#commands[@]} + $i)
		${commands[$i]} > ${files[$i]} 2>${files[$file_err_id]} &
		processi="$processi $!"
		count=$((count + 1))
	fi

	i=$((i + 1))
done


# scrivo sul file descriptor 3 i processi avviati
echo "$processi" >&3

# inizio a monitorare i processi
while [ ! -f "./done.txt" ] && [ ! "$count" = "0" ]; do

	# fai i controlli
	torem=""
	for process in ${processi}; do
		if [ -n "$(ps | grep $process | sed 's, ,,g')" ]; then
			time="$(ps -o etimes= -p $process | sed -e 's,[^0-9],,g')"
			size="$(expr $(ps -o rss= -p $process | sed -e 's,[^0-9],,g') \* 1000)"
			if [ "$walltime" -gt "0" ] && [ "$time" -gt "$walltime" ]; then
				torem="$torem $process"
			elif [ "$numbytes" -gt "0" ] && [ "$size" -gt "$numbytes" ]; then
				torem="$torem $process"
			fi	
		else
			torem="$torem $process"
		fi
	done

	# rimuovo i processi
	for id in ${torem}; do
		if [ -n "$(ps | grep $id | sed 's, ,,g')" ]; then
			kill -INT $id
		fi
		processi="$(echo $processi | sed -e 's,$id,,')"
		count=$((count - 1))
	done

	sleep $sampletime
done

if [ -f "./done.txt" ]; then
	echo "File done.txt trovato" >&1
	exit 0
else
	echo "Tutti i processi sono terminati" >&1
	exit 1
fi