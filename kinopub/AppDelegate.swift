import UIKit
import TVMLKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, TVApplicationControllerDelegate {

    var window: UIWindow?
    var appController: TVApplicationController?

    static let tvBaseURL = "https://atv4.service-kp.com"

    // #if RELEASE
    //     static let tvBaseURL = "https://atv4.service-kp.com"
    // #else
    //     static let tvBaseURL = "http://localhost:9001"
    // #endif

    static let tvBootURL = "\(AppDelegate.tvBaseURL)/application.js"

    // MARK: Javascript Execution Helper

    func executeRemoteMethod(_ methodName: String, completion: @escaping (Bool) -> Void) {
        appController?.evaluate(inJavaScriptContext: { (context: JSContext) in
            let appObject : JSValue = context.objectForKeyedSubscript("App")

            if appObject.hasProperty(methodName) {
                appObject.invokeMethod(methodName, withArguments: [])
            }
        }, completion: completion)
    }

    // MARK: UIApplicationDelegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        window = UIWindow(frame: UIScreen.main.bounds)

        // Create the TVApplicationControllerContext for this application and set the properties that will be passed to the `App.onLaunch` function in JavaScript.
        let appControllerContext = TVApplicationControllerContext()

        // The JavaScript URL is used to create the JavaScript context for your TVMLKit application. Although it is possible to separate your JavaScript into separate files, to help reduce the launch time of your application we recommend creating minified and compressed version of this resource. This will allow for the resource to be retrieved and UI presented to the user quickly.
        if let javaScriptURL = URL(string: AppDelegate.tvBootURL) {
            appControllerContext.javaScriptApplicationURL = javaScriptURL
        }

        appControllerContext.launchOptions["BASEURL"] = AppDelegate.tvBaseURL as NSString

        if let launchOptions = launchOptions {
            for (kind, value) in launchOptions {
                appControllerContext.launchOptions[kind.rawValue] = value
            }
        }

        appController = TVApplicationController(context: appControllerContext, window: window, delegate: self)

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and stop playback
        executeRemoteMethod("onWillResignActive", completion: { (success: Bool) in
            // ...
        })
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        executeRemoteMethod("onDidEnterBackground", completion: { (success: Bool) in
            // ...
        })
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        executeRemoteMethod("onWillEnterForeground", completion: { (success: Bool) in
            // ...
        })
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        executeRemoteMethod("onDidBecomeActive", completion: { (success: Bool) in
            // ...
        })
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        executeRemoteMethod("onWillTerminate", completion: { (success: Bool) in
            // ...
        })
    }

    // MARK: TVApplicationControllerDelegate

    func appController(_ appController: TVApplicationController, evaluateAppJavaScriptIn jsContext: JSContext){
        let defaults = UserDefaults(suiteName: "group.com.wielski.kinopub")
        
        let setData : @convention(block) (String, String) -> Void = {
            (key, value) -> Void in
            defaults?.set(value, forKey: key)
        }
        let getData : @convention(block) (String) -> String? = {
            (key) -> String? in
            return defaults?.string(forKey: key)
        }

        let tinyPlay : @convention(block) (String) -> Void = {
            (json) -> Void in
            self.tinyPlay(json: json)
        }

        // userDefaults mapping
        jsContext.setObject(unsafeBitCast(setData, to: AnyObject.self), forKeyedSubscript: "userDefaultsSetData" as (NSCopying & NSObjectProtocol))
        jsContext.setObject(unsafeBitCast(getData, to: AnyObject.self), forKeyedSubscript: "userDefaultsGetData" as (NSCopying & NSObjectProtocol))
        jsContext.evaluateScript("userDefaults = {setData: userDefaultsSetData, getData: userDefaultsGetData};")

        // tinyPlay player
        jsContext.setObject(unsafeBitCast(tinyPlay, to: AnyObject.self), forKeyedSubscript: "tinyPlay" as (NSCopying & NSObjectProtocol))
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        appController?.evaluate(inJavaScriptContext: { (context: JSContext) in
            let globalObject : JSValue = context.globalObject
            let url = URLComponents(string: url.absoluteString)
            let type = url?.queryItems?.first(where: { $0.name == "type" })?.value
            let id = url?.path.components(separatedBy: "/").last

            if globalObject.hasProperty("run") {
                globalObject.invokeMethod("run", withArguments: [id!, type!, "show"])
            } else {
                print("no openURLHandler in js global object")
            }
        })
        return true
    }

    func appController(_ appController: TVApplicationController, didFinishLaunching options: [String: Any]?) {
        print("\(#function) invoked with options: \(options ?? [:])")
    }

    func appController(_ appController: TVApplicationController, didFail error: Error) {
        print("\(#function) invoked with error: \(error)")

        let title = "Error Launching Application"
        let message = error.localizedDescription
        let alertController = UIAlertController(title: title, message: message, preferredStyle:.alert )

        self.appController?.navigationController.present(alertController, animated: true, completion: {
            // ...
        })
    }

    func appController(_ appController: TVApplicationController, didStop options: [String: Any]?) {
        print("\(#function) invoked with options: \(options ?? [:])")
    }

    func tinyPlay(json: String) {
        DispatchQueue.main.async {
            let jsonData = json.data(using: .utf8)
            do {
                let decoder = JSONDecoder()
                let mediaItems = try decoder.decode([MediaItem].self, from: jsonData!)
                
                if let firstMediaItem = mediaItems.first {
                    let player = VideoPlayerViewController()
                    player.mediaItem = firstMediaItem
                    self.appController?.navigationController.pushViewController(player, animated: true)
                }
            }
            catch {
                print(error)
            }
        }
    }
}
