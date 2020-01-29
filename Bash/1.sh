#!/bin/bash

flag_e=0
flag_b=0

par_b=""
par_path=""


exit_func(){
	local message=$1
    local exitcode=$2
    if ! [ -z "${message}" ]; then
            1>&2 echo "$message"
    fi
    exit $exitcode
}

filename=$(basename "$0")

while getopts ":eb:" c; do
        case $c in
                e) flag_e=1 ;;
                b) flag_b=1; par_b=$OPTARG ;;
                \?) exit_func "Uso: $filename [opzioni] directory" 10 ;;
                :) exit_func "Uso: $filename [opzioni] directory" 10 ;;
        esac
done

shift $(($OPTIND-1))

path=$1

shift

# se dopo la directory d c'è qualcos'altro -> allora errore 10
if ! [ -z "$1" ]; then
	exit_func "Uso: $filename [opzioni] directory" 10
fi

# se -e e -b sono settati -> errore 10
if [ $flag_e = 1 ] && [ $flag_b = 1 ]; then
	exit_func "Uso: $filename [opzioni] directory" 10
fi

# se path è = "" -> errore 10
if [ -z "$path" ]; then
	exit_func "Uso: $filename [opzioni] directory" 10
fi

# ------------------------

# se d non esiste --> errore 100

if ! [ -e "$path" ]; then
	exit_func "L'argomento $path non e' valido in quanto non e' una directory esistente" 100
fi

# se d esiste ma è un file --> errore 100

if [ -f "$path" ]; then
	exit_func "L'argomento $path non e' valido in quanto non e' una directory" 100
fi

# se non (ha i permessi di lettura and esecuzione) --> errore 100
if [ ! -r "$path" ] || [ ! -x "$path" ]; then
	exit_func "L'argomento $path non e' valido in quanto non ha i permessi richiesti" 100	
fi

# ------------------------


# se -b è settato ->
if [ $flag_b = 1 ]; then

	# se l'item b non esiste -> allora la creo con quel nome e setto i diritti a 700
	if ! [ -e $par_b ]; then
		
		# se mkdir non riesce a crearla -> allora errore 200
		if ! [ -z "$(mkdir $par_b 2>&1)" ]; then
			exit_func "L'argomento $par_b non e' valido in quanto non è possibile creare la directory" 200
		fi

		# setto i diritti a 700
		chmod 700 $par_b
	fi

	# se non è una directory -> errore 200
	if ! [ -d $par_b ]; then
		exit_func "L'argomento $par_b non e' valido in quanto non è una directory" 200
	fi

	# se non ha i diritti a 700 -> errore 200
	if [ "$(stat -c %a $par_b)" != "700" ]; then
		exit_func "L'argomento $par_b non e' valido in quanto non ha i permessi richiesti" 200
	fi

fi

# ---------------------- inizio while
vis=""
str=""
regex_data="([0-9]{4})(0[1-9]|10|11|12)(0[1-9]|1[0-9]|2[0-9]|3[0-1])(0[0-9]|1[0-9]|2[0-3])([0-5][0-9])"

while IFS="" read -r f1; do

	var1=$(echo "$f1" | egrep -o "$regex_data")

	# prendo la path del file puntato dal file
	fp="$(readlink -f $f1)"
	var2=$(echo "$fp" | egrep -o "$regex_data")

	# se sono nello stesso gruppo di data
	if [ "$var1" = "$var2" ]; then
		vis="$vis $f1"
		str="$str $f1"
	fi

done <<<$(find $path -regextype posix-extended -type l -regex ".*_([0-9]{4})(0[1-9]|10|11|12)(0[1-9]|1[0-9]|2[0-9]|3[0-1])(0[0-9]|1[0-9]|2[0-3])([0-5][0-9])_.*\.(txt|jpg|TXT|JPG)")


while IFS="" read -r f1; do
	
	# CASO 2) se è un file e un hard link
	if [ "$(stat --format %h $f1)" > "1" ]; then

		# se f1 non fa parte di qualche altro insieme
		if ! [[ $vis == *"$f1"* ]]; then

			vis="$vis $f1"
			var1=$(echo "$f1" | egrep -o "$regex_data")
			vartemp="$f1"
			flag="0"

			while IFS="" read -r f2; do

				# se f2 non fa parte di qualche altro insieme e f1 != f2
				if ! [[ $vis == *"$f2"* ]] && [ "$f1" != "$f2" ]; then
					vis="$vis $f2"
					flag="1"
					# se f1 è maggiore di f2
					if [ $(printf "%s\n%s" "$vartemp" "$f2" | LC_ALL=C sort -r | head -1) = "$f2" ]; then 
						# viene tolto f1
						vartemp="$f2"
					fi
				fi
			done <<<$(find $path -samefile $f1 -regextype posix-extended  -regex ".*_${var1}_.*\.(txt|jpg|TXT|JPG)")
			if [ $flag = "1" ]; then
				# viene tolto $vartemp
				str="$str $vartemp"
			fi
		fi
	fi
	
done <<<$(find $path -regextype posix-extended -type f -regex ".*_([0-9]{4})(0[1-9]|10|11|12)(0[1-9]|1[0-9]|2[0-9]|3[0-1])(0[0-9]|1[0-9]|2[0-3])([0-5][0-9])_.*\.(txt|jpg|TXT|JPG)")

# --------------------
vis="$str"
while IFS="" read -r f1; do
	
	# se f1 non è tra i visitati
	if [[ ! $vis == *"$f1"* ]]; then

		var1=$(echo "$f1" | egrep -o "$regex_data")
		size1="$(stat -L -c %s $f1)"

		files="$f1"
		flag="0"

		while IFS="" read -r f2; do
			if [[ ! $str == *"$f2"* ]] && [ "$f1" != "$f2" ] && [ -z "$(diff $f1 $f2)" ]; then

				flag="1"
				files="$files $f2"
			fi

		done <<<$(find -L $path -size ${size1}c -type f -regextype posix-extended -regex ".*_${var1}_.*\.(txt|jpg|TXT|JPG)")
		vis="$vis $files"
		if [ "$flag" = "1" ]; then
			str="$str $(echo -e "${files}" | tr " " "\n" | LC_ALL=C sort -r | sed '1d' | tr '\n' ' ')"
		fi
	fi

done <<<$(find $path -type f -regextype posix-extended -regex ".*_([0-9]{4})(0[1-9]|10|11|12)(0[1-9]|1[0-9]|2[0-9]|3[0-1])(0[0-9]|1[0-9]|2[0-3])([0-5][0-9])_.*\.(txt|jpg|TXT|JPG)")

echo $(echo $str | tr " " "\n" | LC_ALL=C sort) | tr " " "|"

IFS=' '
if [ "$flag_e" = "0" ]; then
	
	if [ "$flag_b" = "1" ]; then
		for p in $str; do
			mkdir -p "$(dirname ${p/${path}/${par_b}})"
			mv "$p" "$(dirname ${p/${path}/${par_b}})"
		done
	else
		for p in $str; do
			rm $p
		done
	fi
fi


while IFS="" read -r f1; do
	# se il link simbolico punta ad un file non esistente
	if [[ ! -a "$f1" ]];then 
			unlink $f1
	fi
done <<<$(find $path -regextype posix-extended -type l -regex ".*_([0-9]{4})(0[1-9]|10|11|12)(0[1-9]|1[0-9]|2[0-9]|3[0-1])(0[0-9]|1[0-9]|2[0-3])([0-5][0-9])_.*\.(txt|jpg|TXT|JPG)")

exit 0
