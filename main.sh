#!/bin/bash

# ==============================================================================
# tsearch - Advanced Torrent Search Tool
# Made by Taylor Christian Newsome
# ==============================================================================

VERSION="1.0"
SCRIPT_NAME=$(basename "$0")

QUERY=""
MINSIZE=0
SORT_BY="size"
CATEGORY=""
TRACKERS=""
SHOW_MAGNET=0
JSON_OUTPUT=0

usage() {
    cat << EOF
$SCRIPT_NAME - Advanced Torrent Search Tool v$VERSION
Made by Taylor Christian Newsome

Usage
  $SCRIPT_NAME <query> [options]

Search Vectors
  "sql dump"              Exact phrase matching
  sql                     Broad keyword matching
  sql -c apps             Search within a specific category
  ubuntu 22.04            Version-specific search
  S01E01                  TV episode matching
  "season 01"             Full-season search

Options
  -h, --help              Show this help menu
  -v, --version           Show version information
  -m, --minsize <GB>      Minimum file size in Gigabytes, default 0
  -s, --sort <method>     Sort by size, date, or seeders, default size
  -c, --category <cat>    Filter by category, movies tv apps games music
  -t, --trackers          Append live tracker list to output magnets
  -M, --magnet            Output only full magnet links
  -j, --json              Output results as JSON for scripting

Examples
  $SCRIPT_NAME "sql dump" -m 1 -s date
  $SCRIPT_NAME "ubuntu" -c apps -t
  $SCRIPT_NAME "debian iso" -M -t
  $SCRIPT_NAME "windows 11" -j
EOF
    exit 0
}

while getopts "hvm:s:c:tMj-:" opt; do
    case $opt in
        h) usage ;;
        v) echo "$SCRIPT_NAME version $VERSION - Made by Taylor Christian Newsome"; exit 0 ;;
        m) MINSIZE="$OPTARG" ;;
        s) SORT_BY="$OPTARG" ;;
        c) CATEGORY="$OPTARG" ;;
        t) TRACKERS=1 ;;
        M) SHOW_MAGNET=1 ;;
        j) JSON_OUTPUT=1 ;;
        -)
            case "${OPTARG}" in
                help) usage ;;
                version) echo "$SCRIPT_NAME version $VERSION - Made by Taylor Christian Newsome"; exit 0 ;;
                minsize) MINSIZE="${!OPTIND}"; ((OPTIND++)) ;;
                sort) SORT_BY="${!OPTIND}"; ((OPTIND++)) ;;
                category) CATEGORY="${!OPTIND}"; ((OPTIND++)) ;;
                trackers) TRACKERS=1 ;;
                magnet) SHOW_MAGNET=1 ;;
                json) JSON_OUTPUT=1 ;;
                *) echo "Unknown option --${OPTARG}"; usage ;;
            esac
            ;;
        \?) echo "Invalid option -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

shift $((OPTIND - 1))
QUERY="$1"

if [ -z "$QUERY" ]; then
    echo "Error No search query provided." >&2
    echo "Run $SCRIPT_NAME --help for usage information." >&2
    exit 1
fi

MINSIZE="${MINSIZE//[^0-9.]/}"
[ -z "$MINSIZE" ] && MINSIZE=0

if [ -n "$TRACKERS" ]; then
    TRACKERS=$(curl -sL --max-time 5 "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt" 2>/dev/null | tr '\n' '&' | sed 's/&$//;s/^/&tr=/g' | sed 's/^&tr=//')
fi

q=$(printf '%s' "$QUERY" | jq -sRr @uri)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

SOURCES=(
  "apibay|https://apibay.org/q.php?q=$q"
  "bitsearch|https://bitsearch.eu/api/v1/search?q=$q&page=1"
  "torrentgalaxy|https://torrentgalaxy.to/torrents.php?search=$q&nox=1&sort=seeders&order=desc"
  "1337x|https://1337x.to/search/$q/1/"
  "limetorrents|https://www.limetorrents.lol/search/all/$q/"
  "torlock|https://www.torlock.com/all/torrents/$q.html"
  "nyaa|https://nyaa.si/?f=0&c=0_0&q=$q"
  "btdig|https://btdig.com/search?q=$q"
  "solidtorrents|https://solidtorrents.to/search?q=$q"
  "torrentz2|https://torrentz2.nz/search?f=$q"
  "knaben|https://api.knaben.org/v1"
)

fetch_and_parse() {
    local name="$1" url="$2" out="$3"
    local resp
    if [ "$name" = "knaben" ]; then
        resp=$(curl -sL --max-time 8 --connect-timeout 3 \
            -H "Content-Type: application/json" \
            -d "{\"query\":\"$QUERY\",\"size\":100}" \
            "$url" 2>/dev/null)
    else
        resp=$(curl -sL --max-time 8 --connect-timeout 3 -A "Mozilla/5.0" "$url" 2>/dev/null) || return
    fi
    [ -z "$resp" ] && return
    printf '%s' "$resp" | python3 -c "
import sys, re, html, json
data = sys.stdin.read()
m = $MINSIZE
src = '$name'
rows = []

try:
    j = json.loads(data)
    if src == 'knaben':
        items = j.get('hits', [])
        for t in items:
            gb = int(t.get('bytes', 0)) / 1073741824
            if gb < m: continue
            ih = t.get('hash', '').lower()
            title = t.get('title', '?')
            added = t.get('date', '')
            seeders = t.get('seeders', 0)
            leechers = t.get('peers', 0) - seeders
            rows.append((added, gb, title, ih, src, seeders, leechers))
    elif src == 'bitsearch':
        items = j.get('results', [])
        for t in items:
            gb = int(t.get('size', 0)) / 1073741824
            if gb < m: continue
            ih = t.get('infohash', '').lower()
            title = t.get('title', '?')
            seeders = t.get('seeders', 0)
            leechers = t.get('leechers', 0)
            rows.append(('', gb, title, ih, src, seeders, leechers))
    elif src == 'apibay':
        for t in j:
            if t.get('name') == 'No results returned': continue
            gb = int(t.get('size', 0)) / 1073741824
            if gb < m: continue
            ih = t.get('info_hash', '').lower()
            title = t.get('name', '?')
            added = int(t.get('added', 0) or 0)
            seeders = t.get('seeders', 0)
            leechers = t.get('leechers', 0)
            rows.append((added, gb, title, ih, src, seeders, leechers))
except Exception:
    pass

if not rows and src == 'nyaa':
    for item in re.findall(r'<item>(.*?)</item>', data, re.DOTALL):
        title_m = re.search(r'<title>(.*?)</title>', item)
        hash_m = re.search(r'<nyaa:infoHash>(.*?)</nyaa:infoHash>', item)
        size_m = re.search(r'<nyaa:size>(.*?)</nyaa:size>', item)
        date_m = re.search(r'<pubDate>(.*?)</pubDate>', item)
        if title_m and hash_m:
            title = html.unescape(title_m.group(1))
            ih = hash_m.group(1).lower()
            gb = 0.0
            if size_m:
                sz = size_m.group(1)
                num_m = re.search(r'[\d.]+', sz)
                num = float(num_m.group()) if num_m else 0
                if 'GiB' in sz: gb = num
                elif 'MiB' in sz: gb = num / 1024
                elif 'KiB' in sz: gb = num / 1048576
            if gb >= m:
                rows.append((date_m.group(1) if date_m else '', gb, title, ih, src, 0, 0))

if not rows:
    for m_hash, title in re.findall(r'magnet[?]xt=urn:btih:([a-fA-F0-9]{40})[^\"]*\"[^>]*>([^<]{5,120})', data):
        rows.append(('', 0.0, html.unescape(title).strip(), m_hash.lower(), src, 0, 0))

for added, gb, title, ih, src, seeders, leechers in rows:
    print(f'{added}|{gb:.4f}|{title}|{ih}|{src}|{seeders}|{leechers}')
" > "$out" 2>/dev/null
}

for entry in "${SOURCES[@]}"; do
    name="${entry%%|*}"; url="${entry#*|}"
    fetch_and_parse "$name" "$url" "$tmp/$name" &
done
wait

if [ "$JSON_OUTPUT" = 1 ]; then
    cat "$tmp"/* 2>/dev/null | python3 -c "
import sys, json
results = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    parts = line.split('|')
    if len(parts) < 7: continue
    added, gb, title, ih, src, seeders, leechers = parts
    results.append({
        'title': title,
        'size_gb': float(gb),
        'info_hash': ih,
        'source': src,
        'seeders': int(seeders),
        'leechers': int(leechers),
        'added': added
    })
print(json.dumps(results, indent=2))
"
else
    cat "$tmp"/* 2>/dev/null | sort -t'|' -k1,1nr | awk -F'|' -v sort="$SORT_BY" -v magnet="$SHOW_MAGNET" -v trackers="$TRACKERS" '
    {
        ts=$1; gb=$2; title=$3; ih=$4; src=$5; seeders=$6; leechers=$7
        if (sort == "date" && ts ~ /^[0-9]{4}-/) {
            d = substr(ts, 1, 10)
        } else if (sort == "date" && ts ~ /^[0-9]+$/) {
            cmd = "date -d @" ts " +\"%Y-%m-%d\" 2>/dev/null"
            cmd | getline d; close(cmd)
            if (d == "") d = "unknown"
        } else {
            d = "n/a"
        }
        magnet_link = "magnet:?xt=urn:btih:" ih
        if (trackers == 1) {
            magnet_link = magnet_link "&dn=" title trackers
        }
        if (magnet == 1) {
            print magnet_link
        } else {
            printf "%s | %7.2f GB | S %5s L %5s | %s | %s\n", d, gb, seeders, leechers, substr(title,1,60), ih
        }
    }' | if [ "$SORT_BY" = "date" ]; then sort -r; elif [ "$SORT_BY" = "seeders" ]; then sort -t'|' -k3,3nr; else sort -t'|' -k2,2nr; fi
fi
