#import "ViewController.h"
#import <objc/runtime.h>

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)allInstalledApplications;
- (BOOL)openApplicationWithBundleID:(id)arg1;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"IOS-Dumper";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.installedApps = [NSMutableArray array];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    UIBarButtonItem *btnShare = [[UIBarButtonItem alloc] initWithTitle:@"Поделиться Дампом" style:UIBarButtonItemStylePlain target:self action:@selector(shareDumps)];
    self.navigationItem.rightBarButtonItem = btnShare;

    [self loadApplications];
}

- (void)loadApplications {
    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    if (!LSApplicationWorkspace_class) return;

    id workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    NSArray *apps = [workspace performSelector:@selector(allInstalledApplications)];

    for (id app in apps) {
        NSString *type = [app performSelector:@selector(bundleType)];
        if ([type isEqualToString:@"User"]) {
            NSString *bundleId = [app performSelector:@selector(applicationIdentifier)];
            NSString *name = [app performSelector:@selector(localizedName)];
            if (!name) name = [app performSelector:@selector(localizedShortName)];
            if (!name) name = bundleId;

            [self.installedApps addObject:@{@"name": name, @"bundleId": bundleId}];
        }
    }
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.installedApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"AppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    NSDictionary *info = self.installedApps[indexPath.row];
    cell.textLabel.text = info[@"name"];
    cell.detailTextLabel.text = info[@"bundleId"];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *info = self.installedApps[indexPath.row];
    NSString *bundleId = info[@"bundleId"];
    NSString *name = info[@"name"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Запуск & Дамп"
                                                                   message:[NSString stringWithFormat:@"Запустить %@? Подожди 5-10 секунд в игре, затем вернись сюда и нажми 'Поделиться Дампом'.", name]
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Дампить" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
        id workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
        [workspace performSelector:@selector(openApplicationWithBundleID:) withObject:bundleId];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shareDumps {
    NSMutableArray *itemsToShare = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    // Пути к дампам
    NSString *sharedDumpDir = @"/var/mobile/Media/Downloads/Dump";
    NSString *dumpCs = [sharedDumpDir stringByAppendingPathComponent:@"dump.cs"];
    NSString *scriptJson = [sharedDumpDir stringByAppendingPathComponent:@"script.json"];

    if ([fm fileExistsAtPath:dumpCs]) {
        [itemsToShare addObject:[NSURL fileURLWithPath:dumpCs]];
    }
    if ([fm fileExistsAtPath:scriptJson]) {
        [itemsToShare addObject:[NSURL fileURLWithPath:scriptJson]];
    }

    if (itemsToShare.count == 0) {
        UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"Дамп не найден"
                                                                         message:@"Сначала запусти игру на 5-10 секунд, чтобы создались файлы dump.cs и script.json."
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [errAlert addAction:[UIAlertAction actionWithTitle:@"ОК" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errAlert animated:YES completion:nil];
        return;
    }

    // Стандартное системное окно "Поделиться" (AirDrop, Telegram, Сохранить в Файлы)
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end
