import SwiftUI
import UIKit
import AVKit
import AVFoundation

struct MediaItem: Decodable {
    var id: Int?
    var imdb: Int?
    var title: String?
    var desc: String?
    var poster: String?
    var url: String
    var video: Int?
    var season: Int?
    var subTitle: String?
    var watchingTime: Int?
    var rating: String?
}

final class VideoPlayerViewController: UIViewController {
    // MARK: - Properties
    var mediaItem: MediaItem?
    var timer = Timer()
    var debugInfoLabel = UILabel(frame: CGRectMake(5, 100, 200, 50 ))

    fileprivate weak var avPlayerViewController: AVPlayerViewController?

    var speedRate: Float = 1.0 {
        didSet {
            avPlayerViewController?.player?.rate = speedRate
            renderCustomActions()
        }
    }

    var debugInfo: Bool = false {
        didSet {
            renderCustomActions()
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setVideoPlayer()

        // Timer to show debug info
        self.timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { _ in
            self.tryToShowDebugInfo()
        })

        // Init debug info label
        debugInfoLabel.textAlignment = NSTextAlignment.center
        debugInfoLabel.text = ""
        debugInfoLabel.layer.zPosition = 1
        debugInfoLabel.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        avPlayerViewController?.player?.pause()
    }
}


// TinyPlayer -> VideoPlayerViewController Extension
typealias TinyPlayer = VideoPlayerViewController
extension TinyPlayer {
    /// set video player for view
    func setVideoPlayer() {
        let metadata = Metadata(
            title: mediaItem?.title,
            subtitle: mediaItem?.subTitle,
            image: mediaItem?.poster,
            description: mediaItem?.desc,
            rating: mediaItem?.rating
        )

        // AVPlayer Instance
        let avPlayerViewController = AVPlayerViewController()
        avPlayerViewController.player = AVPlayer(url: URL(string: mediaItem!.url)!)
        avPlayerViewController.player?.currentItem?.externalMetadata = createMetadataItems(for: metadata)
        avPlayerViewController.view.frame = self.view.bounds
        pullImageArtwork(metadata: metadata, player: avPlayerViewController.player!)

        // Open player
        self.avPlayerViewController = avPlayerViewController
        
        self.avPlayerViewController!.view.frame = self.view.bounds
        self.view.addSubview(self.avPlayerViewController!.view)
        self.addChildViewController(self.avPlayerViewController!)

        self.avPlayerViewController?.player?.play()

        renderCustomActions()
    }

    func renderCustomActions() {
        if #available(tvOS 15, *) {
            // Custom actions
            let speedImage = UIImage(systemName: "speedometer")
            let gearImage = UIImage(systemName: "gearshape")

            let speedActionValues: KeyValuePairs = ["0.5x": 0.5, "0.75x": 0.75, "1x": 1.0, "1.25x": 1.25, "1.5x": 1.5, "2x": 2.0]
            let speedActions = speedActionValues.map { title, value in
                UIAction(title: title, state: speedRate == Float(value) ? .on : .off) { [weak self] action in
                    // Update the current playback speed.
                    self?.speedRate = Float(value)
                    action.state = .on
                }
            }

            // Create the speed menu
            let speedMenu = UIMenu(title: "Скорость",
                                   image: speedImage,
                                   children: speedActions)

            let debugInfoAction = UIAction(title: "Информация о потоке", state: debugInfo ? .on : .off) {[weak self] action in
                self?.debugInfo = !self!.debugInfo
                action.state = self!.debugInfo ? .off : .on
            }

            // Create the settings menu.
            let settingsMenu = UIMenu(title: "Настройки", image: gearImage, children: [debugInfoAction])

            // Set menu options
            avPlayerViewController?.transportBarCustomMenuItems = [speedMenu, settingsMenu]
        }
    }

    func sourceInfo() async -> String? {
        var videoResolution = ""
        if let size = avPlayerViewController?.player?.currentItem?.presentationSize {
            videoResolution = "\(String(format: "%.0f", size.width))x\(String(format: "%.0f", size.height))"
        }

        var fps: Float = 0.0;
        var videoCodec = "unknown"
        if #available(tvOS 15, *) {
            do {
                if let playerAsset = avPlayerViewController?.player?.currentItem?.asset {
                    let tracks = try await playerAsset.load(.tracks)
                    let videos = tracks.filter({
                        return $0.mediaType == AVMediaType.video
                    })
                    let firstVideo = videos.first!
                    fps = firstVideo.nominalFrameRate
                }
            } catch {
                // Could not get fps, ignore
            }
        } else {
            // No fallback on earlier versions
        }

        if let logEvent = avPlayerViewController?.player?.currentItem?.accessLog()?.events.last {
            return """
            VIDEO: \(videoCodec) \(videoResolution) \(fps)fps (b: \(logEvent.segmentsDownloadedDuration), i: \(logEvent.indicatedBitrate), a: \(logEvent.averageVideoBitrate), o: \(logEvent.observedBitrate))
            AUDIO: hhz 999ch (hz productions) (a: \(logEvent.averageAudioBitrate))
            """
        }

        return nil
    }

    func tryToShowDebugInfo() {
        if !debugInfo {
            debugInfoLabel.text = "BLAH BLAH BLAH"
            debugInfoLabel.isHidden = false
            return
        }

        if #available(tvOS 13.0, *) {
            Task {
//                let sourceInfoString = await sourceInfo()
                debugInfoLabel.text = "blah"
                debugInfoLabel.isHidden = false
            }
        } else {
            // No fallback on earlier versions
        }
    }
}

struct Metadata {
    var title: String?
    var subtitle: String?
    var image: String?
    var description: String?
    var rating: String?
}

func createMetadataItems(for metadata: Metadata) -> [AVMetadataItem] {
    var metaDataItems = [AVMetadataItem]()

    if let title = metadata.title {
        let titleItem = createMetadataItem(.commonIdentifierTitle, value: title)
        metaDataItems.append(titleItem)
    }

    if let subtitle = metadata.subtitle {
        let subtitleItem = createMetadataItem(.iTunesMetadataTrackSubTitle, value: subtitle)
        metaDataItems.append(subtitleItem)
    }

    if let description = metadata.description {
        let descriptionItem = createMetadataItem(.commonIdentifierDescription, value: description)
        metaDataItems.append(descriptionItem)
    }

//    let genreItem = createMetadataItem(.quickTimeMetadataGenre, value: "Movie / TVShow")
//    metaDataItems.append(genreItem)

    return metaDataItems
}

func pullImageArtwork(metadata: Metadata, player: AVPlayer) {
    if let string = metadata.image,
        let url = URL(string: string) {
        if #available(tvOS 13.0, *) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    let image = createMetadataItem(.commonIdentifierArtwork, value: data as NSData)
                    player.currentItem?.externalMetadata.append(image)
                }
            }
        } else {
            // No fallback on earlier versions
        }
    }
}

private func createMetadataItem(_ identifier: AVMetadataIdentifier,
                                value: Any) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value as? NSCopying & NSObjectProtocol
    // Specify "und" to indicate an undefined language.
    item.extendedLanguageTag = "und"
    return item.copy() as! AVMetadataItem
}
