# tsearch

An advanced, multi-source torrent search tool written in Bash. `tsearch` queries multiple public torrent indexers in parallel, aggregates the results, and lets you filter, sort, and output them as either human-readable text, full magnet links, or JSON.

**Made by Taylor Christian Newsome**

## Repository

https://github.com/SleepTheGod/tsearch

---

## Features

- **Parallel searching** across 11+ torrent sources
- **Filter by minimum size** (in GB)
- **Sort** by `size`, `date`, or `seeders`
- **Category filtering** (movies, tv, apps, games, music)
- **Magnet-only output** mode for piping into torrent clients
- **JSON output** mode for scripting and automation
- **Live tracker list** injection via [ngosang/trackerslist](https://github.com/ngosang/trackerslist)

### Supported Sources

| Source | Type |
|--------|------|
| apibay (The Pirate Bay) | JSON API |
| bitsearch | JSON API |
| knaben | JSON API |
| torrentgalaxy | HTML |
| 1337x | HTML |
| limetorrents | HTML |
| torlock | HTML |
| nyaa | RSS |
| btdig | HTML |
| solidtorrents | HTML |
| torrentz2 | HTML |

---

## Requirements

- **Bash** 4.0+
- **curl**
- **python3**
- **jq**
- Standard Unix tools: `awk`, `sort`, `sed`, `tr`, `mktemp`, `date`

### Install dependencies

**Debian / Ubuntu:**
```bash
sudo apt install curl python3 jq
```

**Arch:**
```bash
sudo pacman -S curl python3 jq
```

**macOS (Homebrew):**
```bash
brew install curl python3 jq
```

---

## Installation

```bash
git clone https://github.com/SleepTheGod/tsearch.git
cd tsearch
chmod +x main.sh
```

Optionally move it somewhere on your `$PATH`:

```bash
sudo mv main.sh /usr/local/bin/tsearch
```

---

## Usage

```
tsearch <query> [options]
```

### Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-h` | `--help` | Show help menu |
| `-v` | `--version` | Show version information |
| `-m <GB>` | `--minsize <GB>` | Minimum file size in Gigabytes (default: `0`) |
| `-s <method>` | `--sort <method>` | Sort by `size`, `date`, or `seeders` (default: `size`) |
| `-c <cat>` | `--category <cat>` | Filter by category: `movies` `tv` `apps` `games` `music` |
| `-t` | `--trackers` | Append live tracker list to magnet output |
| `-M` | `--magnet` | Output only full magnet links |
| `-j` | `--json` | Output results as JSON |

---

## Examples

**Exact phrase search:**
```bash
./main.sh "sql dump"
```

**Broad keyword search:**
```bash
./main.sh sql
```

**Search within a category:**
```bash
./main.sh sql -c apps
```

**Version-specific search:**
```bash
./main.sh ubuntu 22.04
```

**TV episode matching:**
```bash
./main.sh S01E01
```

**Full season search:**
```bash
./main.sh "season 01"
```

**Minimum size + sort by date:**
```bash
./main.sh "sql dump" -m 1 -s date
```

**Category with live trackers:**
```bash
./main.sh "ubuntu" -c apps -t
```

**Magnet links only, with trackers:**
```bash
./main.sh "debian iso" -M -t
```

**JSON output for scripting:**
```bash
./main.sh "windows 11" -j
```

**Pipe magnets into a torrent client:**
```bash
./main.sh "arch linux" -M -t | xargs -n1 transmission-remote -a
```

---

## Output Format

**Default (human-readable):**
```
2024-01-15 |   12.34 GB | S  1200 L   340 | Ubuntu 22.04 Desktop amd64 | a1b2c3d4e5f6...
```

Columns: `date | size | S(seeders) L(leechers) | title | info_hash`

**Magnet-only (`-M`):**
```
magnet:?xt=urn:btih:a1b2c3d4e5f6...&dn=Ubuntu 22.04 Desktop amd64&tr=udp://...
```

**JSON (`-j`):**
```json
[
  {
    "title": "Ubuntu 22.04 Desktop amd64",
    "size_gb": 12.34,
    "info_hash": "a1b2c3d4e5f6...",
    "source": "apibay",
    "seeders": 1200,
    "leechers": 340,
    "added": "1705320000"
  }
]
```

---

## How It Works

1. URL-encodes your query and fans it out to all configured sources **in parallel**.
2. Each source's response is parsed by an inline Python script that normalizes it into a common pipe-delimited format: `added|size_gb|title|info_hash|source|seeders|leechers`.
3. Results are merged, sorted, and rendered as text, magnets, or JSON based on your flags.
4. Temp files are cleaned up automatically on exit via `trap`.

---

## Notes & Limitations

- Sources come and go — some indexers may be offline or blocked in your region. Failed sources are simply skipped.
- `-c`/`--category` is accepted but not currently used for server-side filtering; category results depend on the indexer.
- The tracker list is fetched live from `raw.githubusercontent.com` — if that's unreachable, magnet output will still work but without trackers.
- Use a VPN if torrenting is restricted in your jurisdiction.

---

## License

See the repository for license details.

## Author

[SleepTheGod](https://github.com/SleepTheGod) — Taylor Christian Newsome
