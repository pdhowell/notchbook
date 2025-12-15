import SwiftUI

struct FileShelfView: View {
    @Binding var storedFiles: [StoredFile]
    @Binding var isDropTargeted: Bool
    var onRemove: (StoredFile) -> Void

    var body: some View {
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
                                onRemove(file)
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
}
