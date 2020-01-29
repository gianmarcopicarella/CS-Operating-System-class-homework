BEGIN {
	files="";
	counter=1;
	for(i = 1; i < ARGC; i++){
		if(match(ARGV[i], /conf\.[01]\.[01]\.[01]\.txt/) != 0) {
			counter++;
		}
		files = files" "ARGV[i] 
	}

	# stampa i files in stdout e stderr
	print "Eseguito con argomenti"files > "/dev/stdout";
	print "Eseguito con argomenti"files > "/dev/stderr";

	# se i files sono < 2 allora errore
	if(ARGC-1 < 2){
		print "Errore: dare almeno 2 file di input" > "/dev/stderr";
		exit 0;
	}


	# variabili globali
	filecount=0;
	fileinvalid=0;

	only_figs="0";
	also_figs="0";
	strip_comments="0";

	text="";

}

BEGINFILE {
	filecount++;
	text="";
	if(filecount > counter && !(FILENAME in visited) && strip_comments=="1"){
		print "Errore: il file "FILENAME" non risulta incluso" > "/dev/stderr";
		fileinvalid++;
	}
}

# parsing file I1

/only_figs=/ && filecount <= counter {
	only_figs=substr($0, index($0, "=")+1, 1)
	next;
}

/also_figs=/ && filecount <= counter {
	also_figs=substr($0, index($0, "=")+1, 1)
	next;	
}

/strip_comments=/ && filecount <= counter {
	strip_comments=substr($0, index($0, "=")+1, 1)
	next;
}
# fine parsing file I1

# parsing file I2

filecount <= counter {
	text=text""$0;
}

match(text, /\(\.[a-zA-Z\/\-0-9\.\_]*\.(tex|cls|sty|bbl|aux)/) != 0 && filecount <= counter {
	file=substr(text, RSTART+1, RLENGTH-1);
	ext=substr(file, length(file)-2);
	visited[file]=""
	if(only_figs == "0" && ext == "tex" && filecount == 2){
		print file;
	}
	text=substr(text, RSTART+RLENGTH);
}


match(text, /File:\s\.\/[a-zA-Z\/\-0-9\.\_]*\.(png|jpg|pdf)/) != 0 && filecount <= counter {
	if(only_figs == "1" || also_figs == "1" && filecount == 2){
		doc=substr(text, RSTART+6, RLENGTH-6);
		print doc;
	}
	text=substr(text, RSTART+RLENGTH);
}

# fine parsing file I2

match($0, /^\s*\%.*/) != 0 {
	next;
}

match($0, /[^\\]\%.*/) != 0 {
	text=text""substr($0, 1, RSTART)"\n";
	next
}

filecount > counter {
	text=text""$0"\n";
}

ENDFILE {
	# se strip_comments == 1 && invisited == 1
	if(filecount > counter && strip_comments == "1" && FILENAME in visited){
		print substr(text, 1, length(text)-1) > FILENAME
	}

	# se filecount <= counter and only_figs == 1 and also_figs == 0 -> errore
	if(filecount <= counter && only_figs == "1" && also_figs == "0") {
		print "Errore di configurazione: only_figs=1 e also_figs=0" > "/dev/stderr";
		exit 0;
	}
}

END {
	exit fileinvalid;
}