#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

int main(int argc, char *argv[]) {
    // Initialize syslog logging
    openlog("writer", LOG_PID|LOG_CONS, LOG_USER);

    // Check for proper number of arguments
    if(argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments. Usage: %s <path/to/file> <string to write>\n", argv[0]);
        fprintf(stderr, "Invalid number of arguments. Usage: %s <path/to/file> <string to write>\n", argv[0]);
        return 1; // Return an error
    }

    FILE *fp;
    fp = fopen(argv[1], "w"); // Attempt to open file for writing

    if(fp == NULL) {
        syslog(LOG_ERR, "Failed to open file: %s\n", argv[1]);
        perror("Error opening file");
        return 1; // Return an error
    }

    // Write to the file
    fprintf(fp, "%s\n", argv[2]);
    // Log to syslog
    syslog(LOG_DEBUG, "Writing %s to %s", argv[2], argv[1]);


    fclose(fp);
    closelog();

    return 0; // Success
}
