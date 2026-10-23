# UDPソケット：ピアツーピア通信

UDP Sockets: Peer to Peer Communication: Japanese edition.

このテクニカルノートでは、4D 20R10で導入されたUDPSocketクラスとUDPEventクラスを使って、ローカルネットワーク上の4Dアプリケーション同士がサーバーなしでお互いを見つける、ピアツーピアのピア検出メカニズムを解説します。中心となるPeerDiscoveryクラスは、UDPブロードキャストによるアナウンスとプローブを送受信し、TTLにもとづいて古いピアを自動的に削除しながら、検出したピアを共有コレクションで管理します。付属のデモでは、同じネットワーク上で実行中のインスタンスがリアルタイムで一覧に表示され、ログで通信の様子を確認できます。

This technical note explains a serverless peer discovery mechanism for 4D applications on a local network, built on the UDPSocket and UDPEvent classes introduced in 4D 20R10. The companion demo lists the running instances on the same network in real time.

## Download

| | |
|---|---|
| PDF (日本語) | [25-12_UPDPeerToPeer_ja.pdf](https://github.com/miyako/UPDPeerToPeer/releases/latest/download/25-12_UPDPeerToPeer_ja.pdf) |
| 4D demo | [UPDPeerToPeer.zip](https://github.com/miyako/UPDPeerToPeer/releases/latest/download/UPDPeerToPeer.zip) |
| Original (English) | `document/25-12_UPDPeerToPeer.pdf` |

## Demo

- 4D version: 20 R10 or later
- Open `demo/UPDPeerToPeer/Project/UPDPeerToPeer.4DProject`.
- Languages: English, Japanese. The UI follows the system language; the XLIFF files are in `Resources/<lang>.lproj/`.
- The demo window opens at startup as a non-modal window in the application process. Run it on two or more machines on the same subnet, with UDP port 54321 open, to see peers appear.

## Differences from the original

- The cover no longer shows "Technical Note 25-12".
- The demo UI (form labels, column headers, alerts, "time ago" text) is localised with XLIFF. The `Util_formatLastSeen` code printed in the note is the original English version; the demo uses `Localized string`.
- The startup alert "This Demo Must be Launched in 20R10 and above" was removed, and the main window is no longer modal.
- The figure (list box column screenshot) is the original English screenshot.
- The text is translated faithfully, including a few places where the description differs from the code (e.g. default TTL and probe interval values).

## Editing and rebuilding

The PDF is generated from plain-text sources. Edit them and run `make`.

| File | What |
|---|---|
| `src/ja.md` | Translated body text. **Don't touch code blocks** (`make check` verifies them). |
| `figures/fig-NN.ja.txt` | Text drawn in figure NN. Line N corresponds to line N of `fig-NN.en.txt`: an identical line keeps the original, an empty line erases it. |
| `figures/layout/fig-NN.json` | Per-label overrides for size, weight, alignment and position; `"replace"` uses a ready-made image |
| `glossary.md` | Terminology |

```sh
make            # check → figures → build/25-12_UPDPeerToPeer_ja.pdf
make check      # code blocks unchanged, figure references complete
make review     # contact sheets of the figures (build/contact-N.png)
make release-assets
```

Requirements: Python 3, Google Chrome, CJK fonts, and Tesseract (only needed for re-extraction).
See the [localisation template](https://github.com/miyako/4d-technote-localisation-template) for the full workflow.

## Credits

- Original: Anouar Moustarih, Quality Support Engineer, 4D Morocco (Technical Note 25-12)
- Produced with [4d-technote-localisation-template](https://github.com/miyako/4d-technote-localisation-template) and GitHub Copilot.
