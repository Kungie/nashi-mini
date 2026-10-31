# Nashi Mini

A headless macOS conversion wheel. There is no window, Dock icon or menu bar item: press your mouse button and the wheel opens at the cursor. Pick a format and the converted copy lands in Downloads. Originals are never touched.

Nashi Mini is a stripped-down derivative of [Nashi](https://github.com/orkunisitmak/nashi-app) by Orkun Işıtmak. It keeps Nashi's conversion engine and wheel, and removes everything else.

## Install

Requires macOS 13+ on Apple Silicon and the Xcode Command Line Tools.

```sh
scripts/install.sh
```

On first launch, allow Nashi Mini in System Settings › Privacy & Security › Accessibility, then press the mouse button you want. A key combination or function key works too. Nashi Mini starts at login from then on.

If Logi Options+ owns your button, assign it a keystroke such as F19 there, then press that button in Nashi Mini.

## Use

- Select files in Finder and press your button.
- Or press it while dragging files, then drop them on a format.

Click a format to convert, or press Esc to cancel. Video, audio and Office conversions use the tools Nashi installs in `~/Library/Application Support/Nashi/Tools`.

## Change the shortcut or quit

Open Nashi Mini again from Applications. The small window that appears takes a new shortcut, and has a Quit button.

## License

MIT. See [LICENSE](LICENSE). Bundled and external components keep their own licenses; see [Resources/THIRD-PARTY-NOTICES.txt](Resources/THIRD-PARTY-NOTICES.txt).
