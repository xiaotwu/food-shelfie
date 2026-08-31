import Foundation

enum AppGroup {
    static let identifier = "group.com.xiaotwu.shelfie"
    static let storeFileName = "Shelfie.sqlite"
    static let imagesDirectoryName = "FoodImages"
    static let snapshotFileName = "widget-snapshot.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var storeURL: URL {
        let base = containerURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(storeFileName)
    }

    static var imagesDirectory: URL {
        let base = (containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
            .appendingPathComponent(imagesDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var snapshotURL: URL {
        let base = containerURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(snapshotFileName)
    }
}
