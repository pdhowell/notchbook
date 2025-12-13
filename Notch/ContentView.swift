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
    
    // SETTINGS
    @AppStorage("notchWidth") private var notchWidth: Double = 700
    @AppStorage("notchHeight") private var notchHeight: Double = 240
    @AppStorage("showMirror") private var showMirror = true
    
    // STATE 
    @State private var isHovering = false
    @State private var activeTab: Tab = .notch
    @State private var storedFiles: [StoredFile] = []
    @State private var isDropTargeted = false
    @State private var showSettings = false
    
    enum Tab { case notch, shelf }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // MAIN NOTCH INTERFACE
                VStack(spacing: 0) {
                    notchContent
                        .frame(
                            width: isHovering ? CGFloat(notchWidth) : 220,
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
        .padding(.top, 6)
        .onChange(of: showMirror) { _, newValue in
            if !newValue {
                cameraManager.stop()
            } else if isHovering && activeTab == .notch && cameraManager.isEnabled {
                cameraManager.start()
            }
        }
    }
    
    var notchContent: some View {
        ZStack(alignment: .top) {
            // BACKGROUND
            BottomRoundedRectangle(bottomRadius: isHovering ? 24 : 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.95), Color.black.opacity(0.98)]),
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    BottomRoundedRectangle(bottomRadius: isHovering ? 24 : 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                // heavy drop shadow when expanded
                .shadow(color: .black.opacity(isHovering ? 0.7 : 0.0), radius: isHovering ? 20 : 0, x: 0, y: isHovering ? 10 : 0)
            
            // CONTENT
            VStack(spacing: 0) {
                if isHovering {
                    headerView
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    
                    if activeTab == .notch {
                            notchDashboardView
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

            if hovering && activeTab == .notch && showMirror && cameraManager.isEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cameraManager.start()
                }
            } else {
                cameraManager.stop()
            }
        }
        .onChange(of: isHovering) { _, newValue in
            let ignore = !(newValue || showSettings)
            NotificationCenter.default.post(name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil, userInfo: ["ignore": ignore])
        }

        .onChange(of: showSettings) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isHovering = false
                }
            }

            let ignore = !(isHovering || newValue)
            NotificationCenter.default.post(name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil, userInfo: ["ignore": ignore])
        }
        .onChange(of: activeTab) { _, newTab in
            if newTab == .notch && isHovering && showMirror && cameraManager.isEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cameraManager.start()
                }
            } else {
                cameraManager.stop()
            }
        }
        
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            withAnimation {
                activeTab = .shelf
                isHovering = true
            }
            handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - SUBVIEWS
    var headerView: some View {
        HStack(spacing: 15) {
            Button(action: { withAnimation { activeTab = .notch } }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Notch")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(activeTab == .notch ? .white : .gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(activeTab == .notch ? Color.white.opacity(0.15) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { withAnimation { activeTab = .shelf } }) {
                HStack(spacing: 6) {
                    Image(systemName: "tray.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Shelf")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(activeTab == .shelf ? .white : .gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(activeTab == .shelf ? Color.white.opacity(0.15) : Color.clear)
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
    
    var notchDashboardView: some View {
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
                
                HStack(spacing: 20) {
                    SleekIconButton(systemName: "backward.fill", size: 16, action: mediaManager.previousTrack)

                    SleekIconButton(systemName: mediaManager.isPlaying ? "pause.circle.fill" : "play.circle.fill", size: 28, action: mediaManager.togglePlayPause)

                    SleekIconButton(systemName: "forward.fill", size: 16, action: mediaManager.nextTrack)
                }
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
            
            // CAMERA
            if showMirror {
                ZStack {
                    if cameraManager.isAuthorized {
                        ZStack {
                            CameraPreviewView(cameraSession: cameraManager)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10)
                                .contentShape(Circle())
                                .onTapGesture {
                                    // If camera is currently enabled, tapping the preview will turn it off
                                    if cameraManager.isEnabled {
                                        cameraManager.isEnabled = false
                                        cameraManager.stop()
                                    }
                                }

                            // Centered camera-on toggle UI when OFF: shows camera icon with label
                            if !cameraManager.isEnabled {
                                Button(action: {
                                    // Toggle ON: enable and request permission/start
                                    cameraManager.isEnabled = true
                                    if cameraManager.isAuthorized {
                                        cameraManager.start()
                                    } else {
                                        cameraManager.requestPermission()
                                    }
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "camera")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Camera")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.45)))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } else {
                        Button(action: {
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
        
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // LOGIC
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                DispatchQueue.main.async {
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
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
                    Text("Width")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Slider(value: $notchWidth, in: 550...700, step: 40)
                        .onChange(of: notchWidth) { _, newValue in
                            if newValue < 550 { notchWidth = 550 }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Slider(value: $notchHeight, in: 220...270, step: 10)
                        .onChange(of: notchHeight) { _, newValue in
                            if newValue < 220 { notchHeight = 220 }
                        }
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
    @Published var isRunning: Bool = false
        @Published var isEnabled: Bool = false
    
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
                    if self.isEnabled {
                        self.start()
                    }
                }
            }
        }
    }
    
    func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        NSWorkspace.shared.open(url)
        
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
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }
    
    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }
}


// MARK: - MEDIA MANAGER CLASS (FIXED & OPTIMIZED)
class MediaManager: ObservableObject {
    @Published var trackTitle: String = "Not Playing"
    @Published var artistName: String = "No media active"
    @Published var isPlaying: Bool = false
    @Published var albumArt: NSImage? = nil
    @Published var appName: String = "Music"
    
    private var timer: Timer?
    private var currentTrackIdentifier: String = ""
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startListening()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startListening() {
        // Poll every 1.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.fetchTrackInfo()
        }
        fetchTrackInfo()
    }
    
    func fetchTrackInfo() {
        let musicApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first
        let spotifyApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first
        
        if let spotify = spotifyApp, !spotify.isTerminated {
            self.appName = "Spotify"
            runSpotifyScript()
        } else if let music = musicApp, !music.isTerminated {
            self.appName = "Music"
            runMusicScript()
        } else {
            resetState()
        }
    }
    
    private func resetState() {
        if !currentTrackIdentifier.isEmpty {
            DispatchQueue.main.async {
                self.isPlaying = false
                self.trackTitle = "Not Playing"
                self.artistName = "No media active"
                self.albumArt = nil
                self.currentTrackIdentifier = ""
            }
        }
    }

    // MARK: - Spotify Logic
    private func runSpotifyScript() {
        let script = """
        tell application "Spotify"
            if player state is playing then
                set sState to "playing"
            else
                set sState to "paused"
            end if
            -- We get the ID to know if the song changed
            return {sState, name of current track, artist of current track, id of current track, artwork url of current track}
        end tell
        """
        executeScript(script, parseMethod: parseSpotify)
    }
    
    private func parseSpotify(_ result: String) {
        let components = result.components(separatedBy: "|||")
        // State, Name, Artist, ID, URL
        guard components.count >= 4 else { return }
        
        let newState = components[0]
        let newTitle = components[1]
        let newArtist = components[2]
        let newID = components[3]
        
        DispatchQueue.main.async {
            self.isPlaying = (newState == "playing")
            self.trackTitle = newTitle
            self.artistName = newArtist
            
            // Only fetch artwork if the song ID changed
            if self.currentTrackIdentifier != newID {
                self.currentTrackIdentifier = newID
                self.albumArt = nil 
                
                if components.count >= 5 {
                    let urlString = components[4]
                    if let url = URL(string: urlString) {
                        self.downloadArtwork(from: url)
                    }
                }
            }
        }
    }

    // MARK: - Apple Music Logic
    private func runMusicScript() {
        let script = """
        tell application "Music"
            if player state is playing then
                set pState to "playing"
            else
                set pState to "paused"
            end if
            -- Music doesn't have a simple ID, so we make one from name+artist
            return {pState, name of current track, artist of current track}
        end tell
        """
        executeScript(script, parseMethod: parseMusic)
    }
    
    private func parseMusic(_ result: String) {
        let components = result.components(separatedBy: "|||")
        guard components.count >= 3 else { return }
        
        let newState = components[0]
        let newTitle = components[1]
        let newArtist = components[2]
        
        // Create a unique signature for this song
        let newID = "\(newTitle)-\(newArtist)"
        
        DispatchQueue.main.async {
            self.isPlaying = (newState == "playing")
            self.trackTitle = newTitle
            self.artistName = newArtist
            
            // Only fetch artwork if the song changed
            if self.currentTrackIdentifier != newID {
                self.currentTrackIdentifier = newID
                self.albumArt = nil // Clear old art
                self.fetchMusicArtwork()
            }
        }
    }
    
    private func fetchMusicArtwork() {
        // Apple Music holds raw data, not a URL. We must grab the 'data' descriptor.
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptSource = "tell application \"Music\" to get data of artwork 1 of current track"
            if let scriptObject = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                let output = scriptObject.executeAndReturnError(&error)
                
                // output.data is the raw image data (TIFF/JPEG)
                if error == nil {
                    let artData = output.data
                    if let image = NSImage(data: artData) {
                        DispatchQueue.main.async {
                            self.albumArt = image
                        }
                    }
                }
            }
        }
    }

    // MARK: - Common Helpers
    private func executeScript(_ source: String, parseMethod: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: source) {
                let output = scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    print("AppleScript Error: \(error)")
                    return
                }
                
                var resultString = ""
                if output.descriptorType == typeAEList {
                    var results: [String] = []
                    for i in 1...output.numberOfItems {
                        // handle standard text items
                        if let item = output.atIndex(i)?.stringValue {
                            results.append(item)
                        } else {
                            // If an item is missing/null
                            results.append("")
                        }
                    }
                    resultString = results.joined(separator: "|||")
                } else {
                    resultString = output.stringValue ?? ""
                }
                
                parseMethod(resultString)
            }
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
    
    // MARK: - Controls
    func togglePlayPause() {
        executeSimpleScript("tell application \"\(self.appName)\" to playpause")
    }
    
    func nextTrack() {
        executeSimpleScript("tell application \"\(self.appName)\" to next track")
    }
    
    func previousTrack() {
        executeSimpleScript("tell application \"\(self.appName)\" to previous track")
    }
    
    private func executeSimpleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: source) {
                scriptObject.executeAndReturnError(&error)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.fetchTrackInfo()
            }
        }
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

// MARK: - Sleek icon button used for media controls
struct SleekIconButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(.white)
                .opacity(hovering ? 1.0 : 0.9)
                .scaleEffect(hovering ? 1.05 : 1.0)
                .animation(.spring(response: 0.18, dampingFraction: 0.7), value: hovering)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { self.hovering = $0 }
        .padding(.vertical, 4)
        .frame(minWidth: size + 8, minHeight: size + 8)
    }
}

// Custom shape: only the bottom corners are rounded; top corners are square.
struct BottomRoundedRectangle: Shape {
    var bottomRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let br = min(bottomRadius, min(rect.width / 2, rect.height / 2))

        var path = Path()
        path.move(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: maxY - br))
        path.addArc(center: CGPoint(x: maxX - br, y: maxY - br), radius: br,
                    startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: minX + br, y: maxY))
        path.addArc(center: CGPoint(x: minX + br, y: maxY - br), radius: br,
                    startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: minX, y: minY))
        path.closeSubpath()

        return path
    }
}

struct CameraPreviewView: NSViewRepresentable {
    @ObservedObject var cameraSession: CameraManager // provides `session: AVCaptureSession`

    func makeNSView(context: Context) -> NSView {
        // 1. Create a basic NSView that is layer-backed
        let view = NSView()
        view.wantsLayer = true
        
        // 2. Create the preview layer using the session
        // Note: Access the session from your manager or property
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession.session)
        
        // 3. Configure the layer appearance
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    previewLayer.frame = view.bounds
    // Use CA layer autoresizing masks for CALayer
    previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // 4. Add the layer to the view
        view.layer = previewLayer
        
        // 5. CRITICAL FIX: Configure the connection immediately after creation
        setupConnection(for: previewLayer)
        
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure the frame updates if the window resizes
        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer {
            layer.frame = nsView.bounds
            
            // Re-check connection settings in case they reset (rare but safe)
            setupConnection(for: layer)
        }
    }

    // MARK: - The Fix
    private func setupConnection(for previewLayer: AVCaptureVideoPreviewLayer) {
        // We must check if the connection exists (it might be nil momentarily during startup)
        guard let connection = previewLayer.connection else { return }
        
        if connection.isVideoMirroringSupported {
            // Disable automatic mirroring adjustments, then set mirroring explicitly
            if connection.responds(to: Selector(("setAutomaticallyAdjustsVideoMirroring:"))) {
                connection.automaticallyAdjustsVideoMirroring = false
            }
            connection.isVideoMirrored = true
        }
    }
}
