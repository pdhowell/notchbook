import SwiftUI
import AppKit
import Combine

final class FilesRecentsViewModel: ObservableObject {
    
    @Published var latestScreenshotURL: URL?
    @Published var recentItems: [URL] = []
    @Published var favoriteFolderURL: URL?

    private var cached = false
    private var favoriteBookmarkKey = "Notch.favoriteFolderBookmark"

    // Activate when the section becomes visible
    func activate() {
        guard !cached else { return }
        cached = true
        loadLatestScreenshot()
        loadRecentItems()
        loadFavoriteFromDefaults()
    }

    // Deactivate when the section is hidden — keep cache semantics simple
    func deactivate() {
        // keep cached results until next app activation; clear only if desired
    }

    private func loadLatestScreenshot() {
        // Check common screenshot locations and pick newest image file
        let fm = FileManager.default
        let candidates = ["~/Desktop", "~/Pictures/Screenshots"].compactMap { URL(string: $0)?.standardizedFileURL }
        var latest: (url: URL, date: Date)?

        for base in candidates {
            let expanded = URL(fileURLWithPath: (base.path as NSString).expandingTildeInPath)
            guard let enumerator = fm.enumerator(at: expanded, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }

            for case let url as URL in enumerator {
                let ext = url.pathExtension.lowercased()
                guard ["png", "jpg", "jpeg", "tiff"].contains(ext) else { continue }
                do {
                    let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey, .isRegularFileKey])
                    guard values.isRegularFile == true else { continue }
                    let date = values.contentModificationDate ?? values.creationDate ?? Date.distantPast
                    if latest == nil || date > latest!.date {
                        latest = (url, date)
                    }
                } catch {
                    continue
                }
            }
            if latest != nil { break } // prefer Desktop first if present
        }

        DispatchQueue.main.async {
            self.latestScreenshotURL = latest?.url
        }
    }

    private func loadRecentItems() {
        // We'll collect (url, lastOpenedDate) pairs and sort by the date desc
        var candidates: [(URL, Date)] = []

        let fm = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.contentAccessDateKey, .contentModificationDateKey, .creationDateKey, .isDirectoryKey]

        // Primary: use NSDocumentController recentDocumentURLs
        let recent = NSDocumentController.shared.recentDocumentURLs
        if !recent.isEmpty {
            for url in recent where url.isFileURL {
                do {
                    let values = try url.resourceValues(forKeys: resourceKeys)
                    let date = values.contentAccessDate ?? values.contentModificationDate ?? values.creationDate ?? Date.distantPast
                    candidates.append((url, date))
                } catch {
                    // If resource values fail, still include with distant past so it sinks to the end
                    candidates.append((url, Date.distantPast))
                }
            }
        } else {
            // Fallback: scan common user folders for recently accessed/modified files/folders (Downloads, Desktop, Documents)
            let paths = ["~/Downloads", "~/Desktop", "~/Documents"].map { ($0 as NSString).expandingTildeInPath }
            for path in paths {
                let folder = URL(fileURLWithPath: path)
                guard fm.fileExists(atPath: folder.path) else { continue }
                if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    for case let url as URL in enumerator {
                        do {
                            let values = try url.resourceValues(forKeys: resourceKeys)
                            let date = values.contentAccessDate ?? values.contentModificationDate ?? values.creationDate ?? Date.distantPast
                            candidates.append((url, date))
                        } catch {
                            continue
                        }
                    }
                }
            }
        }

        // Sort by most recent last-opened (access) date
        candidates.sort { $0.1 > $1.1 }

        // Deduplicate while preserving order and keep first 4
        var seen = Set<String>()
        var final: [URL] = []
        for (url, _) in candidates {
            let key = url.path
            if seen.contains(key) { continue }
            seen.insert(key)
            final.append(url)
            if final.count >= 4 { break }
        }

        DispatchQueue.main.async {
            self.recentItems = final
        }
    }

    // MARK: - Favorite folder bookmark persistence
    private func loadFavoriteFromDefaults() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: favoriteBookmarkKey) else { return }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
            if isStale {
                // try to recreate bookmark later
                DispatchQueue.main.async { self.favoriteFolderURL = nil }
            } else {
                DispatchQueue.main.async { self.favoriteFolderURL = url }
            }
        } catch {
            DispatchQueue.main.async { self.favoriteFolderURL = nil }
        }
    }

    func pickFavoriteFolder(completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { completion(false); return }
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: self.favoriteBookmarkKey)
                DispatchQueue.main.async {
                    self.favoriteFolderURL = url
                }
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    func openFavoriteInFinder() {
        guard let url = favoriteFolderURL else { return }
        if url.startAccessingSecurityScopedResource() {
            NSWorkspace.shared.open(url)
            url.stopAccessingSecurityScopedResource()
        } else {
            // try to open without security scope; Finder may still open
            NSWorkspace.shared.open(url)
        }
    }
}

struct FilesRecentsView: View {
    @StateObject private var vm = FilesRecentsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            GeometryReader { geo in
                HStack(spacing: 12) {
                    // Left column — latest screenshot
                    Group {
                        if let url = vm.latestScreenshotURL, let nsImg = NSImage(contentsOf: url) {
                            Button(action: { NSWorkspace.shared.open(url) }) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width * 0.38, height: geo.size.height)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onDrag {
                                return NSItemProvider(object: url as NSURL)
                            }
                        } else {
                            VStack {
                                Text("No recent screenshot")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(width: geo.size.width * 0.38, height: geo.size.height)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(8)
                        }
                    }

                    // Right column — recent items + favorite folder
                    VStack(alignment: .leading, spacing: 8) {
                        // Recent Files & Folders
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recent")
                                .font(.subheadline)
                                .foregroundColor(.white)

                            if vm.recentItems.isEmpty {
                                Text("No recent items")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(vm.recentItems, id: \.self) { url in
                                    HStack(spacing: 8) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                            .resizable()
                                            .renderingMode(.original)
                                            .frame(width: 20, height: 20)

                                        Text(url.lastPathComponent)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .foregroundColor(.white)

                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        NSWorkspace.shared.open(url)
                                    }
                                    .onDrag {
                                        return NSItemProvider(object: url as NSURL)
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Favorite Folder
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Favorite")
                                .font(.subheadline)
                                .foregroundColor(.white)

                            if let fav = vm.favoriteFolderURL {
                                HStack {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: fav.path))
                                        .resizable()
                                        .frame(width: 22, height: 22)

                                    Text(fav.lastPathComponent)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Spacer()

                                    Button(action: { vm.openFavoriteInFinder() }) {
                                        Text("Open")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.accentColor)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                            } else {
                                Button(action: {
                                    vm.pickFavoriteFolder { _ in }
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                        Text("Set favorite folder")
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .frame(width: geo.size.width * 0.58, height: geo.size.height)
                }
            }
            .frame(height: 160)

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        .onAppear {
            vm.activate()
        }
        .onDisappear {
            vm.deactivate()
        }
    }
}
