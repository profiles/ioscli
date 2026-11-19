#ifndef IOSCLI_PROFILE_H
#define IOSCLI_PROFILE_H

@class NSString;

int profile_main(int argc, char **argv, const char *prog);
int profile_list(void);
int profile_install(NSString *path);
int profile_remove(NSString *identifier);

#endif
