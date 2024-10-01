#include <stdio.h>
#include <syslog.h>

int main(int argc, char **argv) {
    printf("Writing %s to %s", argv[1], argv[2]);
    openlog(NULL, 0, LOG_USER);

    if (argc == 1) {
        syslog(LOG_ERR, "No parameter specified");
        return 1;
    }

    char* content = argv[1];
    char* filename = argv[2];
    syslog(LOG_DEBUG, "Writing %s to %s", content, filename);

    FILE *fptr;
    fptr = fopen(filename, "w");
    if (fptr == NULL) {
        syslog(LOG_ERR, "Error to open file pointer %s", filename);
        return 1;
    }
    fprintf(fptr, "%s", content);

    fclose(fptr);

    return 0;
}