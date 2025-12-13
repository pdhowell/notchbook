import Foundation
import SwiftUI
import Combine
import AppKit

struct ShortcutItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var iconName: String // SF Symbol name
    var actionURL: String // URL scheme or command
    var actionType: ActionType = .urlScheme
    
    enum ActionType: String, Codable {
        case urlScheme
        case shellCommand
        case application
    }
}

class ShortcutManager: ObservableObject {
    @Published var shortcuts: [ShortcutItem] = []
    
    private let storageKey = "savedShortcuts"
    
    init() {
        loadShortcuts()

        // Add comprehensive default shortcuts if empty
        if shortcuts.isEmpty {
            // Default shortcuts: put the four primary shortcuts first so the UI shows
            // Finder, Safari, Screenshot and System Settings in the main view.
            shortcuts = [
                ShortcutItem(
                    name: "Finder",
                    iconName: "folder.fill",
                    actionURL: "Finder",
                    actionType: .application
                ),
                ShortcutItem(
                    name: "Safari",
                    iconName: "safari.fill",
                    actionURL: "Safari",
                    actionType: .application
                ),
                ShortcutItem(
                    name: "Screenshot",
                    iconName: "camera.viewfinder",
                    actionURL: "screencapture",
                    actionType: .application
                ),
                ShortcutItem(
                    name: "System Settings",
                    // Use the app's sparkles motif so the settings shortcut visually matches the app logo
                    iconName: "sparkles",
                    actionURL: "System Settings",
                    actionType: .application
                ),
                // Additional extras (kept for users who want more)
                ShortcutItem(
                    name: "Calendar",
                    iconName: "calendar",
                    actionURL: "Calendar",
                    actionType: .application
                ),
                ShortcutItem(
                    name: "Notes",
                    iconName: "note.text",
                    actionURL: "Notes",
                    actionType: .application
                )
            ]
            saveShortcuts()
        } else {
            // If user has previously saved shortcuts but System Settings is missing,
            // insert it as the 4th shortcut so the UI (which shows the first 4)
            // will include it by default without overwriting the user's list.
            if !shortcuts.contains(where: { $0.name == "System Settings" }) {
                let systemSettings = ShortcutItem(
                    name: "System Settings",
                    iconName: "sparkles",
                    actionURL: "System Settings",
                    actionType: .application
                )
                let insertIndex = min(3, shortcuts.count)
                shortcuts.insert(systemSettings, at: insertIndex)
                saveShortcuts()
            }
        }
    }
    
    func run(_ item: ShortcutItem) {
        switch item.actionType {
        case .urlScheme:
            runURLScheme(item.actionURL)
        case .shellCommand:
            runShellCommand(item.actionURL)
        case .application:
            openApplication(item.actionURL)
        }
    }
    
    private func runURLScheme(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func runShellCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
        } catch {
            print("Failed to run command: \(error.localizedDescription)")
        }
    }
    
    private func openApplication(_ appName: String) {
        // Special handling for screenshot
        if appName.lowercased() == "screencapture" {
            // Trigger screenshot using keyboard shortcut simulation
            runShellCommand("screencapture -i -c")
            return
        }
        
        // Try to open by name
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: getBundleIdentifier(for: appName)) {
            NSWorkspace.shared.open(appURL)
        } else {
            // Fallback: try opening by name
            let workspace = NSWorkspace.shared
            let apps = workspace.runningApplications
            
            // Check if already running
            if let runningApp = apps.first(where: { $0.localizedName == appName }) {
                // activateIgnoringOtherApps is deprecated; activating with empty options
                // is sufficient and future-proof.
                runningApp.activate(options: [])
            } else {
                // Try to launch using modern API. Prefer resolving the full path
                // first, falling back to opening the application bundle URL.
                if let path = workspace.fullPath(forApplication: appName) {
                    let appURL = URL(fileURLWithPath: path)
                    let config = NSWorkspace.OpenConfiguration()
                    workspace.openApplication(at: appURL, configuration: config, completionHandler: nil)
                } else if let appURL = workspace.urlForApplication(withBundleIdentifier: getBundleIdentifier(for: appName)),
                          FileManager.default.fileExists(atPath: appURL.path) {
                    let config = NSWorkspace.OpenConfiguration()
                    workspace.openApplication(at: appURL, configuration: config, completionHandler: nil)
                } else {
                    // Last resort: try the old helper which may still work on some systems.
                    workspace.launchApplication(appName)
                }
            }
        }
    }
    
    private func getBundleIdentifier(for appName: String) -> String {
        let identifiers: [String: String] = [
            "Finder": "com.apple.finder",
            "Safari": "com.apple.Safari",
            "Calendar": "com.apple.iCal",
            "Notes": "com.apple.Notes",
            "Music": "com.apple.Music",
            "Mail": "com.apple.mail",
            "Messages": "com.apple.MobileSMS",
            "FaceTime": "com.apple.FaceTime",
            "Photos": "com.apple.Photos",
            "System Settings": "com.apple.systempreferences",
            "Reminders": "com.apple.reminders",
            "Contacts": "com.apple.AddressBook",
            "Maps": "com.apple.Maps"
        ]
        
        return identifiers[appName] ?? ""
    }
    
    func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ShortcutItem].self, from: data) {
            self.shortcuts = decoded
        }
    }
    
    func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func addShortcut(name: String, icon: String, command: String, type: ShortcutItem.ActionType = .urlScheme) {
        let newItem = ShortcutItem(
            name: name,
            iconName: icon,
            actionURL: command,
            actionType: type
        )
        shortcuts.append(newItem)
        saveShortcuts()
    }
    
    func removeShortcut(at index: Int) {
        guard index < shortcuts.count else { return }
        shortcuts.remove(at: index)
        saveShortcuts()
    }
    
    func moveShortcut(from source: IndexSet, to destination: Int) {
        shortcuts.move(fromOffsets: source, toOffset: destination)
        saveShortcuts()
    }
}
