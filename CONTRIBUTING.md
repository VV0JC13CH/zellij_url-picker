# Contributing to zellij_url-picker

Thanks for taking the time to contribute! This is a small project, so the
process is light.

## Ways to help

- **Report bugs** — open an issue with your OS, `zellij --version`, `bash
  --version`, and the exact steps. A failing example line of terminal text is
  gold for regex bugs.
- **Improve URL detection** — the extraction regex is pragmatic, not perfect.
  PRs that catch a real-world URL it misses (or stop it grabbing trailing junk)
  are very welcome. Please include a sample input in the PR description.
- **Portability** — fixes for macOS, BSD, other shells, or alternative openers.
- **Docs** — clarity fixes, better install instructions, screenshots/GIFs.

## Development setup

There's no build step — it's a single bash script.

```sh
git clone https://github.com/VV0JC13CH/zellij_url-picker.git
cd zellij_url-picker
```

### Testing without zellij

You don't need a running zellij session to test the core logic. Create a fake
screen dump and point the script at it:

```sh
cat > /tmp/dump <<'EOF'
See https://example.com/path?q=1 and (https://github.com/zellij-org/zellij).
Bare host: www.rust-lang.org   trailing dot: https://news.example.org.
EOF

./url-picker.sh /tmp/dump
```

You should get a deduplicated, punctuation-trimmed `fzf` list. Selecting an
entry opens it with your configured opener.

To test just the extraction without opening anything, set a no-op opener:

```sh
URLPICKER_OPENER=true ./url-picker.sh /tmp/dump
```

## Coding guidelines

- **Shell:** target `bash` (the script uses arrays and `mapfile`). Keep it
  POSIX-friendly where it's free to do so, but bash features are fine.
- **Run [ShellCheck](https://www.shellcheck.net/)** before submitting:
  ```sh
  shellcheck url-picker.sh
  ```
- **Style:** 4-space indentation, lowercase variable names, comments that
  explain *why* (the surprising bits — the dump race, the detached opener),
  not *what*.
- Keep the dependency footprint tiny. New hard dependencies need a good reason.

## Submitting changes

1. Fork and create a topic branch (`fix/url-trailing-paren`).
2. Make your change; run ShellCheck and a manual test.
3. Open a PR describing the change and, for regex/parsing changes, the sample
   input that motivated it.

By contributing you agree your work is licensed under the project's
[MIT License](LICENSE).
