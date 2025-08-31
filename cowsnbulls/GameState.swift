import SwiftUI
import Observation

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

