"""
Applet: Moose Ticker
Summary: Neon watchlist market cards
Description: Cycles a stock watchlist as full-bleed neon cards with Yahoo Finance sparklines. No API key.
Author: coldaine
"""

load("animation.star", "animation")
load("encoding/json.star", "json")
load("http.star", "http")
load("humanize.star", "humanize")
load("render.star", "render")
load("schema.star", "schema")

YAHOO_PREFIX = "https://query1.finance.yahoo.com/v8/finance/chart/"
CACHE_TTL = 60
DEFAULT_SYMBOLS = "NVDA,MU,AMD,MSFT,GOOGL,COST"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"

COLOR_BG = "#000"
COLOR_SYMBOL = "#ffa500"
COLOR_PRICE = "#ffffff"
COLOR_GREEN = "#00ff66"
COLOR_RED = "#ff2244"
COLOR_DIM = "#666666"
COLOR_ERROR = "#ff6688"

FONT_SYMBOL = "6x13"
FONT_PRICE = "6x13"
FONT_META = "tom-thumb"

def main(config):
    symbols = parse_symbols(config.get("symbols", DEFAULT_SYMBOLS))
    range_sel = config.get("Range", "5m&range=1d")
    show_pct = config.bool("DiffDisplay", True)
    dwell_ms = int(config.get("dwell_ms", "3500"))
    if dwell_ms < 1500:
        dwell_ms = 1500
    if dwell_ms > 8000:
        dwell_ms = 8000

    if len(symbols) == 0:
        return error_root("Add symbols in config")

    frames = []
    for symbol in symbols:
        card = build_card(symbol, range_sel, show_pct)
        if card != None:
            frames.append(card)

    if len(frames) == 0:
        return error_root("Yahoo fetch failed")

    return render.Root(
        delay = dwell_ms,
        child = render.Animation(children = frames),
    )

def parse_symbols(raw):
    out = []
    seen = {}
    for part in raw.upper().replace(" ", "").split(","):
        if part == "" or part in seen:
            continue
        if len(part) > 8:
            continue
        seen[part] = True
        out.append(part)
        if len(out) >= 8:
            break
    return out

def build_card(symbol, range_sel, show_pct):
    url = YAHOO_PREFIX + symbol + "?metrics=high?&interval=" + range_sel
    body = fetch_body(url)
    if body == None:
        return error_frame(symbol + " err")

    data = json.decode(body)
    result = data.get("chart", {}).get("result")
    if result == None or len(result) == 0:
        return error_frame(symbol + " n/a")

    meta = result[0].get("meta", {})
    quote = result[0].get("indicators", {}).get("quote", [{}])[0]
    closes = quote.get("close", [])
    if closes == None or len(closes) == 0:
        return error_frame(symbol + " n/a")

    last_close = meta.get("chartPreviousClose")
    current = meta.get("regularMarketPrice")
    if last_close == None or current == None or last_close == 0:
        return error_frame(symbol + " n/a")

    points = current - last_close
    pct = points / last_close * 100.0
    up = pct >= 0
    accent = COLOR_GREEN if up else COLOR_RED
    arrow = "+" if up else ""

    if show_pct:
        diff_text = arrow + humanize.float("#.##", pct) + "%"
    else:
        diff_text = arrow + humanize.float("#.##", points)

    plot_data = sparkline_data(closes, last_close)
    price_text = format_price(current)
    interval = range_label(range_sel)

    # Full-bleed sparkline under large text so the card stays 64x32 and visual.
    overlay = render.Padding(
        pad = (1, 1, 1, 1),
        child = render.Column(
            expanded = True,
            main_align = "space_between",
            children = [
                render.Row(
                    expanded = True,
                    main_align = "space_between",
                    cross_align = "center",
                    children = [
                        render.Text(content = symbol, font = FONT_SYMBOL, color = COLOR_SYMBOL),
                        render.Row(
                            children = [
                                render.Text(content = diff_text, font = FONT_META, color = accent),
                                render.Text(content = " " + interval, font = FONT_META, color = COLOR_DIM),
                            ],
                        ),
                    ],
                ),
                render.Text(content = price_text, font = FONT_PRICE, color = COLOR_PRICE),
            ],
        ),
    )

    return render.Box(
        width = 64,
        height = 32,
        color = COLOR_BG,
        child = render.Stack(
            children = [
                render.Plot(
                    data = plot_data,
                    width = 64,
                    height = 32,
                    color = accent,
                    color_inverted = accent,
                    fill = True,
                ),
                wipe_overlay(),
                overlay,
            ],
        ),
    )

def sparkline_data(closes, last_close):
    data = []
    previous = last_close
    for i in range(len(closes)):
        tick = closes[i]
        if tick == None:
            tick = previous
        else:
            previous = tick
        pct = (tick - last_close) / last_close * 100
        data.append((i, pct))

    # Keep plot readable on 64px
    if len(data) > 64:
        step = int(len(data) / 64)
        if step < 1:
            step = 1
        trimmed = []
        idx = 0
        for j in range(0, len(data), step):
            trimmed.append((idx, data[j][1]))
            idx += 1
            if idx >= 64:
                break
        return trimmed
    return data

def wipe_overlay():
    # Hard left-to-right reveal of the full-bleed sparkline.
    return animation.Transformation(
        child = render.Box(width = 64, height = 32, color = COLOR_BG),
        duration = 20,
        delay = 0,
        origin = animation.Origin(0, 0),
        keyframes = [
            animation.Keyframe(
                percentage = 0.0,
                transforms = [animation.Translate(0, 0)],
            ),
            animation.Keyframe(
                percentage = 0.35,
                transforms = [animation.Translate(64, 0)],
            ),
            animation.Keyframe(
                percentage = 1.0,
                transforms = [animation.Translate(64, 0)],
            ),
        ],
    )

def format_price(value):
    # Compact money string without a $ to save pixels on large prices.
    if value >= 10000:
        return humanize.float("#.", value)
    return humanize.float("#.##", value)

def range_label(range_sel):
    if range_sel == "5m&range=1d":
        return "1D"
    if range_sel == "30m&range=5d":
        return "5D"
    return "1D"

def fetch_body(url):
    res = http.get(
        url = url,
        ttl_seconds = CACHE_TTL,
        headers = {"User-Agent": USER_AGENT},
    )
    if res.status_code != 200:
        return None
    return res.body()

def error_root(msg):
    return render.Root(child = error_frame(msg))

def error_frame(msg):
    return render.Box(
        width = 64,
        height = 32,
        color = COLOR_BG,
        child = render.Column(
            expanded = True,
            main_align = "center",
            cross_align = "center",
            children = [
                render.Text(content = "MOOSE", font = FONT_SYMBOL, color = COLOR_SYMBOL),
                render.Text(content = msg, font = FONT_META, color = COLOR_ERROR),
            ],
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "symbols",
                name = "Symbols",
                desc = "Comma-separated Yahoo tickers (max 8)",
                icon = "chartLine",
                default = DEFAULT_SYMBOLS,
            ),
            schema.Dropdown(
                id = "Range",
                name = "Range",
                desc = "Sparkline range",
                icon = "calendarDays",
                default = "5m&range=1d",
                options = [
                    schema.Option(display = "1 day", value = "5m&range=1d"),
                    schema.Option(display = "5 days", value = "30m&range=5d"),
                ],
            ),
            schema.Toggle(
                id = "DiffDisplay",
                name = "Show percent",
                desc = "On = percent change, Off = points",
                icon = "percent",
                default = True,
            ),
            schema.Dropdown(
                id = "dwell_ms",
                name = "Card dwell",
                desc = "Milliseconds per symbol card",
                icon = "clock",
                default = "3500",
                options = [
                    schema.Option(display = "2.5s", value = "2500"),
                    schema.Option(display = "3.5s", value = "3500"),
                    schema.Option(display = "5s", value = "5000"),
                ],
            ),
        ],
    )
