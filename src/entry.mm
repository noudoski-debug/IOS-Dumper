#import <Foundation/Foundation.h>
#import "dumper.h"
#import <pthread.h>
#import <mach-o/dyld.h>

static void* WorkerThread(void*) {
    // Wait for runtime initialization
    sleep(5);

    // Save to user Documents or shared Downloads
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docsDir = [paths firstObject];
    NSString* dumpDir = [docsDir stringByAppendingPathComponent:@"Dump"];

    // Also copy to rootless Downloads if accessible (/var/mobile/Media/Downloads)
    NSString* downloadsDir = @"/var/mobile/Media/Downloads/Dump";

    Dumper::DumpIl2Cpp([dumpDir UTF8String]);
    
    // Attempt copy to Downloads
    NSFileManager* fm = [NSFileManager defaultManager];
    [fm copyItemAtPath:dumpDir toPath:downloadsDir error:nil];

    return nullptr;
}

__attribute__((constructor))
static void Entry() {
    pthread_t t;
    pthread_create(&t, nullptr, WorkerThread, nullptr);
}
