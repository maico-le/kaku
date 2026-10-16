#!/usr/bin/env python3
"""
tools/generate_3d_fuji_icon.py
Generates a stunning 1:1 phone app icon featuring a stylized 3D animation Mount Fuji.
Designed specifically for mobile app icons (high legibility at small sizes, bold shapes,
cute 3D clay / glossy aesthetic).
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def create_3d_fuji_app_icon(size=1024):
    print(f"Generating 3D Animation Mount Fuji Phone App Icon ({size}x{size})...")

    # 1. Base Image
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Background gradient: Sunset Purple -> Warm Coral Orange -> Sunny Cream Gold
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    
    top_color = (68, 44, 98)       # Twilight purple
    mid_color = (225, 95, 110)     # Japanese coral rose
    bot_color = (255, 185, 120)    # Warm morning gold

    for y in range(size):
        ratio = y / size
        if ratio < 0.55:
            t = ratio / 0.55
            r = int(top_color[0] * (1 - t) + mid_color[0] * t)
            g = int(top_color[1] * (1 - t) + mid_color[1] * t)
            b = int(top_color[2] * (1 - t) + mid_color[2] * t)
        else:
            t = (ratio - 0.55) / 0.45
            r = int(mid_color[0] * (1 - t) + bot_color[0] * t)
            g = int(mid_color[1] * (1 - t) + bot_color[1] * t)
            b = int(mid_color[2] * (1 - t) + bot_color[2] * t)
        bg_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Squircle mask for app icon
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = 230
    mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=corner_radius, fill=255)

    img.paste(bg, (0, 0), mask)
    draw = ImageDraw.Draw(img)

    # 2. Giant Glowing 3D Sun in the Background
    sun_cx = size // 2
    sun_cy = int(size * 0.40)
    sun_r = int(size * 0.28)

    # Sun Soft Glow
    sun_glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sg_draw = ImageDraw.Draw(sun_glow)
    sg_draw.ellipse(
        [(sun_cx - sun_r - 55, sun_cy - sun_r - 55),
         (sun_cx + sun_r + 55, sun_cy + sun_r + 55)],
        fill=(255, 230, 160, 140)
    )
    sun_glow = sun_glow.filter(ImageFilter.GaussianBlur(35))
    img.paste(sun_glow, (0, 0), sun_glow)

    # 3D Glossy Sun Disc
    sun_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(sun_img)
    # Sun body: Gradient from rich red-orange to bright golden yellow
    for sy in range(sun_cy - sun_r, sun_cy + sun_r):
        dy = sy - sun_cy
        half_w = int(math.sqrt(max(0, sun_r**2 - dy**2)))
        ratio = (sy - (sun_cy - sun_r)) / (sun_r * 2)
        sr = int(245 * (1 - ratio) + 255 * ratio)
        sg = int(65 * (1 - ratio) + 215 * ratio)
        sb = int(60 * (1 - ratio) + 110 * ratio)
        s_draw.line([(sun_cx - half_w, sy), (sun_cx + half_w, sy)], fill=(sr, sg, sb, 255))
    
    # Sun top shine
    s_draw.ellipse(
        [(sun_cx - sun_r * 0.65, sun_cy - sun_r * 0.85),
         (sun_cx + sun_r * 0.65, sun_cy - sun_r * 0.15)],
        fill=(255, 255, 240, 100)
    )
    img.paste(sun_img, (0, 0), sun_img)

    # 3. 3D Mountain Fuji Body
    # We render the 3D cone with smooth shading, specular highlight and warm rim lighting
    mountain_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    m_draw = ImageDraw.Draw(mountain_layer)

    fuji_cx = size / 2.0
    fuji_top_y = size * 0.28
    fuji_bot_y = size * 0.84
    top_w = size * 0.10
    bot_w = size * 0.44

    # Drop Shadow under Mount Fuji
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(shadow_layer)
    sh_draw.ellipse(
        [(fuji_cx - bot_w - 40, fuji_bot_y - 30),
         (fuji_cx + bot_w + 40, fuji_bot_y + 70)],
        fill=(25, 15, 40, 160)
    )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(28))
    img.paste(shadow_layer, (0, 0), shadow_layer)

    # Generate 3D Mountain Mesh / Raster
    y_coords, x_coords = np.mgrid[0:size, 0:size].astype(np.float32)
    dy = np.clip((y_coords - fuji_top_y) / (fuji_bot_y - fuji_top_y), 0.0, 1.0)
    
    # Gentle quadratic curve for iconic Fuji silhouette
    curve_w = top_w + (bot_w - top_w) * (dy ** 1.32)
    dx = np.abs(x_coords - fuji_cx)
    is_mountain = (y_coords >= fuji_top_y) & (y_coords <= fuji_bot_y) & (dx <= curve_w)

    # 3D Normal Shading
    # Light from top-left (classic 3D clay / icon lighting)
    nx = (x_coords - fuji_cx) / np.maximum(curve_w, 1.0)
    ny = -0.55
    nz = np.sqrt(np.maximum(0.02, 1.0 - nx**2))

    light_dir = np.array([-0.45, -0.65, 0.60], dtype=np.float32)
    light_dir /= np.linalg.norm(light_dir)

    diffuse = np.maximum(0.20, nx * light_dir[0] + ny * light_dir[1] + nz * light_dir[2])
    specular = np.maximum(0.0, nx * light_dir[0] + ny * light_dir[1] + nz * light_dir[2]) ** 8.0
    rim_light = np.clip((1.0 - nz) ** 2.0, 0.0, 1.0)

    # Mountain Body Color: Deep Indigo Navy (#2B3A67) with vibrant rim
    c_mtn_shadow = np.array([32, 42, 75], dtype=np.float32)
    c_mtn_lit = np.array([88, 108, 168], dtype=np.float32)
    mtn_rgb = (1.0 - diffuse[:, :, None]) * c_mtn_shadow + diffuse[:, :, None] * c_mtn_lit
    # Warm rim light on edges
    mtn_rgb += rim_light[:, :, None] * np.array([255, 170, 130], dtype=np.float32) * 0.45

    # 4. 3D Snow Cap (Cute fluffy serrated snow)
    snow_base_y = fuji_top_y + (fuji_bot_y - fuji_top_y) * 0.38
    # Scalloped snow drips
    drips = np.sin((x_coords - fuji_cx) * 0.04) * 22.0 + np.sin((x_coords - fuji_cx) * 0.10) * 12.0
    is_snow = is_mountain & (y_coords < (snow_base_y + drips))

    # Snow 3D Color: Soft pure white with lavender-blue ambient shadow and glossy highlight
    c_snow_shadow = np.array([210, 218, 245], dtype=np.float32)
    c_snow_lit = np.array([255, 255, 255], dtype=np.float32)
    snow_rgb = (1.0 - diffuse[:, :, None]) * c_snow_shadow + diffuse[:, :, None] * c_snow_lit
    # Glossy 3D shine
    snow_rgb += specular[:, :, None] * np.array([255, 255, 255], dtype=np.float32) * 0.65

    # Combine Mountain + Snow
    combined_mtn = np.where(is_snow[:, :, None], snow_rgb, mtn_rgb)
    
    # Anti-aliasing edge
    edge = np.clip((curve_w - dx) / 1.8, 0.0, 1.0) * ((y_coords >= fuji_top_y) & (y_coords <= fuji_bot_y))
    combined_mtn_img = Image.fromarray(np.clip(combined_mtn, 0, 255).astype(np.uint8), "RGB")
    
    alpha_mask = Image.fromarray((edge * 255).astype(np.uint8), "L")
    img.paste(combined_mtn_img, (0, 0), alpha_mask)

    # 5. Stylized 3D Fluffy Cloud Wrapping Around Mount Fuji (3D Torus Cloud)
    cloud_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(cloud_img)

    def draw_3d_sphere(cx, cy, r, base_rgb=(255, 255, 255), shadow_rgb=(185, 180, 215)):
        # Shadow bottom
        c_draw.ellipse(
            [(cx - r, cy - r + 8), (cx + r, cy + r + 8)],
            fill=(shadow_rgb[0], shadow_rgb[1], shadow_rgb[2], 240)
        )
        # Main sphere
        c_draw.ellipse(
            [(cx - r, cy - r), (cx + r, cy + r)],
            fill=(base_rgb[0], base_rgb[1], base_rgb[2], 255)
        )
        # Specular shine top-left
        c_draw.ellipse(
            [(cx - r * 0.65, cy - r * 0.8), (cx + r * 0.35, cy + r * 0.1)],
            fill=(255, 255, 255, 200)
        )

    # Cloud belt floating across lower-middle of the mountain
    cloud_cy = int(size * 0.58)
    puffs = [
        (fuji_cx - 240, cloud_cy + 15, 62),
        (fuji_cx - 170, cloud_cy - 8, 78),
        (fuji_cx - 95,  cloud_cy + 5, 85),
        (fuji_cx,       cloud_cy - 12, 92),
        (fuji_cx + 95,  cloud_cy + 5, 85),
        (fuji_cx + 170, cloud_cy - 8, 78),
        (fuji_cx + 240, cloud_cy + 15, 62),
    ]

    for cx, cy, r in puffs:
        draw_3d_sphere(cx, cy, r)

    # Cloud drop shadow on mountain
    cloud_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(cloud_shadow)
    for cx, cy, r in puffs:
        cs_draw.ellipse([(cx - r, cy - r + 24), (cx + r, cy + r + 24)], fill=(0, 0, 0, 75))
    cloud_shadow = cloud_shadow.filter(ImageFilter.GaussianBlur(16))
    img.paste(cloud_shadow, (0, 0), cloud_shadow)
    img.paste(cloud_img, (0, 0), cloud_img)

    # 6. Foreground 3D Cherry Blossom (Sakura) Badge at Bottom Corner
    sakura_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sk_draw = ImageDraw.Draw(sakura_img)

    def draw_3d_petal(cx, cy, angle, length, width, color=(255, 175, 200)):
        # Compute rotated petal points
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        
        # Center of petal
        px = cx + cos_a * length * 0.55
        py = cy + sin_a * length * 0.55

        # Petal ellipse
        x0 = px - width / 2
        y0 = py - length / 2
        x1 = px + width / 2
        y1 = py + length / 2
        sk_draw.ellipse([(x0, y0), (x1, y1)], fill=color)

    # Cute 3D 5-Petal Sakura Flower in bottom-right corner
    flower_x = int(size * 0.76)
    flower_y = int(size * 0.76)
    f_rad = 68

    # Flower drop shadow
    sk_draw.ellipse(
        [(flower_x - f_rad - 6, flower_y - f_rad + 8),
         (flower_x + f_rad + 6, flower_y + f_rad + 20)],
        fill=(30, 20, 50, 95)
    )

    # 5 Petals
    for i in range(5):
        angle = (i * 72 - 18) * (math.pi / 180.0)
        px = flower_x + math.cos(angle) * (f_rad * 0.65)
        py = flower_y + math.sin(angle) * (f_rad * 0.65)
        
        # Petal shadow
        sk_draw.ellipse(
            [(px - 34, py - 34 + 4), (px + 34, py + 34 + 4)],
            fill=(220, 110, 150, 255)
        )
        # Petal main
        sk_draw.ellipse(
            [(px - 34, py - 34), (px + 34, py + 34)],
            fill=(255, 192, 215, 255)
        )
        # Petal highlight
        sk_draw.ellipse(
            [(px - 20, py - 26), (px + 14, py)],
            fill=(255, 235, 245, 220)
        )

    # Center flower pistil (golden 3D bead)
    draw_3d_sphere(flower_x, flower_y, 22, (255, 225, 100), (220, 160, 40))

    # A couple of flying cute 3D petals
    for p_offset in [(-85, -60, 18), (55, -80, 14), (-140, -15, 16)]:
        ox, oy, pr = p_offset
        px = flower_x + ox
        py = flower_y + oy
        sk_draw.ellipse([(px - pr, py - pr*0.7), (px + pr, py + pr*0.7)], fill=(255, 195, 220, 240))
        sk_draw.ellipse([(px - pr*0.5, py - pr*0.6), (px + pr*0.2, py - pr*0.1)], fill=(255, 240, 248, 220))

    img.paste(sakura_img, (0, 0), sakura_img)

    # 7. Subtle 3D Glass / Gloss Bevel Reflection across the App Icon
    bevel = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bevel)
    # Diagonal glass gloss curve
    gloss_pts = [
        (0, 0), (size, 0), (size, int(size * 0.28)),
        (0, int(size * 0.62))
    ]
    b_draw.polygon(gloss_pts, fill=(255, 255, 255, 32))
    
    # Inner border / rim light
    b_draw.rounded_rectangle(
        [(2, 2), (size - 2, size - 2)],
        radius=corner_radius,
        outline=(255, 255, 255, 50),
        width=4
    )
    bevel = bevel.filter(ImageFilter.GaussianBlur(1.5))
    
    # Mask to keep inside squircle
    final_icon = Image.composite(Image.alpha_composite(img, bevel), Image.new("RGBA", (size, size), (0,0,0,0)), mask)

    # Save Master Icon
    icon_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    os.makedirs(icon_dir, exist_ok=True)
    out_master = os.path.join(icon_dir, "app_icon.png")
    final_icon.save(out_master, "PNG")
    print(f"Saved Master 3D Fuji App Icon: {out_master}")

    # Generate Android Adaptive Foreground (padded 76% to prevent clipping in squircle / circle launchers)
    fg_canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    scaled_w = int(size * 0.74)
    scaled_h = int(size * 0.74)
    scaled_icon = final_icon.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    offset = (size - scaled_w) // 2
    fg_canvas.paste(scaled_icon, (offset, offset), scaled_icon)
    
    out_fg = os.path.join(icon_dir, "app_icon_foreground.png")
    fg_canvas.save(out_fg, "PNG")
    print(f"Saved Adaptive Foreground: {out_fg}")

    return out_master

if __name__ == "__main__":
    create_3d_fuji_app_icon()
