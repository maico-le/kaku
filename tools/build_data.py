#!/usr/bin/env python3
"""
tools/build_data.py
Preprocesses KanjiVG SVG files into optimized JSON data files for Kaku (書く).

KanjiVG: Copyright (C) Ulrich Apel (CC BY-SA 3.0)
KANJIDIC2 / kanjiapi: CC BY-SA 3.0
"""

import os
import sys
import json
import math
import io
import re
import zipfile
import requests
import xml.etree.ElementTree as ET
from svg.path import parse_path

KANJIVG_ZIP_URL = "https://github.com/KanjiVG/kanjivg/releases/download/r20260714/kanjivg-20260714-main.zip"
CACHE_DIR = os.path.join(os.path.dirname(__file__), ".cache")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "data")

# Hiragana definitions: (char, romaji, group)
HIRAGANA_LIST = [
    # Basic Gojuon (46)
    ('あ', 'a', 'a-row'), ('い', 'i', 'a-row'), ('う', 'u', 'a-row'), ('え', 'e', 'a-row'), ('お', 'o', 'a-row'),
    ('か', 'ka', 'ka-row'), ('き', 'ki', 'ka-row'), ('く', 'ku', 'ka-row'), ('け', 'ke', 'ka-row'), ('こ', 'ko', 'ka-row'),
    ('さ', 'sa', 'sa-row'), ('し', 'shi', 'sa-row'), ('す', 'su', 'sa-row'), ('せ', 'se', 'sa-row'), ('そ', 'so', 'sa-row'),
    ('た', 'ta', 'ta-row'), ('ち', 'chi', 'ta-row'), ('つ', 'tsu', 'ta-row'), ('て', 'te', 'ta-row'), ('と', 'to', 'ta-row'),
    ('な', 'na', 'na-row'), ('に', 'ni', 'na-row'), ('ぬ', 'nu', 'na-row'), ('ね', 'ne', 'na-row'), ('の', 'no', 'na-row'),
    ('は', 'ha', 'ha-row'), ('ひ', 'hi', 'ha-row'), ('ふ', 'fu', 'ha-row'), ('へ', 'he', 'ha-row'), ('ほ', 'ho', 'ha-row'),
    ('ま', 'ma', 'ma-row'), ('み', 'mi', 'ma-row'), ('む', 'mu', 'ma-row'), ('め', 'me', 'ma-row'), ('も', 'mo', 'ma-row'),
    ('や', 'ya', 'ya-row'), ('ゆ', 'yu', 'ya-row'), ('よ', 'yo', 'ya-row'),
    ('ら', 'ra', 'ra-row'), ('り', 'ri', 'ra-row'), ('る', 'ru', 'ra-row'), ('れ', 're', 'ra-row'), ('ろ', 'ro', 'ra-row'),
    ('わ', 'wa', 'wa-row'), ('を', 'wo', 'wa-row'),
    ('ん', 'n', 'n-row'),
    # Dakuten / Handakuten (25)
    ('が', 'ga', 'dakuten'), ('ぎ', 'gi', 'dakuten'), ('ぐ', 'gu', 'dakuten'), ('げ', 'ge', 'dakuten'), ('ご', 'go', 'dakuten'),
    ('ざ', 'za', 'dakuten'), ('じ', 'ji', 'dakuten'), ('ず', 'zu', 'dakuten'), ('ぜ', 'ze', 'dakuten'), ('ぞ', 'zo', 'dakuten'),
    ('だ', 'da', 'dakuten'), ('ぢ', 'ji', 'dakuten'), ('づ', 'zu', 'dakuten'), ('で', 'de', 'dakuten'), ('ど', 'do', 'dakuten'),
    ('ば', 'ba', 'dakuten'), ('び', 'bi', 'dakuten'), ('ぶ', 'bu', 'dakuten'), ('べ', 'be', 'dakuten'), ('ぼ', 'bo', 'dakuten'),
    ('ぱ', 'pa', 'handakuten'), ('ぴ', 'pi', 'handakuten'), ('ぷ', 'pu', 'handakuten'), ('ぺ', 'pe', 'handakuten'), ('ぽ', 'po', 'handakuten'),
    # Small kana (4)
    ('っ', 'small tsu', 'small'), ('ゃ', 'small ya', 'small'), ('ゅ', 'small yu', 'small'), ('ょ', 'small yo', 'small'),
]

# Katakana definitions: (char, romaji, group)
KATAKANA_LIST = [
    # Basic Gojuon (46)
    ('ア', 'a', 'a-row'), ('イ', 'i', 'a-row'), ('ウ', 'u', 'a-row'), ('エ', 'e', 'a-row'), ('オ', 'o', 'a-row'),
    ('カ', 'ka', 'ka-row'), ('キ', 'ki', 'ka-row'), ('ク', 'ku', 'ka-row'), ('ケ', 'ke', 'ka-row'), ('コ', 'ko', 'ka-row'),
    ('サ', 'sa', 'sa-row'), ('シ', 'shi', 'sa-row'), ('ス', 'su', 'sa-row'), ('セ', 'se', 'sa-row'), ('ソ', 'so', 'sa-row'),
    ('タ', 'ta', 'ta-row'), ('チ', 'chi', 'ta-row'), ('ツ', 'tsu', 'ta-row'), ('テ', 'te', 'ta-row'), ('ト', 'to', 'ta-row'),
    ('ナ', 'na', 'na-row'), ('ニ', 'ni', 'na-row'), ('ヌ', 'nu', 'na-row'), ('ネ', 'ne', 'na-row'), ('ノ', 'no', 'na-row'),
    ('ハ', 'ha', 'ha-row'), ('ヒ', 'hi', 'ha-row'), ('フ', 'fu', 'ha-row'), ('ヘ', 'he', 'ha-row'), ('ホ', 'ho', 'ha-row'),
    ('マ', 'ma', 'ma-row'), ('ミ', 'mi', 'ma-row'), ('ム', 'mu', 'ma-row'), ('メ', 'me', 'ma-row'), ('モ', 'mo', 'ma-row'),
    ('ヤ', 'ya', 'ya-row'), ('ユ', 'yu', 'ya-row'), ('ヨ', 'yo', 'ya-row'),
    ('ラ', 'ra', 'ra-row'), ('リ', 'ri', 'ra-row'), ('ル', 'ru', 'ra-row'), ('レ', 're', 'ra-row'), ('ロ', 'ro', 'ra-row'),
    ('ワ', 'wa', 'wa-row'), ('ヲ', 'wo', 'wa-row'),
    ('ン', 'n', 'n-row'),
    # Dakuten / Handakuten (25)
    ('ガ', 'ga', 'dakuten'), ('ギ', 'gi', 'dakuten'), ('グ', 'gu', 'dakuten'), ('ゲ', 'ge', 'dakuten'), ('ゴ', 'go', 'dakuten'),
    ('ザ', 'za', 'dakuten'), ('ジ', 'ji', 'dakuten'), ('ズ', 'zu', 'dakuten'), ('ゼ', 'ze', 'dakuten'), ('ゾ', 'zo', 'dakuten'),
    ('ダ', 'da', 'dakuten'), ('ヂ', 'ji', 'dakuten'), ('ヅ', 'zu', 'dakuten'), ('デ', 'de', 'dakuten'), ('ド', 'do', 'dakuten'),
    ('バ', 'ba', 'dakuten'), ('ビ', 'bi', 'dakuten'), ('ブ', 'bu', 'dakuten'), ('ベ', 'be', 'dakuten'), ('ボ', 'bo', 'dakuten'),
    ('パ', 'pa', 'handakuten'), ('ピ', 'pi', 'handakuten'), ('プ', 'pu', 'handakuten'), ('ペ', 'pe', 'handakuten'), ('ポ', 'po', 'handakuten'),
    # Small / Extras
    ('ッ', 'small tsu', 'small'), ('ャ', 'small ya', 'small'), ('ュ', 'small yu', 'small'), ('ョ', 'small yo', 'small'),
    ('ー', 'chouonpu', 'small'),
]

def ensure_cache():
    os.makedirs(CACHE_DIR, exist_ok=True)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    zip_path = os.path.join(CACHE_DIR, "kanjivg-main.zip")
    if not os.path.exists(zip_path):
        print("Downloading KanjiVG archive...")
        resp = requests.get(KANJIVG_ZIP_URL, timeout=60)
        resp.raise_for_status()
        with open(zip_path, "wb") as f:
            f.write(resp.content)
        print(f"Saved {zip_path} ({len(resp.content)} bytes)")
    return zip_path

def resample_path(d_str, num_points=40):
    try:
        path = parse_path(d_str)
        sample_count = 150
        raw_pts = []
        for i in range(sample_count):
            t = i / (sample_count - 1)
            pt = path.point(t)
            raw_pts.append((pt.real, pt.imag))

        dists = [0.0]
        for i in range(1, len(raw_pts)):
            p1 = raw_pts[i-1]
            p2 = raw_pts[i]
            d = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
            dists.append(dists[-1] + d)

        total_len = dists[-1]
        if total_len < 1e-6:
            return [[round(raw_pts[0][0], 2), round(raw_pts[0][1], 2)]] * num_points

        step = total_len / (num_points - 1)
        resampled = [raw_pts[0]]
        curr_idx = 0

        for i in range(1, num_points - 1):
            target_d = i * step
            while curr_idx < len(dists) - 1 and dists[curr_idx + 1] < target_d:
                curr_idx += 1
            d0 = dists[curr_idx]
            d1 = dists[curr_idx + 1]
            seg_len = d1 - d0
            if seg_len > 1e-6:
                alpha = (target_d - d0) / seg_len
                x = raw_pts[curr_idx][0] + alpha * (raw_pts[curr_idx + 1][0] - raw_pts[curr_idx][0])
                y = raw_pts[curr_idx][1] + alpha * (raw_pts[curr_idx + 1][1] - raw_pts[curr_idx][1])
            else:
                x, y = raw_pts[curr_idx]
            resampled.append((x, y))

        resampled.append(raw_pts[-1])
        return [[round(x, 2), round(y, 2)] for x, y in resampled]
    except Exception as e:
        print(f"Error resampling path {d_str[:30]}...: {e}")
        return []

def extract_strokes_from_svg(svg_content):
    root = ET.fromstring(svg_content)
    # Find all path elements
    # Path IDs match pattern: kvg:codepoint-s<N>
    paths = []
    for elem in root.iter('{http://www.w3.org/2000/svg}path'):
        pid = elem.attrib.get('id', '')
        d = elem.attrib.get('d', '')
        m = re.search(r'-s(\d+)$', pid)
        if m and d:
            stroke_num = int(m.group(1))
            paths.append((stroke_num, d))
    
    # Sort strictly by stroke number (s1, s2, ...)
    paths.sort(key=lambda x: x[0])
    
    strokes = []
    for s_num, d in paths:
        pts = resample_path(d, num_points=40)
        strokes.append({
            "d": d,
            "pts": pts
        })
    return strokes

def fetch_kanji_details(char):
    cache_file = os.path.join(CACHE_DIR, f"kanji_{ord(char):05x}.json")
    if os.path.exists(cache_file):
        with open(cache_file, "r", encoding="utf-8") as f:
            return json.load(f)
    try:
        url = f"https://kanjiapi.dev/v1/kanji/{char}"
        resp = requests.get(url, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            with open(cache_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False)
            return data
    except Exception as e:
        print(f"Failed to fetch details for {char}: {e}")
    return {}

def process_kana_set(zf, kana_list, filename):
    results = []
    for char, romaji, group in kana_list:
        codepoint = f"{ord(char):05x}"
        svg_filename = f"kanji/{codepoint}.svg"
        if svg_filename not in zf.namelist():
            print(f"Warning: SVG not found for {char} ({codepoint})")
            continue
        svg_bytes = zf.read(svg_filename)
        strokes = extract_strokes_from_svg(svg_bytes)
        results.append({
            "char": char,
            "codepoint": codepoint,
            "romaji": romaji,
            "group": group,
            "strokeCount": len(strokes),
            "strokes": strokes
        })
    
    out_path = os.path.join(OUTPUT_DIR, filename)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, separators=(',', ':'))
    return results

def process_kanji_set(zf, kanji_list, filename, level):
    from concurrent.futures import ThreadPoolExecutor
    print(f"Fetching details and parsing SVG for {len(kanji_list)} kanji...")
    with ThreadPoolExecutor(max_workers=10) as executor:
        list(executor.map(fetch_kanji_details, kanji_list))

    results = []
    for char in kanji_list:
        codepoint = f"{ord(char):05x}"
        svg_filename = f"kanji/{codepoint}.svg"
        if svg_filename not in zf.namelist():
            print(f"Warning: SVG not found for {char} ({codepoint})")
            continue
        
        details = fetch_kanji_details(char)
        meaning = ", ".join(details.get("meanings", [])[:3]) if details.get("meanings") else ""
        on_readings = details.get("on_readings", [])
        kun_readings = details.get("kun_readings", [])
        
        svg_bytes = zf.read(svg_filename)
        strokes = extract_strokes_from_svg(svg_bytes)
        
        results.append({
            "char": char,
            "codepoint": codepoint,
            "level": level,
            "meaning": meaning,
            "on": on_readings,
            "kun": kun_readings,
            "strokeCount": len(strokes),
            "strokes": strokes
        })

    out_path = os.path.join(OUTPUT_DIR, filename)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, separators=(',', ':'))
    return results

def main():
    sys.stdout.reconfigure(encoding='utf-8')
    print("=== Kaku Data Builder ===")
    zip_path = ensure_cache()
    print(f"Reading KanjiVG from {zip_path}...")
    zf = zipfile.ZipFile(zip_path)

    print("\n1. Processing Hiragana...")
    hiragana = process_kana_set(zf, HIRAGANA_LIST, "hiragana.json")
    print(f"Hiragana: {len(hiragana)} characters")

    print("\n2. Processing Katakana...")
    katakana = process_kana_set(zf, KATAKANA_LIST, "katakana.json")
    print(f"Katakana: {len(katakana)} characters")

    print("\n3. Fetching JLPT Kanji list...")
    try:
        n5_list = requests.get("https://kanjiapi.dev/v1/kanji/jlpt-5", timeout=15).json()
        n4_list = requests.get("https://kanjiapi.dev/v1/kanji/jlpt-4", timeout=15).json()
    except Exception as e:
        print(f"Error fetching JLPT lists: {e}")
        n5_list = []
        n4_list = []

    print(f"\n4. Processing Kanji N5 ({len(n5_list)} kanji)...")
    kanji_n5 = process_kanji_set(zf, n5_list, "kanji_n5.json", "N5")
    print(f"Kanji N5: {len(kanji_n5)} characters")

    print(f"\n5. Processing Kanji N4 ({len(n4_list)} kanji)...")
    kanji_n4 = process_kanji_set(zf, n4_list, "kanji_n4.json", "N4")
    print(f"Kanji N4: {len(kanji_n4)} characters")

    print("\n=== Statistics ===")
    total_chars = len(hiragana) + len(katakana) + len(kanji_n5) + len(kanji_n4)
    total_strokes = sum(c["strokeCount"] for c in hiragana + katakana + kanji_n5 + kanji_n4)
    
    files = ["hiragana.json", "katakana.json", "kanji_n5.json", "kanji_n4.json"]
    total_size = 0
    for fn in files:
        fp = os.path.join(OUTPUT_DIR, fn)
        sz = os.path.getsize(fp) if os.path.exists(fp) else 0
        total_size += sz
        print(f"  {fn:16s}: {sz / 1024:.1f} KB")

    print(f"Total Characters: {total_chars}")
    print(f"Total Strokes   : {total_strokes}")
    print(f"Total Data Size : {total_size / (1024 * 1024):.2f} MB")
    print("Done!")

if __name__ == "__main__":
    main()
