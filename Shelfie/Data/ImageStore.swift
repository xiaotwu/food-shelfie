import Foundation
import UIKit

enum ImageStore {
    static func save(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let name = UUID().uuidString + ".jpg"
        let url = AppGroup.imagesDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        let url = AppGroup.imagesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func load(_ food: FoodItemRecord) -> UIImage? {
        if let data = food.photoData, let image = UIImage(data: data) {
            return image
        }
        return load(fileName: food.imageFileName)
    }

    static func assign(_ image: UIImage, to food: FoodItemRecord) {
        food.photoData = image.jpegData(compressionQuality: 0.82)
        food.imageFileName = save(image: image)
    }

    static func delete(fileName: String?) {
        guard let fileName else { return }
        let url = AppGroup.imagesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    static func copyIntoStore(from source: URL) -> String? {
        guard source.startAccessingSecurityScopedResource() || true else { return nil }
        defer { source.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: source), let image = UIImage(data: data) else {
            return nil
        }
        return save(image: image)
    }
}
