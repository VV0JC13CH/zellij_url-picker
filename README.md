# zellij_url-picker

> Press a key, fuzzy-pick any URL on your screen, and open it in your browser — without touching the mouse.

`zellij_url-picker` is a small, dependency-light recreation of the much-loved
[`tmux-urlview`](https://github.com/tmux-plugins/tmux-urlview) workflow for
[zellij](https://zellij.dev/). It grabs the text currently on your pane, finds
every URL in it, drops them into an `fzf` menu, and opens whatever you select.

```
┌─ url-picker ──────────────────────────────────────────────┐
│ open url> rust                                             │
│ Enter: open · Tab: multi-select · Esc: cancel              │
│ > https://www.rust-lang.org                                │
│   https://github.com/zellij-org/zellij                     │
│   https://example.com/path?q=1                             │
└────────────────────────────────────────────────────────────┘
```

---

## Background: `tmux-urlview`

This project is a direct homage to
**[tmux-plugins/tmux-urlview](https://github.com/tmux-plugins/tmux-urlview)** —
the tmux plugin that lets you "quickly open any url on your terminal window."
Its workflow is exactly the one this project recreates for zellij:

- It binds a key (default **`u`**, configurable via `@urlview-key`) that runs
  tmux's [`capture-pane`](https://man.openbsd.org/tmux#capture-pane) — with the
  `-J` flag to join wrapped lines — to grab the pane's text.
- It pipes that capture into a URL extractor —
  [`urlview`](https://github.com/sigpipe/urlview) or
  [`extract_url`](https://github.com/n1trux/extract_url) — which presents a menu
  of every link found.
- You pick one, and it opens.

That tiny "capture → extract → pick → open" pipeline became muscle memory for a
lot of terminal users. zellij plugins can't read another pane's scrollback, so
`zellij_url-picker` rebuilds the same idea using zellij's native `DumpScreen`
and `Run` actions (see [How it works](#how-it-works)).

### References & see also

- [tmux-plugins/tmux-urlview](https://github.com/tmux-plugins/tmux-urlview) — the original tmux plugin this is modelled on.
- [urlview](https://github.com/sigpipe/urlview) — the classic URL extractor (long shipped alongside mutt).
- [firecat53/urlscan](https://github.com/firecat53/urlscan) — a modern `urlview` alternative that keeps surrounding context.
- [wfxr/tmux-fzf-url](https://github.com/wfxr/tmux-fzf-url) — an `fzf`-based take on the same workflow for tmux.
- [tmux-plugins/tmux-open](https://github.com/tmux-plugins/tmux-open) — open highlighted selections (incl. URLs) from copy-mode.

---

## How it works

zellij plugins are sandboxed WebAssembly modules, and the plugin API
deliberately **cannot read another pane's scrollback**. So instead of fighting
that, `zellij_url-picker` uses the same idea `tmux-urlview` always did —
capture, then pipe — wired through two native zellij primitives:

1. A keybind runs **`DumpScreen`** while your pane is still focused, writing its
   contents to a temp file.
2. The same keybind then **`Run`s a floating pane** that executes
   `url-picker.sh`, which extracts the URLs, shows them in `fzf`, and opens your
   pick.

Capturing *before* the floating pane opens is the trick that avoids the picker
dumping itself instead of your work.

---

## Requirements

| Tool        | Why                                          | Required           |
| ----------- | -------------------------------------------- | ------------------ |
| `zellij`    | ≥ 0.40 (uses `DumpScreen` + `Run` keybinds)  | yes                |
| `bash`      | the script is bash (`mapfile`, arrays)       | yes                |
| `fzf`       | the picker UI                                | yes (or `urlview`) |
| `urlview`   | fallback picker if `fzf` is missing          | optional           |
| `xdg-open`  | opens the chosen URL (Linux)                 | one opener needed  |
| `open`      | opens the chosen URL (macOS)                 | one opener needed  |
| `setsid`    | detaches the browser cleanly (util-linux)    | optional           |

On most Linux desktops `bash`, `xdg-open`, and `setsid` are already present;
you usually only need to install `fzf`.

---

## Installation

```sh
git clone https://github.com/VV0JC13CH/zellij_url-picker.git ~/.config/zellij/url-picker
chmod +x ~/.config/zellij/url-picker/url-picker.sh
```

Then add a keybind to your `~/.config/zellij/config.kdl`. The binding has two
parts — dump the screen, then open the picker in a floating pane:

```kdl
keybinds {
    shared_except "locked" {
        bind "Alt u" {
            DumpScreen "/tmp/zellij-urlview.dump";
            Run "bash" "/home/YOU/.config/zellij/url-picker/url-picker.sh" "/tmp/zellij-urlview.dump" {
                floating true
                close_on_exit true
                name "url-picker"
            };
        }
    }
}
```

> **Note:** zellij's `Run` needs an **absolute** path — `~` and `$HOME` are not
> expanded. Edit the path to match where you cloned the repo.

A copy of this snippet lives in [`examples/config.kdl`](examples/config.kdl).

Reload your config (in zellij: enter session mode and reload, or restart) and
press your keybind. A floating menu of every URL on screen appears.

---

## Usage

- **`Alt u`** (or whatever you bound) — open the picker.
- **Type** to fuzzy-filter.
- **Enter** — open the highlighted URL.
- **Tab** — multi-select; Enter then opens all selected URLs.
- **Esc** — cancel.

URLs are de-duplicated and listed most-recent-first (bottom of the screen
first), since the link you just saw is usually the one you want.

### Configuration

Set `URLPICKER_OPENER` if you want a specific opener instead of the
auto-detected one (`xdg-open` → `open` → `$BROWSER`):

```sh
URLPICKER_OPENER=firefox
```

---

## Limitations

- `DumpScreen` captures the **visible viewport**, not the full scrollback —
  same as a default `tmux capture-pane`. Scroll up before opening the picker to
  reach older links.
- URL detection is regex-based and pragmatic; it favours the common cases
  (http/https/ftp/file and `www.` hosts) over RFC-perfect completeness.

---

## Contributing

Contributions are very welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Bug reports, regex improvements, and portability fixes for other shells/OSes
are all appreciated.

---

## License

[MIT](LICENSE) — do whatever you like, just keep the notice.

## Acknowledgements

Standing entirely on the shoulders of
[`tmux-urlview`](https://github.com/tmux-plugins/tmux-urlview) and the broader
[`urlview`](https://github.com/sigpipe/urlview) /
