import Foundation

// MARK: - GuideContent
// Single source of truth for all game instruction text.
// Used by OverviewPageView (Learn to Play sheet) and the GUIDE menu tab.
// Change words here — both pages update automatically.

struct GuideContent {

    // MARK: - What Is This
    static let whatIsThis = "ReFret is a fretboard training app for guitar players. It teaches you to memorize notes by string and fret position across the entire neck — from open strings to fret 19."

    // MARK: - Two Consoles
    static let beginner = "Six answer buttons, one per string, each labelled with a note name. Tap the correct string for each note as it is called. Notes are revealed one by one before each round so you can study them first."
    static let maestro = "No labels. Two answer buttons show note names — identify the correct one from memory. Wrong answers restart the current fret. A more demanding test of recall."

    // MARK: - Lesson Styles
    struct LessonStyles {
        static let sequential       = "Notes revealed string by string. Answer each in order. Available in both consoles."
        static let chord            = "All strings of a chord shape active at once. Answer the highlighted one. Beginner only."
        static let speedRun         = "Race through all frets 0 → top → 0 against the clock. Best times saved to HOME. Maestro only."
    }

    // MARK: - Rounds & Frets
    static let roundsAndFrets = "One round covers all six strings on one fret. Complete a round to advance. Fret 0 is open strings. The game reaches fret 12 by default, then reverses — or fret 19 with High Frets purchased."

    // MARK: - Direction
    static let directionIntro       = "Controls which fret the game starts from and which way it moves across the neck."
    static let ascending            = "Starts at fret 0, moves up the neck. Reverses at the top. Uses sharps (e.g. F♯)."
    static let descending           = "Starts at the highest fret, moves down. Reverses at fret 0. Uses flats (e.g. G♭)."
    static let accidentals          = "Accidental notes are always shown with a black background — like black keys on a piano — across all screens and buttons."

    // MARK: - Progression
    static let progressionIntro     = "Controls the order strings are answered within each fret."
    static let highToLow            = "From string 1 (thinnest) down to string 6 (thickest)."
    static let lowToHigh            = "From string 6 (thickest) up to string 1 (thinnest)."

    // MARK: - Scoring
    static let scoring = "Correct answers earn $1 (Beginner) or $2 (Maestro). Wrong answers score nothing — the fret restarts. Build a streak of consecutive correct answers to unlock multipliers and earn more per note. Balance carries forward between sessions."

    // MARK: - Control Panel
    struct ControlPanel {
        static let autoplay         = "Plays correct answers automatically. Use to listen and learn. Tap again to stop."
        static let fretboard        = "Shows all note names at the current fret for reference. Green when active. Gray when unavailable."
        static let menu             = "Opens the menu. Tap CLOSE to dismiss."
    }

    // MARK: - Menu Tabs
    struct MenuTabs {
        static let home             = "Wallet, balance, purchasable upgrades, console skins, and Speed Run scoreboard."
        static let options          = "Starting fret, repetitions, direction, progression, and Maestro lesson style."
        static let guide            = "Game instructions and control reference."
        static let audio            = "Guitar tone, tempo, and volume."
    }
}
