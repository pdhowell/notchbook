//import SwiftUI
//import UniformTypeIdentifiers
//import AVFoundation
//import AppKit
//import Combine
//
//// MARK: - MAIN VIEW
//struct ContentView: View {
//    @StateObject private var mediaManager = MediaManager()
//    @StateObject private var cameraManager = CameraManager()
//    @StateObject private var shortcutManager = ShortcutManager()
//    
//    // --- SETTINGS ---
//    @AppStorage("notchWidth") private var notchWidth: Double = 700
//    @AppStorage("notchHeight") private var notchHeight: Double = 240
//    @AppStorage("showMirror") private var showMirror = true
//    
//    // --- STATE ---
//    @State private var isHovering = false
//    @State private var activeTab: Tab = .nook
//    @State private var storedFiles: [StoredFile] = []
//    @State private var isDropTargeted = false
//    @State private var showSettings = false
//    
//    enum Tab { case nook, tray }
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack(alignment: .top) {
//                // MAIN NOTCH INTERFACE
//                VStack(spacing: 0) {
//                    notchContent
//                        .frame(
//                            width: isHovering ? CGFloat(notchWidth) : 180,
//                            height: isHovering ? CGFloat(notchHeight) : 32
//                        )
//                        .fixedSize()
//                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovering)
//                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeTab)
//                    
//                    Spacer()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//                
//                // SETTINGS PANEL
//                if showSettings {
//                    Color.clear
//                        .contentShape(Rectangle())
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        .onTapGesture { withAnimation { showSettings = false } }
//                        
//                    SettingsView(
//                        notchWidth: $notchWidth,
//                        notchHeight: $notchHeight,
//                        showMirror: $showMirror,
//                        isPresented: $showSettings,
//                        cameraManager: cameraManager
//                    )
//                    .frame(width: 400, height: 450)
//                    .background(
//                        RoundedRectangle(cornerRadius: 20)
//                            .fill(Color(NSColor.windowBackgroundColor))
//                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
//                    )
//                    .padding(.top, 120)
//                    .transition(.move(edge: .top).combined(with: .opacity))
//                    .zIndex(2)
//                }
//            }
//        }
//        .onChange(of: showMirror) { newValue in
//            if !newValue {
//                cameraManager.stop()
//            } else if isHovering && activeTab == .nook {
//                cameraManager.start()
//            }
//        }
//    }
//    
//    var notchContent: some View {
//        ZStack(alignment: .top) {
//            // BACKGROUND
//            RoundedRectangle(cornerRadius: isHovering ? 28 : 16, style: .continuous)
//                .fill(
//                    LinearGradient(
//                        gradient: Gradient(colors: [Color.black.opacity(0.95), Color.black.opacity(0.98)]),
//                        startPoint: .top, endPoint: .bottom
//                    )
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: isHovering ? 28 : 16, style: .continuous)
//                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
//                )
//                .shadow(color: .black.opacity(0.7), radius: 20, x: 0, y: 10)
//            
//            // CONTENT
//            VStack(spacing: 0) {
//                if isHovering {
//                    headerView
//                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
//                    
//                    if activeTab == .nook {
//                        nookDashboardView
//                            .transition(.asymmetric(
//                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
//                                removal: .opacity
//                            ))
//                    } else {
//                        fileShelfView
//                            .transition(.asymmetric(
//                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
//                                removal: .opacity
//                            ))
//                    }
//                } else {
//                    collapsedStateView
//                        .transition(.opacity)
//                }
//            }
//            .clipped()
//        }
//        .onHover { hovering in
//            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
//                isHovering = hovering
//            }
//            
//            if hovering && activeTab == .nook && showMirror {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    cameraManager.start()
//                }
//            } else {
//                cameraManager.stop()
//            }
//        }
//        .onChange(of: isHovering) { newValue in
//            // When collapsed (isHovering == false) instruct the panel to ignore mouse events
//            // But keep the panel interactive if settings are visible.
//            let ignore = !(newValue || showSettings)
//            NotificationCenter.default.post(name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil, userInfo: ["ignore": ignore])
//        }
//
//        .onChange(of: showSettings) { newValue in
//            // Ensure the panel accepts mouse events while settings are shown so the settings UI is usable.
//            let ignore = !(isHovering || newValue)
//            NotificationCenter.default.post(name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil, userInfo: ["ignore": ignore])
//        }
//        
//        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
//                    // Ensure mouse events are enabled during drop
//                    NotificationCenter.default.post(name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil, userInfo: ["ignore": false])
//                    
//                    withAnimation {
//                        activeTab = .tray
//                        isHovering = true
//                    }
//                    handleDrop(providers: providers)
//                    return true
//                }    }
//    
//    // MARK: - SUBVIEWS
//    
//    var headerView: some View {
//        HStack(spacing: 15) {
//            Button(action: { withAnimation { activeTab = .nook } }) {
//                HStack(spacing: 6) {
//                    Image(systemName: "sparkles")
//                        .font(.system(size: 13, weight: .semibold))
//                    Text("Nook")
//                        .font(.system(size: 13, weight: .semibold))
//                }
//                .foregroundColor(activeTab == .nook ? .white : .gray)
//                .padding(.vertical, 8)
//                .padding(.horizontal, 14)
//                .background(
//                    Capsule()
//                        .fill(activeTab == .nook ? Color.white.opacity(0.15) : Color.clear)
//                )
//            }
//            .buttonStyle(PlainButtonStyle())
//            
//            Button(action: { withAnimation { activeTab = .tray } }) {
//                HStack(spacing: 6) {
//                    Image(systemName: "tray.2.fill")
//                        .font(.system(size: 13, weight: .semibold))
//                    Text("Tray")
//                        .font(.system(size: 13, weight: .semibold))
//                }
//                .foregroundColor(activeTab == .tray ? .white : .gray)
//                .padding(.vertical, 8)
//                .padding(.horizontal, 14)
//                .background(
//                    Capsule()
//                        .fill(activeTab == .tray ? Color.white.opacity(0.15) : Color.clear)
//                )
//            }
//            .buttonStyle(PlainButtonStyle())
//            
//            Spacer()
//            
//            Button(action: { withAnimation { showSettings.toggle() } }) {
//                Image(systemName: "gearshape.fill")
//                    .font(.system(size: 15))
//                    .foregroundColor(.gray)
//                    .padding(8)
//                    .background(Circle().fill(Color.white.opacity(0.1)))
//            }
//            .buttonStyle(PlainButtonStyle())
//        }
//        .padding(.horizontal, 20)
//        .padding(.top, 16)
//        .padding(.bottom, 12)
//    }
//    
//    var nookDashboardView: some View {
//        HStack(spacing: 14) {
//            // MEDIA PLAYER
//            VStack(alignment: .leading, spacing: 10) {
//                HStack(spacing: 12) {
//                    if let art = mediaManager.albumArt {
//                        Image(nsImage: art)
//                            .resizable()
//                            .aspectRatio(contentMode: .fill)
//                            .frame(width: 60, height: 60)
//                            .cornerRadius(12)
//                            .shadow(color: .black.opacity(0.3), radius: 5)
//                    } else {
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(
//                                LinearGradient(
//                                    gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
//                                    startPoint: .topLeading,
//                                    endPoint: .bottomTrailing
//                                )
//                            )
//                            .frame(width: 60, height: 60)
//                            .overlay(
//                                Image(systemName: "music.note")
//                                    .font(.title2)
//                                    .foregroundColor(.white.opacity(0.6))
//                            )
//                    }
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text(mediaManager.trackTitle)
//                            .font(.system(size: 14, weight: .bold))
//                            .lineLimit(1)
//                            .foregroundColor(.white)
//                        Text(mediaManager.artistName)
//                            .font(.system(size: 12))
//                            .foregroundColor(.gray)
//                            .lineLimit(1)
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                }
//                
//                HStack(spacing: 25) {
//                    Button(action: mediaManager.previousTrack) {
//                        Image(systemName: "backward.fill")
//                            .font(.system(size: 16))
//                    }
//                    Button(action: mediaManager.togglePlayPause) {
//                        Image(systemName: mediaManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
//                            .font(.system(size: 28))
//                    }
//                    Button(action: mediaManager.nextTrack) {
//                        Image(systemName: "forward.fill")
//                            .font(.system(size: 16))
//                    }
//                }
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity)
//            }
//            .padding(16)
//            .frame(maxWidth: .infinity)
//            .background(
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(Color.white.opacity(0.08))
//            )
//            
//            // SHORTCUTS
//            VStack(spacing: 10) {
//                ForEach(shortcutManager.shortcuts.prefix(3)) { shortcut in
//                    Button(action: { shortcutManager.run(shortcut) }) {
//                        HStack(spacing: 10) {
//                            Image(systemName: shortcut.iconName)
//                                .font(.system(size: 14, weight: .semibold))
//                                .foregroundColor(.cyan)
//                                .frame(width: 20)
//                            Text(shortcut.name)
//                                .font(.system(size: 13, weight: .medium))
//                                .foregroundColor(.white)
//                            Spacer()
//                        }
//                        .padding(.horizontal, 14)
//                        .padding(.vertical, 12)
//                        .background(
//                            RoundedRectangle(cornerRadius: 12)
//                                .fill(Color.white.opacity(0.08))
//                        )
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//            }
//            .frame(width: 180)
//            
//            // CAMERA MIRROR
//            if showMirror {
//                ZStack {
//                    if cameraManager.isAuthorized {
//                        CameraPreviewView(cameraManager: cameraManager)
//                            .aspectRatio(contentMode: .fill)
//                            .frame(width: 100, height: 100)
//                            .clipShape(Circle())
//                            .overlay(
//                                Circle()
//                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
//                            )
//                            .shadow(color: .black.opacity(0.3), radius: 10)
//                    } else {
//                        Button(action: {
//                            // Check if we need to request or if it's been denied
//                            let status = AVCaptureDevice.authorizationStatus(for: .video)
//                            if status == .notDetermined {
//                                cameraManager.requestPermission()
//                            } else {
//                                cameraManager.openSystemPreferences()
//                            }
//                        }) {
//                            Circle()
//                                .fill(Color.white.opacity(0.08))
//                                .frame(width: 100, height: 100)
//                                .overlay(
//                                    VStack(spacing: 4) {
//                                        Image(systemName: "video.slash")
//                                            .font(.title2)
//                                            .foregroundColor(.gray)
//                                        Text(AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined ? "Enable" : "Settings")
//                                            .font(.caption2)
//                                            .foregroundColor(.cyan)
//                                    }
//                                )
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                    }
//                }
//            }
//        }
//        .padding(.horizontal, 20)
//        .padding(.bottom, 20)
//    }
//    
//    var fileShelfView: some View {
//        VStack(spacing: 12) {
//            if storedFiles.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down.fill")
//                        .font(.system(size: 40))
//                        .foregroundColor(isDropTargeted ? .cyan : .gray)
//                        .animation(.spring(response: 0.3), value: isDropTargeted)
//                    Text(isDropTargeted ? "Release to add files" : "Drag files here to store them")
//                        .font(.system(size: 14))
//                        .foregroundColor(.gray)
//                        .multilineTextAlignment(.center)
//                }
//                .frame(maxHeight: .infinity)
//            } else {
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack(spacing: 16) {
//                        ForEach(storedFiles) { file in
//                            FileItemView(file: file) {
//                                removeFile(file)
//                            }
//                        }
//                    }
//                    .padding(.horizontal, 20)
//                    .padding(.vertical, 10)
//                }
//            }
//        }
//        .padding(.bottom, 20)
//        .frame(maxHeight: .infinity)
//    }
//    
//    var collapsedStateView: some View {
//        HStack(spacing: 6) {
//            Circle()
//                .fill(Color.white.opacity(0.3))
//                .frame(width: 5, height: 5)
//            Circle()
//                .fill(Color.white.opacity(0.2))
//                .frame(width: 4, height: 4)
//            Circle()
//                .fill(Color.white.opacity(0.15))
//                .frame(width: 3, height: 3)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//    
//    // --- LOGIC ---
//    func handleDrop(providers: [NSItemProvider]) {
//        for provider in providers {
//            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
//                DispatchQueue.main.async {
//                    if let urlData = urlData as? Data,
//                       let url = URL(dataRepresentation: urlData, relativeTo: nil),
//                       !storedFiles.contains(where: { $0.url == url }) {
//                        withAnimation(.spring(response: 0.3)) {
//                            storedFiles.append(StoredFile(url: url))
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    func removeFile(_ file: StoredFile) {
//        withAnimation(.spring(response: 0.3)) {
//            storedFiles.removeAll { $0.id == file.id }
//        }
//    }
//}
//
//// MARK: - SETTINGS VIEW
//struct SettingsView: View {
//    @Binding var notchWidth: Double
//    @Binding var notchHeight: Double
//    @Binding var showMirror: Bool
//    @Binding var isPresented: Bool
//    @ObservedObject var cameraManager: CameraManager
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 20) {
//            HStack {
//                Text("Settings")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                Spacer()
//                Button(action: { withAnimation { isPresented = false } }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title3)
//                        .foregroundColor(.secondary)
//                }
//                .buttonStyle(PlainButtonStyle())
//            }
//            .padding(.bottom, 10)
//            
//            Divider()
//            
//            VStack(alignment: .leading, spacing: 15) {
//                Text("Appearance")
//                    .font(.headline)
//                
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Width: \(Int(notchWidth))px")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                    Slider(value: $notchWidth, in: 500...900, step: 10)
//                }
//                
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Height: \(Int(notchHeight))px")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                    Slider(value: $notchHeight, in: 180...300, step: 10)
//                }
//            }
//            
//            Divider()
//            
//            VStack(alignment: .leading, spacing: 15) {
//                Text("Features")
//                    .font(.headline)
//                
//                HStack {
//                    Toggle("Show Camera Mirror", isOn: $showMirror)
//                    
//                    if !cameraManager.isAuthorized && showMirror {
//                        Button("Open Settings") {
//                            cameraManager.openSystemPreferences()
//                        }
//                        .buttonStyle(.borderedProminent)
//                        .controlSize(.small)
//                    }
//                }
//                
//                if !cameraManager.isAuthorized && showMirror {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("⚠️ Camera access required")
//                            .font(.caption)
//                            .foregroundColor(.orange)
//                        Text("Click 'Open Settings' → Find your app → Enable camera → Restart app")
//                            .font(.caption2)
//                            .foregroundColor(.secondary)
//                    }
//                    .padding(.leading, 4)
//                }
//            }
//            
//            Spacer()
//            
//            Text("Made with ♥ for macOS")
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .frame(maxWidth: .infinity, alignment: .center)
//        }
//        .padding(30)
//    }
//}
//
//// MARK: - CAMERA MANAGER CLASS
//class CameraManager: NSObject, ObservableObject {
//    @Published var session = AVCaptureSession()
//    @Published var isAuthorized = false
//    
//    override init() {
//        super.init()
//        checkPermissions()
//    }
//    
//    func checkPermissions() {
//        switch AVCaptureDevice.authorizationStatus(for: .video) {
//        case .authorized:
//            DispatchQueue.main.async {
//                self.isAuthorized = true
//            }
//            setupSession()
//        case .notDetermined:
//            // Don't request automatically
//            DispatchQueue.main.async {
//                self.isAuthorized = false
//            }
//        case .denied, .restricted:
//            DispatchQueue.main.async {
//                self.isAuthorized = false
//            }
//        @unknown default:
//            DispatchQueue.main.async {
//                self.isAuthorized = false
//            }
//        }
//    }
//    
//    func requestPermission() {
//        AVCaptureDevice.requestAccess(for: .video) { granted in
//            DispatchQueue.main.async {
//                self.isAuthorized = granted
//                if granted {
//                    self.setupSession()
//                    self.start()
//                }
//            }
//        }
//    }
//    
//    func openSystemPreferences() {
//        // Open System Settings to Camera privacy
//        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
//        NSWorkspace.shared.open(url)
//        
//        // Show alert with instructions
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            let alert = NSAlert()
//            alert.messageText = "Enable Camera Access"
//            alert.informativeText = "In System Settings:\n1. Find your app in the list\n2. Toggle the switch to ON\n3. Restart the app"
//            alert.alertStyle = .informational
//            alert.addButton(withTitle: "OK")
//            alert.runModal()
//        }
//    }
//    
//    func setupSession() {
//        guard !session.isRunning else { return }
//        
//        session.beginConfiguration()
//        
//        // Remove existing inputs
//        session.inputs.forEach { session.removeInput($0) }
//        
//        guard let device = AVCaptureDevice.default(for: .video),
//              let input = try? AVCaptureDeviceInput(device: device) else {
//            session.commitConfiguration()
//            return
//        }
//        
//        if session.canAddInput(input) {
//            session.addInput(input)
//        }
//        
//        session.commitConfiguration()
//    }
//    
//    func start() {
//        guard isAuthorized, !session.isRunning else { return }
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            self?.session.startRunning()
//        }
//    }
//    
//    func stop() {
//        guard session.isRunning else { return }
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            self?.session.stopRunning()
//        }
//    }
//}
//
//// MARK: - MEDIA MANAGER CLASS
//class MediaManager: ObservableObject {
//    @Published var trackTitle: String = "Not Playing"
//    @Published var artistName: String = "No media active"
//    @Published var isPlaying: Bool = false
//    @Published var albumArt: NSImage? = nil
//    @Published var appName: String = "Music"
//    
//    private var timer: Timer?
//    
//    init() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            self.startListening()
//        }
//    }
//    
//    deinit {
//        timer?.invalidate()
//    }
//    
//    func startListening() {
//        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
//            self?.fetchTrackInfo()
//        }
//        fetchTrackInfo()
//    }
//    
//    func fetchTrackInfo() {
//        DispatchQueue.global(qos: .background).async { [weak self] in
//            guard let self = self else { return }
//            
//            let spotifyScript = """
//            tell application "Spotify"
//                if it is running then
//                    return {player state as string, name of current track, artist of current track, artwork url of current track}
//                end if
//            end tell
//            """
//            
//            let musicScript = """
//            tell application "Music"
//                if it is running then
//                    return {player state as string, name of current track, artist of current track}
//                end if
//            end tell
//            """
//            
//            if let result = self.runAppleScript(spotifyScript) {
//                self.appName = "Spotify"
//                self.parseSpotify(result)
//            } else if let result = self.runAppleScript(musicScript) {
//                self.appName = "Music"
//                self.parseMusic(result)
//            } else {
//                DispatchQueue.main.async {
//                    self.isPlaying = false
//                    self.trackTitle = "Not Playing"
//                    self.artistName = "No media active"
//                    self.albumArt = nil
//                }
//            }
//        }
//    }
//    
//    func togglePlayPause() {
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            guard let self = self else { return }
//            _ = self.runAppleScript("tell application \"\(self.appName)\" to playpause")
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                self.fetchTrackInfo()
//            }
//        }
//    }
//    
//    func nextTrack() {
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            guard let self = self else { return }
//            _ = self.runAppleScript("tell application \"\(self.appName)\" to next track")
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                self.fetchTrackInfo()
//            }
//        }
//    }
//    
//    func previousTrack() {
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            guard let self = self else { return }
//            _ = self.runAppleScript("tell application \"\(self.appName)\" to previous track")
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                self.fetchTrackInfo()
//            }
//        }
//    }
//    
//    private func runAppleScript(_ source: String) -> String? {
//        var error: NSDictionary?
//        guard let scriptObject = NSAppleScript(source: source) else { return nil }
//        
//        let output = scriptObject.executeAndReturnError(&error)
//        if error == nil {
//            if output.descriptorType == typeAEList {
//                var results: [String] = []
//                for i in 1...output.numberOfItems {
//                    if let item = output.atIndex(i)?.stringValue {
//                        results.append(item)
//                    }
//                }
//                return results.joined(separator: "|||")
//            }
//            return output.stringValue
//        }
//        return nil
//    }
//    
//    private func parseSpotify(_ result: String) {
//        let components = result.components(separatedBy: "|||")
//        guard components.count >= 3 else { return }
//        
//        DispatchQueue.main.async {
//            self.isPlaying = (components[0] == "playing")
//            self.trackTitle = components[1]
//            self.artistName = components[2]
//            
//            if components.count >= 4, let url = URL(string: components[3]) {
//                self.downloadArtwork(from: url)
//            }
//        }
//    }
//    
//    private func parseMusic(_ result: String) {
//        let components = result.components(separatedBy: "|||")
//        guard components.count >= 3 else { return }
//        
//        DispatchQueue.main.async {
//            self.isPlaying = (components[0] == "playing")
//            self.trackTitle = components[1]
//            self.artistName = components[2]
//            self.albumArt = nil
//        }
//    }
//    
//    private func downloadArtwork(from url: URL) {
//        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
//            if let data = data, let image = NSImage(data: data) {
//                DispatchQueue.main.async {
//                    self?.albumArt = image
//                }
//            }
//        }.resume()
//    }
//}
//
//// MARK: - HELPERS
//struct StoredFile: Identifiable {
//    let id = UUID()
//    let url: URL
//    let name: String
//    let icon: NSImage
//    let fileSize: String
//    
//    init(url: URL) {
//        self.url = url
//        self.name = url.lastPathComponent
//        self.icon = NSWorkspace.shared.icon(forFile: url.path)
//        
//        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
//           let size = attr[.size] as? Int64 {
//            self.fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
//        } else {
//            self.fileSize = "Unknown"
//        }
//    }
//}
//
//struct FileItemView: View {
//    let file: StoredFile
//    let onRemove: () -> Void
//    @State private var isHoveringFile = false
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            ZStack(alignment: .topTrailing) {
//                Image(nsImage: file.icon)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 50, height: 50)
//                
//                if isHoveringFile {
//                    Button(action: onRemove) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.system(size: 18))
//                            .foregroundColor(.white)
//                            .background(Circle().fill(Color.red))
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                    .offset(x: 8, y: -8)
//                    .transition(.scale.combined(with: .opacity))
//                }
//            }
//            
//            VStack(spacing: 2) {
//                Text(file.name)
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(.white)
//                    .lineLimit(2)
//                    .multilineTextAlignment(.center)
//                    .frame(width: 80)
//                
//                Text(file.fileSize)
//                    .font(.system(size: 9))
//                    .foregroundColor(.gray)
//            }
//        }
//        .padding(12)
//        .background(
//            RoundedRectangle(cornerRadius: 14)
//                .fill(Color.white.opacity(isHoveringFile ? 0.12 : 0.06))
//        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 14)
//                .stroke(Color.white.opacity(isHoveringFile ? 0.2 : 0), lineWidth: 1)
//        )
//        .animation(.spring(response: 0.3), value: isHoveringFile)
//        .onHover { isHoveringFile = $0 }
//        .onDrag {
//            NSItemProvider(object: file.url as NSURL)
//        }
//    }
//}
//
//struct CameraPreviewView: NSViewRepresentable {
//    @ObservedObject var cameraManager: CameraManager
//    
//    func makeNSView(context: Context) -> NSView {
//        let view = NSView()
//        view.wantsLayer = true
//        
//        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
//        previewLayer.videoGravity = .resizeAspectFill
//        previewLayer.connection?.isVideoMirrored = true
//        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
//        
//        view.layer = previewLayer
//        return view
//    }
//    
//    func updateNSView(_ nsView: NSView, context: Context) {
//        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer {
//            layer.frame = nsView.bounds
//        }
//    }
//}
//
//


import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import AppKit
import Combine

// MARK: - MAIN VIEW
struct ContentView: View {
    @StateObject private var mediaManager = MediaManager()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var shortcutManager = ShortcutManager()
    
    // --- SETTINGS ---
    @AppStorage("notchWidth") private var notchWidth: Double = 700
    @AppStorage("notchHeight") private var notchHeight: Double = 240
    @AppStorage("showMirror") private var showMirror = true
    
    // --- STATE ---
    @State private var isHovering = false
    @State private var activeTab: Tab = .nook
    @State private var storedFiles: [StoredFile] = []
    @State private var isDropTargeted = false
    @State private var showSettings = false
    
    enum Tab { case nook, tray }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // MAIN NOTCH INTERFACE
                VStack(spacing: 0) {
                    notchContent
                        .frame(
                            width: isHovering ? CGFloat(notchWidth) : 180,
                            height: isHovering ? CGFloat(notchHeight) : 32
                        )
                        .fixedSize()
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovering)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeTab)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // SETTINGS PANEL
                if showSettings {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture { withAnimation { showSettings = false } }
                        
                    SettingsView(
                        notchWidth: $notchWidth,
                        notchHeight: $notchHeight,
                        showMirror: $showMirror,
                        isPresented: $showSettings,
                        cameraManager: cameraManager
                    )
                    .frame(width: 400, height: 450)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    )
                    .padding(.top, 120)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                }
            }
        }
        .onChange(of: showMirror) { newValue in
            if !newValue {
                cameraManager.stop()
            } else if isHovering && activeTab == .nook {
                cameraManager.start()
            }
        }
    }
    
    var notchContent: some View {
        ZStack(alignment: .top) {
            // BACKGROUND
            RoundedRectangle(cornerRadius: isHovering ? 28 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.95), Color.black.opacity(0.98)]),
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isHovering ? 28 : 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.7), radius: 20, x: 0, y: 10)
            
            // CONTENT
            VStack(spacing: 0) {
                if isHovering {
                    headerView
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    
                    if activeTab == .nook {
                        nookDashboardView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    } else {
                        fileShelfView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }
                } else {
                    collapsedStateView
                        .transition(.opacity)
                }
            }
            .clipped()
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isHovering = hovering
            }
            
            if hovering && activeTab == .nook && showMirror {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cameraManager.start()
                }
            } else {
                cameraManager.stop()
            }
        }
        .onChange(of: isHovering) { newValue in
            // When collapsed (isHovering == false) instruct the panel to ignore mouse events
            // But keep the panel interactive if settings are visible.
            let ignore = !(newValue || showSettings)
            NotificationCenter.default.post(name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil, userInfo: ["ignore": ignore])
        }

        .onChange(of: showSettings) { newValue in
            // Ensure the panel accepts mouse events while settings are shown so the settings UI is usable.
            let ignore = !(isHovering || newValue)
            NotificationCenter.default.post(name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil, userInfo: ["ignore": ignore])
        }
        
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            withAnimation {
                activeTab = .tray
                isHovering = true
            }
            handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - SUBVIEWS
    
    var headerView: some View {
        HStack(spacing: 15) {
            Button(action: { withAnimation { activeTab = .nook } }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Nook")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(activeTab == .nook ? .white : .gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(activeTab == .nook ? Color.white.opacity(0.15) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { withAnimation { activeTab = .tray } }) {
                HStack(spacing: 6) {
                    Image(systemName: "tray.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Tray")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(activeTab == .tray ? .white : .gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(activeTab == .tray ? Color.white.opacity(0.15) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: { withAnimation { showSettings.toggle() } }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    var nookDashboardView: some View {
        HStack(spacing: 14) {
            // MEDIA PLAYER
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    if let art = mediaManager.albumArt {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mediaManager.trackTitle)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(.white)
                        Text(mediaManager.artistName)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack(spacing: 25) {
                    Button(action: mediaManager.previousTrack) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                    }
                    Button(action: mediaManager.togglePlayPause) {
                        Image(systemName: mediaManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                    }
                    Button(action: mediaManager.nextTrack) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            
            // SHORTCUTS
            VStack(spacing: 10) {
                ForEach(shortcutManager.shortcuts.prefix(3)) { shortcut in
                    Button(action: { shortcutManager.run(shortcut) }) {
                        HStack(spacing: 10) {
                            Image(systemName: shortcut.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.cyan)
                                .frame(width: 20)
                            Text(shortcut.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 180)
            
            // CAMERA MIRROR
            if showMirror {
                ZStack {
                    if cameraManager.isAuthorized {
                        CameraPreviewView(cameraManager: cameraManager)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10)
                    } else {
                        Button(action: {
                            // Check if we need to request or if it's been denied
                            let status = AVCaptureDevice.authorizationStatus(for: .video)
                            if status == .notDetermined {
                                cameraManager.requestPermission()
                            } else {
                                cameraManager.openSystemPreferences()
                            }
                        }) {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "video.slash")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                        Text(AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined ? "Enable" : "Settings")
                                            .font(.caption2)
                                            .foregroundColor(.cyan)
                                    }
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    var fileShelfView: some View {
        VStack(spacing: 12) {
            if storedFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down.fill")
                        .font(.system(size: 40))
                        .foregroundColor(isDropTargeted ? .cyan : .gray)
                        .animation(.spring(response: 0.3), value: isDropTargeted)
                    Text(isDropTargeted ? "Release to add files" : "Drag files here to store them")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(storedFiles) { file in
                            FileItemView(file: file) {
                                removeFile(file)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxHeight: .infinity)
    }
    
    var collapsedStateView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 5, height: 5)
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 4, height: 4)
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 3, height: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // --- LOGIC ---
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil),
                       !storedFiles.contains(where: { $0.url == url }) {
                        withAnimation(.spring(response: 0.3)) {
                            storedFiles.append(StoredFile(url: url))
                        }
                    }
                }
            }
        }
    }
    
    func removeFile(_ file: StoredFile) {
        withAnimation(.spring(response: 0.3)) {
            storedFiles.removeAll { $0.id == file.id }
        }
    }
}

// MARK: - SETTINGS VIEW
struct SettingsView: View {
    @Binding var notchWidth: Double
    @Binding var notchHeight: Double
    @Binding var showMirror: Bool
    @Binding var isPresented: Bool
    @ObservedObject var cameraManager: CameraManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { withAnimation { isPresented = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 10)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Appearance")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Width: \(Int(notchWidth))px")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Slider(value: $notchWidth, in: 500...900, step: 10)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height: \(Int(notchHeight))px")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Slider(value: $notchHeight, in: 180...300, step: 10)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Features")
                    .font(.headline)
                
                HStack {
                    Toggle("Show Camera Mirror", isOn: $showMirror)
                    
                    if !cameraManager.isAuthorized && showMirror {
                        Button("Open Settings") {
                            cameraManager.openSystemPreferences()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                if !cameraManager.isAuthorized && showMirror {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚠️ Camera access required")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Click 'Open Settings' → Find your app → Enable camera → Restart app")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }
            }
            
            Spacer()
            
            Text("Made with ♥ for macOS")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(30)
    }
}

// MARK: - CAMERA MANAGER CLASS
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            setupSession()
        case .notDetermined:
            // Don't request automatically
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.setupSession()
                    self.start()
                }
            }
        }
    }
    
    func openSystemPreferences() {
        // Open System Settings to Camera privacy
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        NSWorkspace.shared.open(url)
        
        // Show alert with instructions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Enable Camera Access"
            alert.informativeText = "In System Settings:\n1. Find your app in the list\n2. Toggle the switch to ON\n3. Restart the app"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func setupSession() {
        guard !session.isRunning else { return }
        
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        session.commitConfiguration()
    }
    
    func start() {
        guard isAuthorized, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
}

// MARK: - MEDIA MANAGER CLASS
class MediaManager: ObservableObject {
    @Published var trackTitle: String = "Not Playing"
    @Published var artistName: String = "No media active"
    @Published var isPlaying: Bool = false
    @Published var albumArt: NSImage? = nil
    @Published var appName: String = "Music"
    
    private var timer: Timer?
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startListening()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startListening() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchTrackInfo()
        }
        fetchTrackInfo()
    }
    
    func fetchTrackInfo() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let spotifyScript = """
            tell application "Spotify"
                if it is running then
                    return {player state as string, name of current track, artist of current track, artwork url of current track}
                end if
            end tell
            """
            
            let musicScript = """
            tell application "Music"
                if it is running then
                    return {player state as string, name of current track, artist of current track}
                end if
            end tell
            """
            
            if let result = self.runAppleScript(spotifyScript) {
                self.appName = "Spotify"
                self.parseSpotify(result)
            } else if let result = self.runAppleScript(musicScript) {
                self.appName = "Music"
                self.parseMusic(result)
            } else {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.trackTitle = "Not Playing"
                    self.artistName = "No media active"
                    self.albumArt = nil
                }
            }
        }
    }
    
    func togglePlayPause() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runAppleScript("tell application \"\(self.appName)\" to playpause")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.fetchTrackInfo()
            }
        }
    }
    
    func nextTrack() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runAppleScript("tell application \"\(self.appName)\" to next track")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.fetchTrackInfo()
            }
        }
    }
    
    func previousTrack() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.runAppleScript("tell application \"\(self.appName)\" to previous track")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.fetchTrackInfo()
            }
        }
    }
    
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: source) else { return nil }
        
        let output = scriptObject.executeAndReturnError(&error)
        if error == nil {
            if output.descriptorType == typeAEList {
                var results: [String] = []
                for i in 1...output.numberOfItems {
                    if let item = output.atIndex(i)?.stringValue {
                        results.append(item)
                    }
                }
                return results.joined(separator: "|||")
            }
            return output.stringValue
        }
        return nil
    }
    
    private func parseSpotify(_ result: String) {
        let components = result.components(separatedBy: "|||")
        guard components.count >= 3 else { return }
        
        DispatchQueue.main.async {
            self.isPlaying = (components[0] == "playing")
            self.trackTitle = components[1]
            self.artistName = components[2]
            
            if components.count >= 4, let url = URL(string: components[3]) {
                self.downloadArtwork(from: url)
            }
        }
    }
    
    private func parseMusic(_ result: String) {
        let components = result.components(separatedBy: "|||")
        guard components.count >= 3 else { return }
        
        DispatchQueue.main.async {
            self.isPlaying = (components[0] == "playing")
            self.trackTitle = components[1]
            self.artistName = components[2]
            self.albumArt = nil
        }
    }
    
    private func downloadArtwork(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self?.albumArt = image
                }
            }
        }.resume()
    }
}

// MARK: - HELPERS
struct StoredFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let icon: NSImage
    let fileSize: String
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        if let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attr[.size] as? Int64 {
            self.fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            self.fileSize = "Unknown"
        }
    }
}

struct FileItemView: View {
    let file: StoredFile
    let onRemove: () -> Void
    @State private var isHoveringFile = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: file.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                
                if isHoveringFile {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: 8, y: -8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            VStack(spacing: 2) {
                Text(file.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                
                Text(file.fileSize)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(isHoveringFile ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(isHoveringFile ? 0.2 : 0), lineWidth: 1)
        )
        .animation(.spring(response: 0.3), value: isHoveringFile)
        .onHover { isHoveringFile = $0 }
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.isVideoMirrored = true
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        view.layer = previewLayer
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer {
            layer.frame = nsView.bounds
        }
    }
}
