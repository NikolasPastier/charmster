import Foundation

/// Lightweight analytics shim. Production will forward to a real provider.
/// Events buffered in-memory so the cancel/win-back + paywall funnels can be inspected.
enum Analytics {
    private static var buffer: [Event] = []

    struct Event: Hashable {
        let name: String
        let timestamp: Date
        let props: [String: String]
    }

    static func log(_ name: String, _ props: [String: Any] = [:]) {
        let stringProps = props.reduce(into: [String: String]()) { acc, kv in
            acc[kv.key] = String(describing: kv.value)
        }
        let ev = Event(name: name, timestamp: Date(), props: stringProps)
        buffer.append(ev)
        if buffer.count > 200 { buffer.removeFirst(buffer.count - 200) }
        #if DEBUG
        print("📊 \(name) \(stringProps)")
        #endif
    }

    static var recent: [Event] { buffer }
}
