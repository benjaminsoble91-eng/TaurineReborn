# Taurine Reborn

A fork of [Taurine](https://github.com/Odyssey-Team/Taurine) (iOS 14.0–14.8.1, A8–A14) with a cleaned-up,
faster UI. **The exploits, kernel code and post-exploit code are untouched**, byte for byte.

> This product includes software developed by The Odyssey Team.

## The exploit code is untouched

Everything below is identical to upstream Taurine (commit `b4824a0`):

- `Taurine/exploit/` (cicuta_virosa, kfd physpuppet/smith, KernelRW)
- `Taurine/post-exploit/` (Electra, patchfinder, amfid takeover, remount, bootstrap)
- `Taurine/resources/`, `Taurine/electra-stub.swift`, `Taurine-Bridging-Header.h`
- `Taurine/app/ExploitManager/` (exploit selection)
- `kern-rw/`, `ctbypass/`, `amfidebilitate/`, `external/`, `test-kernrw/`
- The exploit dispatch block inside `ViewController.jailbreak()`

Check it yourself with `./scripts/verify-untouched.sh`. The GitHub Actions build also runs it,
so a build fails if any of those files ever change.

## What changed (UI layer only)

### Faster
- **Jailbreak starts ~1s sooner.** Upstream waited a flat 1.5s (`asyncAfter(1)` + `usleep(500ms)`)
  before running the exploit. Reborn starts as soon as the log sheet finishes presenting, plus a short 0.3s settle
  (`exploitStartSettleTime`, which you can raise if your success rate ever drops).
- **The log no longer slows the jailbreak down.** Upstream re-rendered and re-styled the *entire* log on the main
  thread for every chunk of output. That work grows quadratically while the jailbreak is running. Reborn appends only
  the new text and coalesces UI updates to about 15 per second.
- **The animated background freezes while jailbreaking**, so the GPU isn't busy re-blurring moving gradients.
- **Faster launch.** All four wallpaper HEICs used to be decoded at launch. Now only the chosen one loads, and it's
  decoded and downscaled to screen size off the main thread.
- **No pointless background rebuilds.** Every 10s the background was torn down and rebuilt with a 4s crossfade, even
  though every theme has a single background. Gradient animations also restarted on every layout pass. Both are fixed.
- **Credits avatars load only when you open Credits.** Upstream fetched all 7 at launch. They're now cached and
  decoded off the main thread.
- Picked custom wallpapers are saved in the background at screen resolution, not as a full-size PNG on the main
  thread. Colour-picker drags are throttled.

### Cleaner
- Jailbreak button: smooth spring progress fill, continuous rounded corners, a press-down effect, a crossfade between
  status texts and consistent labels ("Exploiting Kernel · 1/3", "Jailbreaking · 2/3").
- The progress bar keeps creeping forward during post-exploit stages, so it never looks frozen.
- Haptics: tap, stage change, success/failure, toggles and selections.
- Log window: monospaced styling, auto-scroll only while you're at the bottom (so you can scroll up and read),
  and a **Copy** button.
- Clearer failure state: "Exploit Failed · Reboot & Retry".
- Animated highlight on table rows. Unavailable exploits are dimmed instead of looking tappable.
- Respects Reduce Motion and Low Power Mode by showing a static gradient.
- The home screen name is **Taurine Reborn**.

### Bugs fixed
- Data race: stdout and stderr appended to the same log buffer from a *concurrent* queue.
- Possible crash: `fatalError("User dragged the other way???")` when a panel scroll didn't land exactly.
- Possible crash: `SeparatorView` force-unwrapped `window`.
- Possible deadlock: `showAlert(sync: true)` called on the main thread.
- The update check compared versions as strings ("1.1.10" < "1.1.7"). It now compares them numerically.
- The progress label's clip rect used the 0–1 progress value as a pixel width.
- `AvatarView`'s stale-request check compared the URL to itself, so it never worked.
- The first gradient animation ran with a duration of 0.

## Building

**GitHub Actions (no Xcode needed):** push to GitHub, open the **Actions** tab, then download the `TaurineReborn-ipa` artifact.

**On a Mac:**
```sh
git clone --recursive <your fork>
cd Taurine
./scripts/verify-untouched.sh
make            # → Taurine.ipa (unsigned, same as upstream's Makefile)
```

Sign and install the IPA the same way as upstream Taurine, with your sideloader using Apple ID signing.
The app's sanity check requires real signing entitlements, so an unsigned or fake-signed IPA will show
"Sanity Check Failed".

## License

BSD 4-Clause, same as upstream. See `LICENSE.md`.
