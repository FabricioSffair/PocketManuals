# Pocket Manuals

An iOS and macOS showcase for [RailtracksSwift](https://github.com/RailtownAI/Railtracks-swift): ask your PDF manuals, and get answers that cite the page and are checked by a verifier.

Every run is traced to JSON, to the in-app call tree, and to Instruments through
RailtracksInstrumentationKit.

Pocket Manuals started as its own app, then shared one app with the Travel Assistant, and is now its own repository again.

## How it works

A RAG showcase: you import PDF manuals, the app indexes each one page by page, and
questions are answered from your own manuals with page-level citations. Tabs:
**Library** (PDF import, bundled samples, indexing), **Ask** (grounded answers with
page citations, checked by a verifier) and **Settings**.

### The library

- **Import PDF** copies the file to `Documents/Manuals/<id>.pdf` (`<id>` is a UUID),
  reads the title and page count with PDFKit, and indexes it immediately.
- Swiping to delete removes the document, its file, and its pages from the index.
- The list is saved as JSON at `Application Support/PocketManuals/library.json`.
- **Samples** are bundled from `PocketManuals/Samples/`. The synchronized
  folder copies them flat into the bundle, and the app looks in both places. They show
  up as *Not indexed* and are indexed only when you tap **Index**, never at launch,
  because on a device without the on-device model that would spend your OpenAI key.

### Ask

One `RTSOrchestratorNode` (`AskWorkflow`, traced as "Ask Manuals") runs two agents on
the provider chosen in Settings:

1. **Answerer.** Calls `SearchManuals`, an `RTSKnowledgeSearchTool` over
   `ManualIndex.search`, and replies with `{ claims: [{ text, citations }], notFound }`,
   each citation a `"<docID>#page-N"` key.
2. **Verifier.** No tools. Gets the numbered claims and the collected passages and
   returns a verdict per claim: supported, partial or unsupported (✓, ~, ⚠).

**Ground answers in my manuals** (on by default, in Ask and in Settings) switches the
search tool and the Verifier off for a with/without comparison. The scope picker
searches all manuals or one. Tapping a citation chip or a source opens the manual at
that page.

### The index and its embedder

`ManualIndex` (an actor) keeps one `RTSRAGFileStore` per embedder at
`Application Support/ManualIndex/<embedder-id>/`. It embeds on-device with Apple's
`NLContextualEmbedding` when its assets are already present (loaded within 8 s);
otherwise with OpenAI `text-embedding-3-small` if Allow OpenAI embeddings is on and an OpenAI key is set;
otherwise it is unavailable and Settings shows why. Simulators cannot load the
on-device embedding model, so there indexing needs an OpenAI key. **Re-index
library** (Settings) indexes every document again with the active embedder, skipping
pages already stored for it.

### Sample manuals

Four sample PDFs ship in `PocketManuals/Samples/`. Each sample's title in
the library is its file name. All four are US federal government works, public domain
(17 U.S.C. §105); may contain third-party images.

| Sample | Publisher | Source |
|---|---|---|
| Kitchen Companion (USDA) | U.S. Department of Agriculture (govinfo copy) | https://www.govinfo.gov/content/pkg/GOVPUB-A110-PURL-LPS99050/pdf/GOVPUB-A110-PURL-LPS99050.pdf |
| Energy Saver Guide (DOE) | U.S. Department of Energy (Energy Saver Guide 2022) | https://www.energy.gov/sites/default/files/2022-08/energy-saver-guide-2022.pdf |
| Citizens Guide to Radon (EPA) | U.S. Environmental Protection Agency (A Citizen's Guide to Radon) | https://www.epa.gov/sites/default/files/2016-12/documents/2016_a_citizens_guide_to_radon.pdf |
| Prepare Your Pets for Disasters (Ready.gov) | Ready.gov | https://www.ready.gov/sites/default/files/2023-06/ready.gov_prepare-pets-for-disasters.pdf |

## Demo script

1. Library tab: tap **Index** on each of the four samples. On a simulator this needs
   the OpenAI key.
2. Ask tab: tap each suggestion and check the cited page:

| Question | Expected citation |
|---|---|
| What temperature should I set my water heater to? | Energy Saver Guide p. 22, 120 °F |
| At what radon level should I fix my home? | Citizen's Guide to Radon p. 6, 4 pCi/L |
| What should go in my pet's emergency kit? | Prepare Your Pets p. 2 |
| What internal temperature should chicken reach? | Kitchen Companion p. 28, 165 °F. Retrieval ranks that page 5th for this wording; the Answerer is told to search again with other wording to reach it |

## Requirements

- Xcode 27 (the SDK's `main` needs it), iOS 18 deployment target. The Answerer and the Verifier run on Apple Intelligence on iOS 26
  and macOS 26, or on the cloud provider.
- This project uses the SDK's `main` branch from GitHub
  (`https://github.com/RailtownAI/Railtracks-swift.git`), with no local changes. The
  revision is pinned in `Package.resolved`; File > Packages > Update to Latest Package
  Versions moves it to the newest `main`. Xcode asks once to trust the `RTSMacro`
  macro; command-line builds pass `-skipMacroValidation`.
- The private `railtown-swift-logger` package resolves over SSH; for command-line
  builds set `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0='url.git@github.com:.insteadOf'
  GIT_CONFIG_VALUE_0='https://github.com/'` and pass `-scmProvider system`.
- Optional: two Railtown keys, entered in Settings under "Railtown". Both pipelines come
  from `railtown-swift-logger`, and each key turns on only its own:
  - **Logs**: `RailtownLogger`, for the app's own logs (`AppLog`) and the errors
    RailtracksSwift reports when a run fails.
  - **Agent runs**: `ConductrTraceUploader`, for each run's agent trace (host
    `testcndr.railtown.ai`), which includes prompts and tool results.

  Without a key, its pipeline stays off. With one, the logger's diagnostics print to the
  console, which shows whether batches upload.
- An API key for OpenAI, Anthropic or Gemini, entered once in the Settings tab and stored in
  the Keychain under the service `io.railtown.PocketManuals.apikeys`. They are handed to
  `RTSLLMGateway` per run.

## Run

1. Open `PocketManuals.xcodeproj`, select an iPhone simulator, a device or My Mac, and press ⌘R.
   The bundle id is `io.railtown.PocketManuals`.
2. Settings: pick a provider, and paste its key.
3. Follow the demo script above.

## Profile in Instruments

Install the Railtracks Instrumentation package (see the visualizer repo), then
Product → Profile with the **Railtracks Instrumentation** template. The Ask Manuals
workflow shows the Answerer with its `SearchManuals` calls, then the Verifier.
