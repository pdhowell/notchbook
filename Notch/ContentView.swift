import SwiftUI

struct ContentView: View {
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // THE NOTCH PILL
            ZStack(alignment: .top) {
                // Background
                RoundedRectangle(cornerRadius: isHovering ? 24 : 14, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: isHovering ? 24 : 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // Content Layer
                VStack {
                    if isHovering {
                        // EXPANDED CONTENT
                        VStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Drop Files Here")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    } else {
                        // COLLAPSED STATE (The Peek)
                        VStack {
                            Spacer()
                            Capsule()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 36, height: 4)
                                .padding(.bottom, 5)
                        }
                    }
                }
            }
            .frame(
                width: isHovering ? 450 : 160,
                height: isHovering ? 160 : 38
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovering)
            // CRITICAL: Add contentShape to make the entire frame hoverable
            .contentShape(Rectangle())
            // Hover Trigger - now works on the entire shape
            .onHover { hovering in
                withAnimation {
                    isHovering = hovering
                }
            }
            // Add padding from the top to position below the notch
            .padding(.top, -6)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
