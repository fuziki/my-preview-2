import UIKit

enum ImageOrientation {
    case portrait, landscape
}

extension UIImage {
    var photoOrientation: ImageOrientation {
        size.width >= size.height ? .landscape : .portrait
    }
}
