# TokenBar Audio Arrangement

TokenBar audio is opt-in and uses built-in macOS system sounds only. The repo does not ship audio assets.

## CLI Arrangement

Run:

```bash
tokenbar --sound
```

or:

```bash
TOKENBAR_SOUND=1 tokenbar
```

The launch animation is intentionally short and data-aware. The current motion language is QD opening an agent console, reading the local usage index, building a runway forecast, checking budget dials, and arming the natural-language prompt editor. With `--sound`, it uses short cues:

- local log read: light tick
- budget and reset estimate lock-in: small pop
- app opened: warm resolved chime

## Demo Video Direction

For a public launch video, the intended sound palette is:

- low soft hum for local monitor startup
- small digital ticks for electrons and token formation
- tighter pulse when quota pressure appears
- warm resolved chime when TokenBar opens
- no vocals, no copyrighted samples, no aggressive alarm sounds

The audio should communicate that TokenBar is a continuous regulator: calm, local, useful, and always available from the menu bar.
