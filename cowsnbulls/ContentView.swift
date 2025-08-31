// Bulls & Cows — SwiftUI Starter by ChatGPT
// Xcode 15+ • iOS 17+ • Swift 5.9
// Create a new iOS App (SwiftUI) project and replace ContentView.swift with this file's content.

import SwiftUI
import Observation

// MARK: - Game Logic
struct BullsCowsResult: Identifiable {
    let id = UUID()
    let guess: String
    let bulls: Int
    let cows: Int
}

@Observable
final class GameState {
    var secret: String = ""
    var guesses: [BullsCowsResult] = []
    var maxAttempts: Int = 12
    var isGameOver: Bool = false
    var didWin: Bool = false

    // Settings
    var codeLength: Int = 4
    var allowRepeats: Bool = false

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
            // Ensure first digit isn't 0 for nicer UX
            let firstPool = Array("123456789")
            var code = String(firstPool.randomElement()!)
            digits.removeAll(where: { $0 == code.first! })
            while code.count < length {
                let d = digits.remove(at: Int.random(in: 0..<digits.count))
                code.append(d)
            }
            return code
        } else {
            // Repeats allowed; first digit can be 0 or not — keep it simple
            return String((0..<length).map { _ in Array("0123456789").randomElement()! })
        }
    }

    func submit(guess: String) {
        guard !isGameOver else { return }
        guard validate(guess: guess) == nil else { return }

        let (b, c) = Self.score(guess: guess, secret: secret)
        let result = BullsCowsResult(guess: guess, bulls: b, cows: c)
        guesses.insert(result, at: 0)

        if b == codeLength {
            didWin = true
            isGameOver = true
        } else if guesses.count >= maxAttempts {
            didWin = false
            isGameOver = true
        }
    }

    func validate(guess: String) -> String? {
        if guess.count != codeLength { return "Enter exactly \(codeLength) digits." }
        if !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: guess)) {
            return "Digits only." }
        if !allowRepeats && Set(guess).count != guess.count { return "No repeating digits." }
        if guess.first == "0" && !allowRepeats { return "First digit can't be 0." }
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
}

// MARK: - UI
struct ContentView: View {
    @State private var input: String = ""
    @State private var validationMessage: String? = nil
    @State private var showSettings = false
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)

    @State private var game = GameState()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                inputRow
                if let msg = validationMessage { Text(msg).foregroundStyle(.red).font(.footnote) }
                attemptsProgress
                historyList
                Spacer(minLength: 0)
                footer
            }
            .padding()
            .navigationTitle("Bulls & Cows")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings.toggle() } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { settingsSheet }
        }
        .onAppear { haptic.prepare() }
    }

    // MARK: - Subviews
    var header: some View {
        VStack(spacing: 6) {
            Text("Guess the secret code")
                .font(.title2.weight(.semibold))
            Text("\(game.codeLength) unique digits. Bulls = right digit & place. Cows = right digit, wrong place.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    var inputRow: some View {
        HStack(spacing: 12) {
            TextField("Your guess", text: $input)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)
                .disableAutocorrection(true)
                .font(.title3.monospaced())
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: input) { _, newVal in
                    // keep digits only & trim to length
                    let digitsOnly = newVal.filter { $0.isNumber }
                    input = String(digitsOnly.prefix(game.codeLength))
                    validationMessage = nil
                }

            Button(action: onSubmit) {
                Image(systemName: "paperplane.fill")
                    .font(.title3.weight(.semibold))
                    .padding(12)
                    .background(Color.accentColor.opacity(0.15), in: Circle())
            }
            .disabled(game.isGameOver)
        }
    }

    var attemptsProgress: some View {
        let used = game.guesses.count
        let total = game.maxAttempts
        return HStack {
            ProgressView(value: Double(used), total: Double(total))
                .tint(game.isGameOver ? (game.didWin ? .green : .red) : .accentColor)
            Text("\(used)/\(total)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if game.guesses.isEmpty {
                ContentUnavailableView(
                    "No guesses yet",
                    systemImage: "lightbulb",
                    description: Text("Try a number like 1234 or 4271.")
                )
                .padding(.top, 16)
            } else {
                List(game.guesses) { r in
                    HStack {
                        Text(r.guess).font(.body.monospaced())
                        Spacer()
                        Label("\(r.bulls)", systemImage: "circle.fill").labelStyle(.titleAndIcon).foregroundStyle(.green)
                        Label("\(r.cows)", systemImage: "circle").labelStyle(.titleAndIcon).foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .frame(maxHeight: 320)
            }
        }
    }

    var footer: some View {
        VStack(spacing: 10) {
            if game.isGameOver {
                VStack(spacing: 4) {
                    Text(game.didWin ? "You cracked it!" : "Out of attempts")
                        .font(.title3.weight(.semibold))
                    Text("Secret was \(game.secret)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(role: .cancel) {
                    withAnimation { input.removeAll() }
                    game.newGame()
                } label: {
                    Label("New Game", systemImage: "arrow.clockwise")
                }

                Spacer()

                Menu {
                    Picker("Attempts", selection: $game.maxAttempts) {
                        ForEach([8, 10, 12, 14, 16], id: \.self) { Text("\($0) attempts").tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Attempts: \(game.maxAttempts)", systemImage: "flag")
                }
            }
            .font(.callout)
        }
    }

    var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Code") {
                    Stepper(value: $game.codeLength, in: 3...6, step: 1, onEditingChanged: { _ in }) {
                        Text("Length: \(game.codeLength)")
                    }
                    Toggle("Allow repeating digits", isOn: $game.allowRepeats)
                }
                Section(footer: Text("Changing settings starts a fresh game.")) {
                    Button("Apply & Start New Game") {
                        input.removeAll()
                        game.newGame()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions
    func onSubmit() {
        if let error = game.validate(guess: input) {
            validationMessage = error
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        haptic.impactOccurred()
        withAnimation { game.submit(guess: input) }
        input.removeAll()
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}

