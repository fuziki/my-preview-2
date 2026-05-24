import UIKit

public enum ImageOrientation {
    case portrait, landscape
}

public extension UIImage {
    var photoOrientation: ImageOrientation {
        size.width >= size.height ? .landscape : .portrait
    }
}
