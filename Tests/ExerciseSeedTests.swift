import XCTest
import PlayLenseCore

final class ExerciseSeedTests: XCTestCase {
    func testSeedBundleLoadsAndValidates() throws {
        let seed = try ExerciseSeedBundle.loadBundled()
        XCTAssertEqual(seed.schemaVersion, 1)
        XCTAssertGreaterThanOrEqual(seed.exercises.count, 60)

        let validator = ExerciseValidator(vocabulary: seed.vocabulary)
        var seenSlugs = Set<String>()
        for ex in seed.exercises {
            let issues = validator.validate(ex, existingSlugs: seenSlugs)
            XCTAssertTrue(issues.isEmpty, "\(ex.slug): \(issues.map(\.message))")
            seenSlugs.insert(ex.slug)
        }
        XCTAssertEqual(Set(seed.exercises.map(\.id)).count, seed.exercises.count, "IDs müssen eindeutig sein")
    }

    func testStableIDMatchesPythonTool() throws {
        // uuid5(NAMESPACE, "rondo-5v2") aus tools/exercises.py muss identisch sein.
        let seed = try ExerciseSeedBundle.loadBundled()
        let rondo = try XCTUnwrap(seed.exercises.first { $0.slug == "rondo-5v2" })
        XCTAssertEqual(rondo.id, Exercise.stableID(forSlug: "rondo-5v2"))
    }

    func testRoundTripEncoding() throws {
        let seed = try ExerciseSeedBundle.loadBundled()
        let ex = try XCTUnwrap(seed.exercises.first { $0.animation != nil })
        let data = try ExerciseJSON.encoder().encode(ex)
        let back = try ExerciseJSON.decoder().decode(Exercise.self, from: data)
        XCTAssertEqual(ex, back)
    }

    func testAnimationInterpolation() throws {
        let seed = try ExerciseSeedBundle.loadBundled()
        let ex = try XCTUnwrap(seed.exercises.first { $0.slug == "passquadrat-mit-nachlaufen" })
        let anim = try XCTUnwrap(ex.animation)
        let start = try XCTUnwrap(anim.position(of: "a1", at: 0))
        XCTAssertEqual(start.x, 1.5, accuracy: 0.001)
        let mid = try XCTUnwrap(anim.position(of: "a1", at: 0.75))
        XCTAssertGreaterThan(mid.x, 1.5)
        XCTAssertLessThan(mid.x, 8)
    }

    @MainActor
    func testLibrarySaveValidateDelete() throws {
        let seed = try ExerciseSeedBundle.loadBundled()
        let lib = ExerciseLibrary(seed: seed)
        let before = lib.exercises.count

        var ex = Exercise.blank()
        XCTAssertFalse(lib.validate(ex).isEmpty, "Leere Vorlage darf nicht valide sein")
        XCTAssertThrowsError(try lib.save(ex))

        ex.slug = "test-rondo"
        ex.name = "Test-Rondo"
        ex.description = "Eine Testübung mit ausreichend langer Beschreibung für den Validator."
        ex.procedure = "Aufbau und Ablauf mit mindestens sechzig Zeichen, damit die Prüfung des Ablaufs erfüllt ist."
        ex.coachingPoints = ["Eins", "Zwei", "Drei"]
        ex.variations = Variations(easier: ["Größer"], harder: ["Ein Kontakt"])
        ex.tags = ["rondo", "passspiel"]
        XCTAssertTrue(lib.validate(ex).isEmpty, "\(lib.validate(ex))")
        try lib.save(ex)
        XCTAssertEqual(lib.exercises.count, before + 1)

        var dup = ex
        dup.id = UUID()
        XCTAssertThrowsError(try lib.save(dup), "Doppelter Slug muss abgelehnt werden")

        try lib.delete(id: ex.id)
        XCTAssertEqual(lib.exercises.count, before)

        let seedID = try XCTUnwrap(seed.exercises.first).id
        try lib.delete(id: seedID)
        XCTAssertEqual(lib.exercises.count, before - 1)
        try lib.resetToSeed(id: seedID)
        XCTAssertEqual(lib.exercises.count, before)
    }
}
