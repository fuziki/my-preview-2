import SwiftUI

struct ToastItem {
    let id = UUID()
    let duration: TimeInterval
    let viewBuilder: () -> AnyView
}
