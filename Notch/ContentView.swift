import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isHovering = false
    @State private var isDropTargeted = false
    @State private var storedFiles: [StoredFile] = []

    var body: some View {
        VStack(spacing: 0) {
            // THE NOTCH PILL
            ZStack(alignment: .top) {
                // Background with drop highlight
                RoundedRectangle(cornerRadius: isHovering ? 24 : 14, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: isHovering ? 24 : 14, style: .continuous)
                            .stroke(
                                isDropTargeted ? Color.blue.opacity(0.6) : Color.white.opacity(0.1),
                                lineWidth: isDropTargeted ? 2 : 0.5
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // Content Layer
                VStack {
                    if isHovering {
                        // EXPANDED CONTENT
                        if storedFiles.isEmpty {
                            // Empty state
                            VStack(spacing: 8) {
                                Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "tray.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(isDropTargeted ? .blue : .white)
                                Text(isDropTargeted ? "Drop Files Here" : "Magic Shelf")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Drag files here to store them")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            // Files display
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Magic Shelf")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(storedFiles.count) file\(storedFiles.count == 1 ? "" : "s")")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(storedFiles) { file in
                                            FileItemView(file: file) {
                                                removeFile(file)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: 90)
                            }
                        }
                    } else {
                        // COLLAPSED STATE - Badge if files present
                        VStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 36, height: 4)
                                
                                // File count badge
                                if !storedFiles.isEmpty {
                                    Text("\(storedFiles.count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(Color.blue))
                                }
                            }
                            .padding(.bottom, 5)
                        }
                    }
                }
            }
            .frame(
                width: isHovering ? 500 : 160,
                height: isHovering ? 180 : 38
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovering)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: storedFiles.count)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation {
                    isHovering = hovering
                }
            }
            // FILE DROP HANDLING
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            .padding(.top, -5)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // Handle file drops
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                        
                        // Check if file already exists
                        if !storedFiles.contains(where: { $0.url == url }) {
                            let newFile = StoredFile(url: url)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                storedFiles.append(newFile)
                            }
                        }
                        
                        // Keep expanded after drop
                        withAnimation {
                            isHovering = true
                        }
                    }
                }
            }
        }
    }
    
    func removeFile(_ file: StoredFile) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            storedFiles.removeAll { $0.id == file.id }
        }
    }
}

// MARK: - Models

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
        
        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            self.fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            self.fileSize = ""
        }
    }
}

// MARK: - File Item View

struct FileItemView: View {
    let file: StoredFile
    let onRemove: () -> Void
    @State private var isHoveringFile = false
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // File icon
                Image(nsImage: file.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                
                // Remove button on hover
                if isHoveringFile {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                    .offset(x: 6, y: -6)
                }
            }
            
            // File details
            VStack(spacing: 2) {
                Text(file.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
                
                if !file.fileSize.isEmpty {
                    Text(file.fileSize)
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isHoveringFile ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isHoveringFile ? 0.3 : 0), lineWidth: 1)
        )
        .scaleEffect(isHoveringFile ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringFile)
        .onHover { hovering in
            isHoveringFile = hovering
        }
        // CRITICAL: Enable dragging OUT
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
    }
}
