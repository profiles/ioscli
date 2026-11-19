#import <Foundation/Foundation.h>

@interface MCProfileConnection : NSObject

+ (instancetype)sharedConnection;
- (NSArray *)installedProfileIdentifiers;
- (id)installProfileData:(NSData *)data
                 options:(NSDictionary *)options
                outError:(NSError **)error;
- (void)removeProfileWithIdentifier:(NSString *)identifier;

@end
