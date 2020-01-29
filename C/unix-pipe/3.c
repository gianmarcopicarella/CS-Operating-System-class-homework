#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

int file_exist(char * path, char * mode){
	FILE * fp;
	if((fp = fopen(path, mode))){
		fclose(fp);
		return 0;
	}
	return -1;
};

int is_number(char * str){
	int len = 0;
	while(str[len] >= '0' && str[len] <= '9' && str[len] != '\0') {
		len++;
	}
	return (len > 0 && str[len] == '\0') ? 0 : -1;
};

void exit_proc(int exit_code, char * param[]){
	switch(exit_code){
		case 10:
			fprintf(stderr, "Usage: %s filein fileout awk script i1 i2\n", param[0]);
			exit(exit_code);
		break;
		case 30:
			fprintf(stderr, "Wrong format for input binary file %s\n", param[0]);
			FILE * fp = fopen(param[1], "wb");
			fclose(fp);
			exit(exit_code);
		break;
		case 20:
			fprintf(stderr, "Unable to open file %s because of e\n", param[0]);
			exit(exit_code);
		break;
		case 70:
			fprintf(stderr, "Unable to open file %s because of e\n", param[0]);
			exit(exit_code);
		break;
		case 80:
		case 100:
			exit(exit_code);
		break;
	}
}

void pipe_data_to_file(int pipe[2], FILE * f, char * buff, int buff_size, int * counter, int i1, int i2){
	int s1;
	while((s1 = read(pipe[0], buff, buff_size)) != 0){
		int k = *counter;
		while(k < *counter + s1){
			if(k >= i1 && k < i1+i2){
				buff[k - *counter] = ~buff[k - *counter];
				fwrite(&buff[k++ - *counter], sizeof(char), 1, f);
				continue;
			}
			fwrite(&buff[k++ - *counter], sizeof(char), 1, f);
		}
		*counter += s1;
	}
};

void complement_array(char array[], int start, int end){
	for(int i = start; i < end; i++) array[i] = ~array[i];
}

int main(int argc, char ** argv){

	// parsing parametri
	char * exit_params[2];
	exit_params[0] = argv[0];

	// manca un parametro
	if(argc - 1 != 5 || is_number(argv[4]) == -1 || is_number(argv[5]) == -1) {
		exit_proc(10, exit_params);
	}

	if(file_exist(argv[1], "rb") == -1){
		exit_params[0] = argv[1];
		exit_proc(20, exit_params);
	}

	if(file_exist(argv[2], "wb") == -1){
		exit_params[0] = argv[2];
		exit_proc(70, exit_params);
	}

	int i1 = atoi(argv[4]), i2 = atoi(argv[5]);

	// ottengo la dimensione del file in byte
	struct stat fb;
	lstat(argv[1], &fb);

	exit_params[0] = argv[1];
	exit_params[1] = argv[2];

	if(fb.st_size < 8){	
		exit_proc(30, exit_params);
	}

	// apro il file input
	FILE * f = fopen(argv[1], "rb");

	// leggo i due interi
	int n1 = 0, n2 = 0;

	fread(&n1, sizeof(int), 1, f);
	fread(&n2, sizeof(int), 1, f);

	if(fb.st_size < 8 + n1 + n2){
		fclose(f);
		exit_proc(30, exit_params);
	}

	// alloco un buffer per il file
	char * buff = malloc(fb.st_size * sizeof(char) - 8);

	// leggo il file
	fread(buff, fb.st_size - 8, 1, f);
	fclose(f);

	complement_array(buff, n1, n1+n2);

	// salvo il buffer sul file temp.txt
	FILE * temp = fopen("temp.txt", "w");

	fwrite(buff, sizeof(char), fb.st_size * sizeof(char) - 8, temp);
	fclose(temp);
	free(buff);


	int pipes[2];
	int pipes_e[2];

	// crea la pipe
	if(pipe(pipes) || pipe(pipes_e)){
		exit_proc(100, NULL);
	}

	// genera processo figlio
	pid_t pid = fork();

	if(pid == 0){
		// processo figlio
		
		close(pipes[0]);
		close(pipes_e[0]);

		dup2(pipes_e[1], 2);
		dup2(pipes[1], 1);
		
		char *params[] = {(char *)"gawk", NULL, "temp.txt", NULL};
		params[1] = argv[3];

		if(execvp(params[0], params) < 0){
			fprintf(stderr, "%s\n", "execvp failed execution");
			exit(1);
		}

		exit(0);
	}
	else {
		// processo padre

		close(pipes[1]);
		close(pipes_e[1]);

		int status;

		pid_t wpid = waitpid(pid, &status, 0);

		FILE * fout = fopen(argv[2], "wb");
		fseek(fout, 8, SEEK_SET);
		
		char buff[4096];
		int counter = 0;

		pipe_data_to_file(pipes, fout, buff, 4096, &counter, i1, i2);
		pipe_data_to_file(pipes_e, fout, buff, 4096, &counter, i1, i2);

		close(pipes[0]);
		close(pipes_e[0]);

		remove("temp.txt");

		short int flag = 0;

		if(counter < i1+i2){
			flag = 1;
			if(counter > i1){
				fseek(fout, 8 + i1, SEEK_SET);
				char * arr = malloc(counter - i1);
				fread(arr, sizeof(char), counter-i1, fout);
				fseek(fout, 8 + i1, SEEK_SET);
				complement_array(arr, 0, counter-i1);
				fwrite(arr, sizeof(char), counter-i1, fout);
				free(arr);
			}
			i1 = 0, i2 = 0;
		}

		fseek(fout, 0, SEEK_SET);
		fwrite(&i1, 4, 1, fout);
		fwrite(&i2, 4, 1, fout);
		fclose(fout);
		exit_proc((flag == 0 && pid == wpid && WIFEXITED(status)) ? 0 : 80, NULL);
	}
}