#!/usr/bin/env python3
"""
Generates high-resolution app icon for Kaku (書く).
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_app_icon():
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Background: Rounded rect with vibrant Japanese Crimson Gradient
    # Gradient from #D32F2F to #7F0000
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    for y in range(size):
        ratio = y / size
        r = int(211 * (1 - ratio) + 120 * ratio)
        g = int(47 * (1 - ratio) + 10 * ratio)
        b = int(47 * (1 - ratio) + 20 * ratio)
        bg_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Mask for squircle / rounded rectangle
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = 220
    mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=corner_radius, fill=255)

    img.paste(bg, (0, 0), mask)
    draw = ImageDraw.Draw(img)

    # 2. Subtle calligraphy grid guidelines (Watermark style)
    grid_color = (255, 255, 255, 28)
    center = size // 2
    # Center cross
    draw.line([(center, 120), (center, size - 120)], fill=grid_color, width=4)
    draw.line([(120, center), (size - 120, center)], fill=grid_color, width=4)
    # Diagonals
    draw.line([(180, 180), (size - 180, size - 180)], fill=grid_color, width=3)
    draw.line([(180, size - 180), (size - 180, 180)], fill=grid_color, width=3)
    # Inner subtle square
    draw.rounded_rectangle([(160, 160), (size - 160, size - 160)], radius=60, outline=grid_color, width=3)

    # 3. Soft drop shadow for character
    font_path = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "NotoSansJP-Regular.ttf")
    font_size = 520
    font = ImageFont.truetype(font_path, font_size)

    char = "書"
    bbox = font.getbbox(char)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = (size - w) // 2 - bbox[0]
    y = (size - h) // 2 - bbox[1] - 40

    # Draw Shadow layer
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_layer)
    s_draw.text((x + 8, y + 16), char, font=font, fill=(0, 0, 0, 90))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img, shadow_layer)

    draw = ImageDraw.Draw(img)

    # 4. Main Character: "書" in crisp white
    draw.text((x, y), char, font=font, fill=(255, 255, 255, 255))

    # 5. Bottom Label: "KAKU" in modern geometric sans-serif
    try:
        sub_font_size = 80
        sub_font = ImageFont.truetype("arial.ttf", sub_font_size)
    except:
        sub_font = font

    sub_text = "KAKU"
    sub_bbox = sub_font.getbbox(sub_text)
    sub_w = sub_bbox[2] - sub_bbox[0]
    sub_x = (size - sub_w) // 2 - sub_bbox[0]
    sub_y = size - 190

    # Pill background for "KAKU"
    pill_padding_x = 36
    pill_padding_y = 10
    pill_box = [
        (sub_x - pill_padding_x, sub_y - pill_padding_y),
        (sub_x + sub_w + pill_padding_x, sub_y + (sub_bbox[3] - sub_bbox[1]) + pill_padding_y + 8)
    ]
    draw.rounded_rectangle(pill_box, radius=24, fill=(0, 0, 0, 60))
    draw.text((sub_x, sub_y), sub_text, font=sub_font, fill=(255, 255, 255, 240))

    # Save output
    icon_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    os.makedirs(icon_dir, exist_ok=True)
    out_path = os.path.join(icon_dir, "app_icon.png")
    img.save(out_path, "PNG")
    print(f"Generated master app icon: {out_path} ({size}x{size})")

    # Generate adaptive foreground (padded)
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Scale down by 0.72 for Android adaptive safe zone
    fg_scaled = img.resize((int(size * 0.76), int(size * 0.76)), Image.Resampling.LANCZOS)
    offset = (size - fg_scaled.width) // 2
    fg.paste(fg_scaled, (offset, offset), fg_scaled)
    fg_path = os.path.join(icon_dir, "app_icon_foreground.png")
    fg.save(fg_path, "PNG")
    print(f"Generated adaptive foreground icon: {fg_path}")

if __name__ == "__main__":
    create_app_icon()
