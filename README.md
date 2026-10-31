# Nashi Mini

A headless macOS file wheel. There is no main window, Dock icon or menu bar item: press your mouse button, and a wheel opens at the cursor. Pick a format or tool, and the result lands in Downloads. Originals are never touched.

Nashi Mini is a stripped-down derivative of [Nashi](https://github.com/orkunisitmak/nashi-app) by Orkun Işıtmak. It keeps Nashi's engine and wheel, and replaces every editor window with presets.

## Install

You need an Apple Silicon Mac on macOS 13 or later.

1. Install Apple's command line tools, if you don't have them:

   ```sh
   xcode-select --install
   ```

2. Build and install the app into `/Applications`:

   ```sh
   git clone https://github.com/Kungie/nashi-mini.git
   cd nashi-mini
   scripts/install.sh
   ```

3. Nashi Mini opens a small window and macOS asks for Accessibility access. Turn on **Nashi Mini** in System Settings › Privacy & Security › Accessibility. The app needs this to hear your button anywhere on the Mac.

4. Set your shortcut. See the next section.

5. Video, audio and Office files need ffmpeg and LibreOffice. If they are missing, the window shows **Download Media & Office Tools**. Click it once. The downloads are large and hash-verified, and a line at the bottom of the screen shows progress. Images and most PDF work don't need them.

Nashi Mini starts at login from then on. The first time you use a Finder selection, macOS also asks to let it control Finder. Allow that too.

## Set your shortcut

With the Nashi Mini window open, press the button you want. It is saved right away, and the window closes.

- **Mouse buttons:** middle, back, forward and any extra button work. Your button stops doing its old job, so the Back button no longer goes back in your browser.
- **Keys:** use a function key (F1 to F20) alone, or any key with ⌘, ⌥, ⌃ or ⇧. Plain letters are rejected so typing never opens the wheel.
- **Mouse software:** if pressing a button does nothing in the window, your mouse app is keeping it. In Logi Options+, a button set to Do nothing, Gesture or Radial Menu sends nothing to the Mac. Pick the button, choose Keystroke Assignment, and enter an unused combination such as ⌃⌥⌘K. Then press the button in the Nashi Mini window.

Nashi Mini takes the shortcut over in every app, so avoid combinations you use. ⌘Z would stop undo everywhere, and ⇧⌘N would stop New Folder in Finder.

To change the shortcut, open Nashi Mini again from Applications and press a new one. Esc keeps the current one.

## Use

- Select files in Finder and press your button.
- Or start dragging files and press your button while you drag, then drop them on a format.

The wheel starts on formats. **Click the center** to switch to tools, and click it again to go back. A tool with options opens a smaller wheel of presets. Click a petal to run it. To close the wheel, press Esc, click outside it, or press your button again. The arrow keys, Return and Tab also work.

A line at the bottom of the screen shows progress, the saved file, or any error.

## Tools

Which tools appear depends on your selection.

| Files | Tools |
| --- | --- |
| Image | Compress, Metadata, Edit Photo (rotate, flip, half size, black and white, vivid, brighten, sharpen), Add BG (white, black, gradient), Crop Image (1:1, 4:3, 3:4, 16:9, 9:16 from the center), Read QR Codes |
| Several images | Compress, Metadata, Crop Image, Read QR Codes, Create PDF, Create Collage |
| Video | Compress, Metadata, Remove Audio, Trim Video (first 10, 30 or 60 seconds), Crop Video, Change Video Speed (0.5× to 4×), Video Snapshots, Split Video (2 to 5 clips) |
| Several videos | Compress, Metadata, Remove Audio, Join Videos |
| Audio | Compress, Metadata, Normalize Volume, Audio Visualizer, Trim Audio (first 10, 30 or 60 seconds, or trim silence), Convert Audio Channels |
| Several audio files | Compress, Metadata, Normalize Volume |
| PDF | Compress, Metadata, Split PDF, Organize PDF (reverse pages), Read QR Codes |
| Several PDFs | Compress, Metadata, Split PDF, Read QR Codes, Merge PDFs |
| Archive | Extract Archive |

Nashi's Annotate, Redact and Bleep tools are left out, because they need you to draw on the file or mark a time range. Exact trims and free-form crops are out for the same reason.

## Quit or uninstall

Open Nashi Mini from Applications and click **Quit Nashi Mini**. To stop it starting at login, turn it off in System Settings › General › Login Items.

To uninstall, quit it, then delete `/Applications/Nashi Mini.app`. Downloaded tools are in `~/Library/Application Support/Nashi/Tools`, and regular Nashi shares them.

## Update

```sh
git pull
scripts/install.sh
```

The app is signed locally, so macOS treats each new build as a new app and its permissions stop working, even if the switches still look on. See [Troubleshooting](#troubleshooting) to grant them again. Your shortcut is kept.

## Troubleshooting

- **The window keeps saying Allow Nashi Mini:** in System Settings › Privacy & Security › Accessibility, select Nashi Mini and remove it with **−**. Add `/Applications/Nashi Mini.app` back with **+** and turn it on. The window updates within a few seconds.
- **"Allow Nashi Mini to control Finder":** reset the permission, select a file in Finder, press your button and click Allow:

  ```sh
  tccutil reset AppleEvents io.github.kungie.nashi-mini
  ```

- **"Select files in Finder first":** the button works, but Finder wasn't the active app or nothing was selected.
- **The button isn't recorded:** your mouse app is keeping it. See [Set your shortcut](#set-your-shortcut).

## License

MIT. See [LICENSE](LICENSE). Bundled and external components keep their own licenses; see [Resources/THIRD-PARTY-NOTICES.txt](Resources/THIRD-PARTY-NOTICES.txt).
