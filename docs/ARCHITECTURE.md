# Architecture

`src/macos/main.swift` connects AppKit events, window lifecycle, rendering and local state. `NativeCat.swift`, motion, eye, mouth and paw modules compose the layered 2D cat. Growth models and `CatGrowthStore.swift` keep goals and persistence separate from presentation; `CatGrowthController.swift` renders the growth panel. `CatLetter.swift` and `CatLetterDrift.swift` implement the local reader.

Release behavior is selected using the explicit Swift definitions in `scripts/build-macos.sh`. Preview definitions are for development and must not be substituted into a release build. Browser source files are a separate earlier prototype.

Model tests exercise scoring, dates, toys and motion without an app installation. The full suite adds native controllers, GUI lifecycle checks, rendered comparisons, storage migration and both target architectures. Test fixtures preserve prior rendering and motion behavior for regression comparisons; their version labels are internal baselines, not public release claims.

Historical renderer baselines needed by tests are checked in as sanitized source fixtures. No test requires the original private Git history; `docs/fixture-provenance.json` identifies those fixture bytes.
