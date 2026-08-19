# omarchy-pixel-buds

An Omarchy bar panel for Google Pixel Buds, backed by
[`pbpctrl`](https://github.com/qzed/pbpctrl).

## Features

- Appears automatically while paired Pixel Buds are connected
- Left, right, and case battery levels
- Off, ANC, transparency, and adaptive noise control
- Five-band equalizer

## Install

```bash
omarchy plugin add https://github.com/MattMangoni/omarchy-pixel-buds.git --enable
```

The panel needs `pbpctrl-git` for detailed battery and noise controls. If it is
missing, the panel offers an install button and opens a terminal for the normal
`yay` package review and password prompt. Plugin installation itself never runs
privileged commands.

## Development

```bash
python -m unittest discover -s tests
omarchy plugin validate .
```
