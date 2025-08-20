import SwiftUI

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var animationTimer: Timer?
    
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces, id: \.id) { piece in
                    Circle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .position(x: piece.x, y: piece.y)
                        .opacity(piece.opacity)
                        .scaleEffect(piece.scale)
                        .rotationEffect(.degrees(piece.rotation))
                }
            }
        }
        .onAppear {
            startConfetti()
        }
        .onDisappear {
            stopConfetti()
        }
    }
    
    private func startConfetti() {
        // Create initial burst of confetti
        createConfettiBurst()
        
        // Continue creating confetti pieces
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateConfetti()
            if confettiPieces.count < 50 {
                addNewConfettiPieces()
            }
        }
        
        // Stop after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            stopConfetti()
        }
    }
    
    private func stopConfetti() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Fade out existing pieces
        withAnimation(.easeOut(duration: 1.0)) {
            for index in confettiPieces.indices {
                confettiPieces[index].opacity = 0
            }
        }
        
        // Remove all pieces after fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            confettiPieces.removeAll()
        }
    }
    
    private func createConfettiBurst() {
        for _ in 0..<30 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 50...350),
                y: CGFloat.random(in: -50...100),
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 8...15),
                velocity: CGFloat.random(in: 2...6),
                opacity: 1.0,
                scale: CGFloat.random(in: 0.5...1.0),
                rotation: CGFloat.random(in: 0...360)
            )
            confettiPieces.append(piece)
        }
    }
    
    private func addNewConfettiPieces() {
        for _ in 0..<3 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...400),
                y: -20,
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 6...12),
                velocity: CGFloat.random(in: 1...4),
                opacity: 1.0,
                scale: CGFloat.random(in: 0.4...0.8),
                rotation: CGFloat.random(in: 0...360)
            )
            confettiPieces.append(piece)
        }
    }
    
    private func updateConfetti() {
        withAnimation(.linear(duration: 0.1)) {
            for index in confettiPieces.indices.reversed() {
                confettiPieces[index].y += confettiPieces[index].velocity
                confettiPieces[index].rotation += 5
                
                // Remove pieces that have fallen off screen
                if confettiPieces[index].y > 900 {
                    confettiPieces.remove(at: index)
                }
            }
        }
    }
}

struct ConfettiPiece {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let velocity: CGFloat
    var opacity: Double
    let scale: CGFloat
    var rotation: CGFloat
}

struct SuccessOverlay: View {
    @Binding var isShowing: Bool
    let message: String
    let isOutgoing: Bool
    let onComplete: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    // Add initializer to support the new parameter
    init(isShowing: Binding<Bool>, message: String, isOutgoing: Bool = false, onComplete: @escaping () -> Void) {
        self._isShowing = isShowing
        self.message = message
        self.isOutgoing = isOutgoing
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Success icon - different for outgoing vs incoming
                Image(systemName: isOutgoing ? "minus.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(isOutgoing ? .orange : .green)
                    .scaleEffect(scale)
                
                // Success message
                Text(isOutgoing ? "Money Withdrawn! 💸" : "Transfer Successful! 🎉")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder((isOutgoing ? Color.orange : Color.green).opacity(0.3), lineWidth: 2)
                    )
            )
            .scaleEffect(scale)
            .opacity(opacity)
            
            // Confetti animation - different types for outgoing vs incoming
            if isOutgoing {
                SadConfettiView()
                    .allowsHitTesting(false)
            } else {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismissOverlay()
            }
        }
    }
    
    private func dismissOverlay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 0.8
            opacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowing = false
            onComplete()
        }
    }
}

struct SadConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var animationTimer: Timer?
    
    let sadColors: [Color] = [.gray, .blue.opacity(0.6), .purple.opacity(0.6), .black.opacity(0.7)]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces, id: \.id) { piece in
                    Rectangle() // Sad shapes are rectangles instead of circles
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.6)
                        .position(x: piece.x, y: piece.y)
                        .opacity(piece.opacity)
                        .scaleEffect(piece.scale)
                        .rotationEffect(.degrees(piece.rotation))
                }
            }
        }
        .onAppear {
            startSadConfetti()
        }
        .onDisappear {
            stopConfetti()
        }
    }
    
    private func startSadConfetti() {
        // Create initial smaller burst of sad confetti
        createSadConfettiBurst()
        
        // Continue creating fewer confetti pieces
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            updateConfetti()
            if confettiPieces.count < 25 { // Half as many pieces
                addNewSadConfettiPieces()
            }
        }
        
        // Stop after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            stopConfetti()
        }
    }
    
    private func stopConfetti() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Fade out existing pieces
        withAnimation(.easeOut(duration: 1.0)) {
            for index in confettiPieces.indices {
                confettiPieces[index].opacity = 0
            }
        }
        
        // Remove all pieces after fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            confettiPieces.removeAll()
        }
    }
    
    private func createSadConfettiBurst() {
        for _ in 0..<15 { // Fewer pieces for sad effect
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 50...350),
                y: CGFloat.random(in: -50...100),
                color: sadColors.randomElement() ?? .gray,
                size: CGFloat.random(in: 6...12), // Smaller pieces
                velocity: CGFloat.random(in: 1...3), // Slower falling
                opacity: 0.7, // More transparent
                scale: CGFloat.random(in: 0.3...0.7), // Smaller scale
                rotation: CGFloat.random(in: 0...360)
            )
            confettiPieces.append(piece)
        }
    }
    
    private func addNewSadConfettiPieces() {
        for _ in 0..<2 { // Fewer new pieces
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...400),
                y: -20,
                color: sadColors.randomElement() ?? .gray,
                size: CGFloat.random(in: 5...10),
                velocity: CGFloat.random(in: 0.5...2), // Very slow
                opacity: 0.6,
                scale: CGFloat.random(in: 0.3...0.6),
                rotation: CGFloat.random(in: 0...360)
            )
            confettiPieces.append(piece)
        }
    }
    
    private func updateConfetti() {
        withAnimation(.linear(duration: 0.15)) {
            for index in confettiPieces.indices.reversed() {
                confettiPieces[index].y += confettiPieces[index].velocity
                confettiPieces[index].rotation += 3 // Slower rotation
                
                // Remove pieces that have fallen off screen
                if confettiPieces[index].y > 900 {
                    confettiPieces.remove(at: index)
                }
            }
        }
    }
}

#Preview {
    SuccessOverlay(
        isShowing: .constant(true),
        message: "Your goal has been updated successfully!",
        onComplete: {}
    )
}
