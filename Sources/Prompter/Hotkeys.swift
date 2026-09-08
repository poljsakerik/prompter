import AppKit
import Carbon

/// Carbon hotkeys work while another app has focus, without Accessibility permission.
final class Hotkeys {
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    var onAction: ((UInt32) -> Void)?
    private(set) var failedIDs: [UInt32] = []

    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard result == noErr else { return result }
            Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue().onAction?(key.id)
            return noErr
        }, 1, &event, context, &handler)
        let keys: [(UInt32, Int)] = [(1, kVK_ANSI_P), (2, kVK_ANSI_R), (3, kVK_ANSI_J),
                                    (4, kVK_ANSI_O), (5, kVK_ANSI_Equal), (6, kVK_ANSI_Minus)]
        for (id, key) in keys {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(key), UInt32(optionKey | cmdKey),
                                             EventHotKeyID(signature: 0x50524D50, id: id),
                                             GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference { registrations.append(reference) }
            else { failedIDs.append(id) }
        }
    }

    deinit {
        registrations.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}
