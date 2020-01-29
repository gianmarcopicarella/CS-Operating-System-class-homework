#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <locale.h>

int check_param_value(char * str, int * val);
void _scandir(char* path);
void bubble_sort(char * array[], int len);
void print_file(char * path, char * filename, int add);

enum file_type {
	FL = 0,
	DR = 1,
	SYM = 2,
	UNDEF = 3
};

enum file_type get_file_type(char* path);

short int d_flag = 0;
short int R_flag = 0;
short int l_flag = 0;
short int printed_flag = 0;
short int dir_c = 0;

int l_val = 0;


int main(int argc, char** argv){

	setlocale(LC_ALL, "C");

	char * filename = argv[0];

	int option = -1;

	while((option = getopt(argc, argv, ":dRl:")) != -1){

		switch(option){
			case 'd':
				d_flag = 1;
			break;

			case 'R':
				R_flag = 1;
			break;

			case 'l':
				if(check_param_value(optarg, &l_val) == 0){
					l_flag = 1;
				}
				else {
					fprintf(stderr, "%s [-dR] [-l mod] [files]\n", filename);
					exit(20);
				}
			break;

			case '?':
			case ':':
				fprintf(stderr, "%s [-dR] [-l mod] [files]\n", filename);
				exit(20);
			break;
		}
	}

	int files_type_counter[4] = {0, 0, 0, 0};

	for(int i = optind; i < argc; i++){
		files_type_counter[get_file_type(argv[i])]++;
	}

	char * files_and_links[files_type_counter[FL] + files_type_counter[SYM]];
	char * dirs[files_type_counter[DR]];

	int fc = 0, dc = 0;

	for(int i = optind; i < argc; i++){
		switch(get_file_type(argv[i])){
			case FL:
			case SYM:
				files_and_links[fc++] = argv[i];
			break;
			case DR:
				dirs[dc++] = argv[i];
			break;
			case UNDEF:
				fprintf(stderr, "%s: cannot access \'%s\': No such file or directory\n", filename, argv[i]);
			break;
		}
	}

	bubble_sort(files_and_links, files_type_counter[FL] + files_type_counter[SYM]);
	bubble_sort(dirs, files_type_counter[DR]);	

	if(files_type_counter[DR] > 0){
		dir_c = 1;
	}

	if(d_flag == 0){
		for(int i = 0; i < files_type_counter[FL] + files_type_counter[SYM]; i++){
			print_file("", files_and_links[i], 0);
			printed_flag = 1;
		}

		// stampa ricorsiva partendo dalle directories
		for(int i = 0; i < files_type_counter[DR]; i++){
			_scandir(dirs[i]);
		}	

		if(files_type_counter[DR] == 0 && files_type_counter[FL] + files_type_counter[SYM] == 0){
			_scandir(".");
		}

	}
	else {
		int size = files_type_counter[DR] +files_type_counter[FL] + files_type_counter[SYM];
		char * files_dirs_links[size];
		for(int i = 0; i < files_type_counter[DR]; i++){
			files_dirs_links[i] = dirs[i];
		}
		for(int i = files_type_counter[DR]; i < size; i++){
			files_dirs_links[i] = files_and_links[i-files_type_counter[DR]];
		}

		bubble_sort(files_dirs_links, size);

		if(size > 0){
			printed_flag = 1;
		}

		for(int i = 0; i < size; i++){
			print_file("", files_dirs_links[i], 0);
			printed_flag = 1;
		}

		if(files_type_counter[DR] == 0 && files_type_counter[FL] + files_type_counter[SYM] == 0){
			print_file("", ".", 0);
			printed_flag = 1;
		}
	}

	return files_type_counter[UNDEF] > 0 ? files_type_counter[UNDEF] : 0;
}

void build_path(char * full_path, char * path, char * filename, int add_sep){
	strcpy(full_path, path);
	if(add_sep == 1) strcat(full_path, "/");
	strcat(full_path, filename);
}

char get_file_letter(int bits){
    if (S_ISDIR(bits)) return 'd';
    else if (S_ISLNK(bits)) return 'l';
	return '-';
};

int get_total_dir_size(char * path, struct dirent ** files, int size, int add){
	int total = 0;
	for(int i = 0; i < size; i++){
		char full_path[1024];
		build_path(full_path, path, files[i]->d_name, add);

		struct stat fileStat;
		lstat(full_path, &fileStat);

		if(files[i]->d_name[0] != '.' && get_file_letter(fileStat.st_mode) != 'l'){
			int dim = fileStat.st_size;
            int block_size = fileStat.st_blksize;
            int temp = dim/block_size + (dim % block_size != 0);
            temp = block_size*temp;
            total += temp;
		}
	}

	char * env = getenv("BLOCKSIZE");
	return env != NULL ? (total / atoi(env)) : (total / 1024);
};

void print_file(char * path, char * filename, int add){
	// permission types
	static const char *rwx[] = {"---", "--x", "-w-", "-wx",
    "r--", "r-x", "rw-", "rwx"};

	// creo il path assoluto del file
	char full_path[1024];
	build_path(full_path, path, filename, add);

	struct stat fileStat;
	lstat(full_path, &fileStat);

	// se è un link simbolico -> creo la stringa con il file puntato
	char buff[1024];
	buff[0] = '\0';
	int len = 0;
	
	char perm[11];
	perm[0] = get_file_letter(fileStat.st_mode);

	if(perm[0] == 'l'){
		len = readlink(full_path, buff, 1023);
		buff[len] = '\0';
	}

	strcpy(&perm[1], rwx[(fileStat.st_mode >> 6)& 7]);
    strcpy(&perm[4], rwx[(fileStat.st_mode >> 3)& 7]);
    strcpy(&perm[7], rwx[(fileStat.st_mode & 7)]);
    if (fileStat.st_mode & S_ISUID)
        perm[3] = (fileStat.st_mode & S_IXUSR) ? 's' : 'S';
    if (fileStat.st_mode & S_ISGID)
        perm[6] = (fileStat.st_mode & S_IXGRP) ? 's' : 'S';
    if (fileStat.st_mode & S_ISVTX)
        perm[9] = (fileStat.st_mode & S_IXOTH) ? 't' : 'T';
    perm[10] = '\0';

	if(l_val == 0 && l_flag == 1) {
		printf("%s\t%d\t%d\t%s%s%s\n", perm, fileStat.st_nlink, fileStat.st_size, filename, len > 0 ? " -> " : "", buff);	
	}
	else if(l_flag == 1){
		printf("%s\t%s%s%s\n", perm, filename, len > 0 ? " -> " : "", buff);
	}
	else {
		printf("%s\n", filename);
	}
}


void _scandir(char * path){
	struct dirent ** files;
	int num_files = scandir(path, &files, NULL, alphasort);

	int name_printed_flag = 0;

	if(R_flag == 1 || dir_c == 1){
		printf("%s%s:\n", printed_flag == 1 ? "\n" : "", path);
		name_printed_flag = 1;
		printed_flag = 1;
	}

	int add = 1 - (path[strlen(path)-1] == '/');

	if(l_flag == 1){
		printf("%stotal %d\n", (printed_flag == 1 && name_printed_flag == 0) ? "\n" : "", get_total_dir_size(path, files, num_files, add));
	}


	for(int i = 0; i < num_files; i++){
		if(files[i]->d_name[0] != '.'){
			print_file(path, files[i]->d_name, add);
		}
	}

	if(R_flag == 1){
		for(int i = 0; i < num_files; i++){
			if(files[i]->d_name[0] != '.'){
				char dir_path[1024];
				build_path(dir_path, path, files[i]->d_name, add);

				struct stat fileStat;
				lstat(dir_path, &fileStat);

				if(get_file_letter(fileStat.st_mode) == 'd'){
					_scandir(dir_path);
				}
			}
		}
	}

	for(int i = 0; i < num_files; i++){
		free(files[i]);
	}
	free(files);
};

int check_param_value(char * str, int * val){
	int len = 0;
	while(str[len] >= '0' && str[len] <= '9' && str[len] != '\0') 
		len++;
	if(str[len] != '\0'){
		return 1;
	}
	*val = atoi(str);
	return 0;
};

enum file_type get_file_type(char* path){
	struct stat sb;
	
	if(lstat(path, &sb) != 0) return UNDEF;

	if(S_ISDIR(sb.st_mode)){
		return DR;
	}
	else if(S_ISREG(sb.st_mode)){
		return FL;
	}
	else if(S_ISLNK(sb.st_mode)){
		return SYM;
	}

	return UNDEF;
};

void bubble_sort(char * array[], int len){
	char * temp;
	for(int i = 0; i < len; i++){
		for(int k = i+1; k < len; k++){
			if(strcmp(array[i], array[k]) > 0){
				temp = array[i];
				array[i] = array[k];
				array[k] = temp;
			}
		}
	}
};
