# PlayLenseCore

Swift-Package mit den ersten Bausteinen der App:

| Target | Inhalt |
|---|---|
| `PlayLenseCore` | `Exercise`-Modell, `ExerciseAnimation` (Keyframe-Format mit Interpolation), `ExerciseValidator`, `ExerciseLibrary` (Seed + Nutzerdatei, Suche, Speichern, Import/Export), Seed-Bundle als Ressource |
| `PlayLenseUI` | `ExerciseLibraryView` (Liste, Suche, Filter, Detail), `ExerciseEditorView` (Formular zum Anlegen und Bearbeiten eigener Übungen) |
| `PlayLenseCoreTests` | Seed lädt und ist valide, ID-Ableitung stimmt mit dem Python-Werkzeug überein, Round-Trip, Interpolation, Speichern/Löschen |

**Status: geschrieben, aber noch nicht kompiliert.** In der Umgebung, in der dieser Code entstand,
gab es keinen Swift-Compiler. Erster Schritt am Mac:

```bash
cd PlayLenseCore
swift build
swift test
```

Erwartbare Nacharbeiten beim ersten Build: kleine Typ- oder Import-Fehler, nichts Strukturelles.

## Einbinden in die App

In Xcode: File → Add Package Dependencies → „Add Local…“ → Ordner `PlayLenseCore` wählen. Dann in
der App:

```swift
import SwiftUI
import PlayLenseCore
import PlayLenseUI

@main
struct PlayLenseApp: App {
    @State private var library = try! ExerciseLibrary.live()

    var body: some Scene {
        WindowGroup {
            ExerciseLibraryView(library: library)
        }
    }
}
```

## Seed aktualisieren

Die Datei `Sources/PlayLenseCore/Resources/exercises.seed.json` wird von
`python3 tools/exercises.py bundle` geschrieben. Nicht von Hand ändern, sondern die Quellen in
`content/exercises/` bearbeiten und neu bündeln.
