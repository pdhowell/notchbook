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
            shortcuts = [
                ShortcutItem(
                    name: "Screenshot",
                    iconName: "camera.viewfinder",
                    actionURL: "screencapture",
                    actionType: .application
                ),
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
                ),
                ShortcutItem(
                    name: "System Settings",
                    iconName: "gearshape.2.fill",
                    actionURL: "System Settings",
                    actionType: .application
                )
            ]
            saveShortcuts()
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
                runningApp.activate(options: .activateIgnoringOtherApps)
            } else {
                // Try to launch
                workspace.launchApplication(appName)
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
