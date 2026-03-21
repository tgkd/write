import UIKit

enum DeviceContext {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
