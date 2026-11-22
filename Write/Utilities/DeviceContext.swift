import UIKit

@MainActor
enum DeviceContext {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
