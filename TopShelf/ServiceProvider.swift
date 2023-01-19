import Foundation
import TVServices

class ServiceProvider: NSObject, TVTopShelfProvider {

    override init() {
        super.init()
    }

    // MARK: - TVTopShelfProvider protocol

    var topShelfStyle: TVTopShelfContentStyle {
        // Return desired Top Shelf style.
        return .sectioned
    }

    var topShelfItems: [TVContentItem] {
        var SectionsItems = [TVContentItem]();

        do {
            if let userDefaults = UserDefaults(suiteName: "group.com.wielski.kinopub"),
                let topShelfString = userDefaults.string(forKey: "topshelf_url"),
                let topShelfData = topShelfString.data(using: String.Encoding.utf8, allowLossyConversion: false),
                let topShelf = try JSONSerialization.jsonObject(with: topShelfData) as? [String: Any] {

                for sectionData in topShelf["sections"] as! [[String: Any]] {
                    let sectionItem = TVContentItem(contentIdentifier: TVContentIdentifier(identifier: sectionData["contentIdentifier"] as! String, container: nil)!)

                    var sectionTopShelfItems = [TVContentItem]();
                    for itemData in sectionData["items"] as! [[String: Any]] {
                        let contentItem = TVContentItem(contentIdentifier: TVContentIdentifier(identifier: itemData["slug"] as! String, container: nil)!)

                        if let imageURLString = itemData["image"] as? String,
                            let imageURL = URL(string: imageURLString) {
                            if #available(tvOSApplicationExtension 11.0, *) {
                                contentItem!.setImageURL(imageURL, forTraits: .userInterfaceStyleLight)
                                contentItem!.setImageURL(imageURL, forTraits: .userInterfaceStyleDark)
                            } else {
                                contentItem!.imageURL = imageURL
                            }
                        }

                        if let displayURLString = itemData["slug"] as? String {
                           let displayURLComponents = displayURLString.components(separatedBy: ";")
                           if let displayURL = URL(string: "kinopub4atv://\(displayURLComponents[1])?type=\(displayURLComponents[0])") {
                               contentItem!.displayURL = displayURL;
                           }
                        }

                        contentItem!.imageShape = .poster
                        contentItem!.title = itemData["title"] as? String

                        sectionTopShelfItems.append(contentItem!)
                    }

                    sectionItem!.title = sectionData["title"] as? String

                    if sectionTopShelfItems.count > 0 {
                        sectionItem!.topShelfItems = sectionTopShelfItems
                        SectionsItems.append(sectionItem!)
                    }
                }
            }
        } catch {
            print("Error processing data: \(error)")
        }
        return SectionsItems
    }
}
