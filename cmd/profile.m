#import "profile.h"
#import <ManagedConfiguration/ManagedConfiguration.h>
#import <Foundation/Foundation.h>
#include <getopt.h>
#include <stdio.h>
#include <string.h>

static NSData *loadProfileData(NSString *path) {
    NSData *raw;
    if ([path isEqualToString:@"-"]) {
        raw = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
    } else {
        raw = [NSData dataWithContentsOfFile:path];
        if (raw.length == 0) {
            NSString *alternate = [path hasPrefix:@"/rootfs"]
                ? [path substringFromIndex:7]
                : [@"/rootfs" stringByAppendingString:path];
            raw = [NSData dataWithContentsOfFile:alternate];
        }
    }
    return raw.length > 0 ? raw : nil;
}

static NSString *profileIdentifier(NSData *data) {
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:NULL
                                                           error:NULL];
    if ([plist isKindOfClass:[NSDictionary class]]) {
        id identifier = [(NSDictionary *)plist objectForKey:@"PayloadIdentifier"];
        if ([identifier isKindOfClass:[NSString class]]) {
            return identifier;
        }
    }
    return nil;
}

int profile_list(void) {
    MCProfileConnection *connection = [MCProfileConnection sharedConnection];
    if (connection == nil) {
        fprintf(stderr, "[-] MCProfileConnection unavailable\n");
        return 1;
    }
    NSArray *identifiers = [connection installedProfileIdentifiers];
    if (![identifiers isKindOfClass:[NSArray class]]) {
        fprintf(stderr, "[-] installedProfileIdentifiers returned an unexpected value\n");
        return 1;
    }
    for (id identifier in identifiers) {
        printf("%s\n", [[identifier description] UTF8String]);
    }
    return 0;
}

int profile_install(NSString *path) {
    NSData *data = loadProfileData(path);
    if (data == nil) {
        fprintf(stderr, "[-] cannot read profile: %s\n", path.UTF8String);
        return 1;
    }
    NSString *identifier = profileIdentifier(data);
    MCProfileConnection *connection = [MCProfileConnection sharedConnection];
    if (connection == nil) {
        fprintf(stderr, "[-] MCProfileConnection unavailable\n");
        return 1;
    }
    NSError *error = nil;
    id result = [connection installProfileData:data options:@{} outError:&error];
    if (error != nil) {
        fprintf(stderr, "[-] install failed: %s\n", [[error description] UTF8String]);
        return 1;
    }
    if (identifier != nil) {
        printf("[+] installed: %s\n", identifier.UTF8String);
    } else if (result != nil) {
        printf("[+] installed: %s\n", [[result description] UTF8String]);
    } else {
        printf("[+] installed\n");
    }
    return 0;
}

int profile_remove(NSString *identifier) {
    MCProfileConnection *connection = [MCProfileConnection sharedConnection];
    if (connection == nil) {
        fprintf(stderr, "[-] MCProfileConnection unavailable\n");
        return 1;
    }
    [connection removeProfileWithIdentifier:identifier];
    printf("[+] remove requested: %s\n", identifier.UTF8String);
    return 0;
}

static void profileUsage(const char *prog) {
    printf("usage: %s profile -a|--add <mobileconfig|->          install a configuration profile\n", prog);
    printf("       %s profile -d|--remove <payload-identifier>   remove an installed profile\n", prog);
    printf("       %s profile -l|--list                          list installed configuration profiles\n", prog);
    printf("\n");
    printf("  --install is an alias for --add; --delete is an alias for --remove.\n");
}

int profile_main(int argc, char **argv, const char *prog) {
    @autoreleasepool {
        int action = 0;
        NSString *value = nil;
        int opt;
        enum {
            OPT_ADD = 1000,
            OPT_REMOVE,
            OPT_LIST,
        };
        static struct option longOptions[] = {
            {"add", required_argument, NULL, OPT_ADD},
            {"install", required_argument, NULL, OPT_ADD},
            {"remove", required_argument, NULL, OPT_REMOVE},
            {"delete", required_argument, NULL, OPT_REMOVE},
            {"list", no_argument, NULL, OPT_LIST},
            {"help", no_argument, NULL, 'h'},
            {NULL, 0, NULL, 0},
        };
        optind = 1;
        while ((opt = getopt_long(argc, argv, "a:d:lh", longOptions, NULL)) != -1) {
            switch (opt) {
                case 'a':
                case OPT_ADD:
                    action = 'a';
                    value = @(optarg);
                    break;
                case 'd':
                case OPT_REMOVE:
                    action = 'd';
                    value = @(optarg);
                    break;
                case 'l':
                case OPT_LIST:
                    action = 'l';
                    break;
                case 'h':
                    profileUsage(prog);
                    return 0;
                default:
                    profileUsage(prog);
                    return 2;
            }
        }
        switch (action) {
            case 'a':
                if (value == nil) {
                    profileUsage(prog);
                    return 2;
                }
                return profile_install(value);
            case 'd':
                if (value == nil) {
                    profileUsage(prog);
                    return 2;
                }
                return profile_remove(value);
            case 'l':
                return profile_list();
            default:
                profileUsage(prog);
                return 2;
        }
    }
}
