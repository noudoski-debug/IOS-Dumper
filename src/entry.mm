#import <Foundation/Foundation.h>
#import "dumper.h"
#import <pthread.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <UIKit/UIKit.h>

static void ShowAlertOnScreen(NSString* title, NSString* msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* window = nil;
        for (UIWindowScene* scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow* w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }
        }
        if (!window) window = [UIApplication sharedApplication].keyWindow;

        UIViewController* root = window.rootViewController;
        while (root.presentedViewController) {
            root = root.presentedViewController;
        }

        UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

static void* WorkerThread(void*) {
    // Ждём инициализации рантайма il2cpp (до 30 сек)
    void* il2cpp = nullptr;
    for (int i = 0; i < 30; ++i) {
        il2cpp = dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
        if (il2cpp) break;
        sleep(1);
    }

    if (!il2cpp) {
        // Игра не на Unity/Il2Cpp
        return nullptr;
    }

    // Сохраняем в Documents приложения
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docsDir = [paths firstObject];
    NSString* dumpDir = [docsDir stringByAppendingPathComponent:@"Dump"];

    Dumper::DumpIl2Cpp([dumpDir UTF8String]);

    // Копируем в общую папку Downloads
    NSString* downloadsDir = @"/var/mobile/Media/Downloads/Dump";
    NSFileManager* fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:@"/var/mobile/Media/Downloads" withIntermediateDirectories:YES attributes:nil error:nil];
    [fm removeItemAtPath:downloadsDir error:nil];
    [fm copyItemAtPath:dumpDir toPath:downloadsDir error:nil];

    ShowAlertOnScreen(@"IOS-Dumper", @"Дамп успешно завершен! Файлы сохранены в Downloads/Dump.");
    return nullptr;
}

__attribute__((constructor))
static void Entry() {
    // Игнорируем запуск внутри самого дампера и системных процессов
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleId isEqualToString:@"com.c4.iosdumperapp"] || [bundleId hasPrefix:@"com.apple."]) {
        return;
    }

    pthread_t t;
    pthread_create(&t, nullptr, WorkerThread, nullptr);
}
