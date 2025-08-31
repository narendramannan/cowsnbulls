// Bulls & Cows — Kid‑Friendly Edition (SwiftUI)
// Drop this into ContentView.swift. Keep Xcode’s default cowsnbullsApp.swift as @main.
// iOS 17+ / Xcode 15+

import SwiftUI
import Observation
import UIKit

// MARK: - Theme
struct KidTheme {
    let gradient = LinearGradient(colors: [Color(.systemTeal), Color(.systemMint), Color(.systemYellow)], startPoint: .topLeading, endPoint: .bottomTrailing)
    let tile = Color.white.opacity(0.9)
    let accent = Color.orange
    let good = Color.green
    let warn = Color.orange
    let bad  = Color.red
}

// MARK: - Game Result Row
struct BullsCowsResult: Identifiable {
    let id = UUID()
    let guess: String
    let bulls: Int
    let cows: Int
}

// MARK: - Players
struct Player: Identifiable {
    let id = UUID()
    var name: String
    var score: Int = 0
}

// MARK: - Game State
@Observable
final class GameState {
    var secret: String = ""
    var guesses: [BullsCowsResult] = []
    var maxAttempts: Int = 12
    var isGameOver: Bool = false
    var didWin: Bool = false

    // Multiplayer
    var players: [Player] = [Player(name: "Player 1"), Player(name: "Player 2")]
    var currentPlayerIndex: Int = 0
    var currentPlayer: Player { players[currentPlayerIndex] }

    // Settings
    var codeLength: Int = 4
    var allowRepeats: Bool = false
    var kidMode: Bool = true // default ON for this edition

    init() { newGame() }

    func newGame() {
        guesses.removeAll()
        isGameOver = false
        didWin = false
        secret = Self.generateSecret(length: codeLength, allowRepeats: allowRepeats)
        #if DEBUG
        print("[DEBUG] Secret:", secret)
        #endif
    }

    static func generateSecret(length: Int, allowRepeats: Bool) -> String {
        var digits = Array("0123456789")
        if !allowRepeats {
            let firstPool = Array("123456789")
            var code = String(firstPool.randomElement()!)
            digits.removeAll(where: { $0 == code.first! })
            while code.count < length {
                let d = digits.remove(at: Int.random(in: 0..<digits.count))
                code.append(d)
            }
            return code
        } else {
            return String((0..<length).map { _ in Array("0123456789").randomElement()! })
        }
    }

    func submit(guess: String) -> (Int, Int)? {
        guard !isGameOver else { return nil }
        guard validate(guess: guess) == nil else { return nil }

        let (b, c) = Self.score(guess: guess, secret: secret)
        let result = BullsCowsResult(guess: guess, bulls: b, cows: c)
        withAnimation(.spring) { guesses.insert(result, at: 0) }

        if b == codeLength {
            didWin = true
            isGameOver = true
            players[currentPlayerIndex].score += 1
        } else if guesses.count >= maxAttempts {
            didWin = false
            isGameOver = true
        }
        return (b, c)
    }

    func validate(guess: String) -> String? {
        if guess.count != codeLength { return "Enter exactly \(codeLength) digits." }
        if !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: guess)) { return "Digits only." }
        if !allowRepeats && Set(guess).count != guess.count { return "No repeats." }
        if guess.first == "0" && !allowRepeats { return "No leading 0." }
        return nil
    }

    static func score(guess: String, secret: String) -> (Int, Int) {
        var bulls = 0
        var cows = 0
        let g = Array(guess)
        let s = Array(secret)
        for i in 0..<s.count {
            if g[i] == s[i] { bulls += 1 }
            else if s.contains(g[i]) { cows += 1 }
        }
        return (bulls, cows)
    }

    func nextPlayer() {
        guard !players.isEmpty else { return }
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }
}

// MARK: - ContentView
struct ContentView: View {
    @State private var game = GameState()
    @State private var input: String = ""
    @State private var showSettings = false
    @State private var validationMessage: String? = nil
    @State private var winningPulse = false

    let theme = KidTheme()

    var body: some View {
        ZStack {
            theme.gradient.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                mascot
                guessTiles
                keypad
                if let msg = validationMessage { Text(msg).font(.footnote).foregroundStyle(theme.bad).transition(.opacity) }
                attemptsProgress
                historyList
                leaderboard
                Spacer(minLength: 0)
                footer
            }
            .padding([.horizontal, .bottom])
            .padding(.top, 60)
            .toolbarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: input)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
            }
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .overlay(alignment: .top) { topBanner }
        .overlay { if game.didWin { ConfettiView(key: UUID()) } }
        .navigationTitle("Bulls & Cows")
    }

    // MARK: - Subviews
    var header: some View {
        VStack(spacing: 6) {
            Text(game.kidMode ? "Crack the Secret Code!" : "Guess the secret code")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .shadow(radius: 4)
            Text("\(game.codeLength) digits • Bulls = right spot • Cows = right digit")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
            Text("Turn: \(game.currentPlayer.name)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    var mascot: some View {
        HStack(spacing: 12) {
            Text("🐮🐂")
                .font(.system(size: game.kidMode ? 44 : 28))
                .scaleEffect(game.didWin ? 1.2 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.5), value: game.didWin)
            if game.kidMode {
                Text(game.didWin ? "Yay! You did it!" : "Guess the number!")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }

    var guessTiles: some View {
        HStack(spacing: 8) {
            ForEach(0..<game.codeLength, id: \.self) { i in
                let char = i < input.count ? String(Array(input)[i]) : "?"
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.tile)
                    .overlay(Text(char).font(.title2.monospaced()).foregroundStyle(.black.opacity(0.8)))
                    .frame(height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(radius: 3)
                    .scaleEffect(i < input.count ? 1.02 : 1)
                    .animation(.spring, value: input)
            }
        }
    }

    var keypad: some View {
        VStack(spacing: 10) {
            let rows: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],["⌫","0","⏎"]]
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(rows[r], id: \.self) { label in
                        Button { keyTap(label) } label: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.9))
                                .overlay(
                                    Text(label).font(.title3.weight(.semibold)).foregroundStyle(.black)
                                )
                                .frame(height: 54)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    var attemptsProgress: some View {
        let used = game.guesses.count
        let total = game.maxAttempts
        return HStack {
            ProgressView(value: Double(used), total: Double(total))
                .tint(game.isGameOver ? (game.didWin ? theme.good : theme.bad) : theme.accent)
            Text("\(used)/\(total)")
                .font(.footnote.monospaced()).foregroundStyle(.white.opacity(0.9))
        }
    }

    var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if game.guesses.isEmpty {
                ContentUnavailableView(
                    game.kidMode ? "No guesses yet" : "No guesses yet",
                    systemImage: "lightbulb",
                    description: Text(game.kidMode ? "Tap numbers and press ⏎ to try!" : "Try a number like 1234.")
                )
                .padding(.top, 12)
            } else {
                List(game.guesses) { r in
                    HStack(spacing: 12) {
                        Text(r.guess).font(.body.monospaced())
                        Spacer()
                        Label("\(r.bulls)", systemImage: "checkmark.seal.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(theme.good)
                            .scaleEffect(r.bulls > 0 ? 1.1 : 1)
                            .animation(.spring, value: r.bulls)
                        Label("\(r.cows)", systemImage: "wand.and.stars")
                            .foregroundStyle(theme.warn)
                            .scaleEffect(r.cows > 0 ? 1.08 : 1)
                            .animation(.spring, value: r.cows)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .frame(maxHeight: 280)
            }
        }
    }

    var leaderboard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Leaderboard")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(game.players) { player in
                HStack {
                    Text(player.name)
                    Spacer()
                    Text("\(player.score)")
                }
                .font(.subheadline.monospaced())
                .foregroundStyle(.white)
            }
        }
    }

    var footer: some View {
        VStack(spacing: 10) {
            if game.isGameOver {
                VStack(spacing: 4) {
                    Text(game.didWin ? "You cracked it! 🎉" : "Nice try!")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Secret was \(game.secret)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.white.opacity(0.9))
                }
                .transition(.scale)
            }

            HStack {
                Button {
                    withAnimation { input.removeAll() }
                    game.nextPlayer()
                    game.newGame()
                } label: { Label("New Game", systemImage: "arrow.clockwise") }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button {
                    giveHint()
                } label: { Label("Hint", systemImage: "lightbulb.fill") }
                .buttonStyle(.bordered)
                .disabled(game.isGameOver)
            }
        }
    }

    var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Code") {
                    Stepper(value: $game.codeLength, in: 3...6) { Text("Length: \(game.codeLength)") }
                    Toggle("Allow repeating digits", isOn: $game.allowRepeats)
                }
                Section("Play Style") {
                    Toggle("Kid Mode (bigger text, mascot)", isOn: $game.kidMode)
                    Picker("Attempts", selection: $game.maxAttempts) {
                        ForEach([8,10,12,14,16], id: \.self) { Text("\($0)").tag($0) }
                    }
                }
                Section(footer: Text("Applying starts a new game.")) {
                    Button("Apply & New Game") { input.removeAll(); game.newGame() }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    var topBanner: some View {
        HStack(spacing: 8) {
            if game.kidMode { Text("🐮 Bulls = right spot  •  🐓 Cows = right digit") }
        }
        .font(.footnote.weight(.medium))
        .padding(8)
        .background(.white.opacity(0.25), in: Capsule())
        .padding(.top, 6)
    }

    // MARK: - Actions
    func keyTap(_ label: String) {
        validationMessage = nil
        switch label {
        case "⏎":
            if let err = game.validate(guess: input) { validationMessage = err; return }
            let _ = game.submit(guess: input)
            input.removeAll()
        case "⌫":
            if !input.isEmpty { input.removeLast() }
        default:
            guard input.count < game.codeLength else { return }
            guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: label)) else { return }
            if !game.allowRepeats && input.contains(label) { validationMessage = "No repeats"; return }
            if input.isEmpty && label == "0" && !game.allowRepeats { validationMessage = "No leading 0"; return }
            input.append(label)
        }
    }

    func giveHint() {
        guard !game.isGameOver else { return }
        // Simple hint: reveal one digit from the secret (not position). Costs one attempt (adds a dummy guess row with 0/0 and hint text via validation).
        if let d = game.secret.randomElement() {
            validationMessage = "Hint: the number contains \(d)"
            // Count it as using one attempt without adding a guess; we’ll add an empty row for history clarity.
            let hintRow = BullsCowsResult(guess: "Hint: \(d)", bulls: 0, cows: 0)
            withAnimation { game.guesses.insert(hintRow, at: 0) }
            if game.guesses.count >= game.maxAttempts { game.isGameOver = true; game.didWin = false }
        }
    }
}

// MARK: - Confetti (UIKit CAEmitterLayer)
struct ConfettiView: UIViewRepresentable {
    let key: UUID // change value to retrigger
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { emit(on: view) }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private func emit(on view: UIView) {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -4)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 2)

        func cell(_ color: UIColor) -> CAEmitterCell {
            let c = CAEmitterCell()
            c.birthRate = 16
            c.lifetime = 4
            c.velocity = 160
            c.velocityRange = 40
            c.emissionLongitude = .pi
            c.emissionRange = .pi / 8
            c.spin = 3
            c.spinRange = 4
            c.scale = 0.6
            c.scaleRange = 0.3
            c.color = color.cgColor
            c.contents = UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal).cgImage
            return c
        }
        emitter.emitterCells = [cell(.systemPink), cell(.systemTeal), cell(.systemYellow), cell(.systemOrange), cell(.systemGreen)]

        view.layer.addSublayer(emitter)
        // Stop after a burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { emitter.removeFromSuperlayer() }
    }
}

// MARK: - Preview
#Preview { ContentView() }
