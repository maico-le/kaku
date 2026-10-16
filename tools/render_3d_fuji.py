#!/usr/bin/env python3
"""
tools/render_3d_fuji.py
Generates a stunning, high-resolution 3D animation style digital render of Mount Fuji.
Stylized 3D Anime / Pixar aesthetic:
- 3D conical mountain geometry with snow cap & directional lighting
- Dreamy pastel sunrise/sunset sky with giant sun
- 3D volumetric puffy clouds
- Floating Torii gate on reflective water
- 3D stylized cherry blossom (sakura) trees with drifting petals
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0 + 1e-7), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def render_3d_mount_fuji(width=1920, height=1080):
    print(f"Rendering 3D Animation Mount Fuji ({width}x{height})...")

    # Coordinate grids
    y_idx, x_idx = np.mgrid[0:height, 0:width].astype(np.float32)
    u = x_idx / (width - 1)          # 0..1 horizontal
    v = y_idx / (height - 1)         # 0..1 vertical (0 top, 1 bottom)

    # -------------------------------------------------------------
    # 1. Sky Gradient (Stylized Anime Pastel Sunrise/Sunset)
    # -------------------------------------------------------------
    # Deep purple at top -> Pink peach -> Warm gold at horizon (around v = 0.58)
    sky_v = np.clip(v / 0.58, 0.0, 1.0)
    
    # Color stops
    c_top = np.array([55, 30, 85], dtype=np.float32)      # Deep twilight violet
    c_mid = np.array([215, 95, 130], dtype=np.float32)    # Sunset magenta-pink
    c_warm = np.array([255, 145, 105], dtype=np.float32)  # Coral peach
    c_horizon = np.array([255, 210, 140], dtype=np.float32) # Golden dawn

    sky_rgb = np.zeros((height, width, 3), dtype=np.float32)
    mask1 = sky_v < 0.4
    t1 = sky_v / 0.4
    sky_rgb[mask1] = (1.0 - t1[mask1, None]) * c_top + t1[mask1, None] * c_mid

    mask2 = (sky_v >= 0.4) & (sky_v < 0.75)
    t2 = (sky_v - 0.4) / 0.35
    sky_rgb[mask2] = (1.0 - t2[mask2, None]) * c_mid + t2[mask2, None] * c_warm

    mask3 = sky_v >= 0.75
    t3 = (sky_v - 0.75) / 0.25
    sky_rgb[mask3] = (1.0 - t3[mask3, None]) * c_warm + t3[mask3, None] * c_horizon

    # -------------------------------------------------------------
    # 2. Giant Stylized 3D Sun & Atmospheric Glow
    # -------------------------------------------------------------
    sun_cx = width * 0.50
    sun_cy = height * 0.42
    sun_r = 135.0

    dist_sun = np.hypot(x_idx - sun_cx, y_idx - sun_cy)
    sun_glow = np.exp(-dist_sun / 220.0)
    sky_rgb += sun_glow[:, :, None] * np.array([255, 180, 120], dtype=np.float32) * 0.55

    # Crisp stylized sun disc with soft rim
    sun_edge = smoothstep(sun_r + 2.0, sun_r - 2.0, dist_sun)
    sun_core_color = np.array([255, 245, 230], dtype=np.float32)
    sky_rgb = sky_rgb * (1.0 - sun_edge[:, :, None]) + sun_core_color * sun_edge[:, :, None]

    # -------------------------------------------------------------
    # 3. Mount Fuji 3D Surface & Lighting
    # -------------------------------------------------------------
    fuji_cx = width * 0.50
    peak_y = height * 0.21
    base_y = height * 0.58
    peak_half_w = width * 0.055
    base_half_w = width * 0.38

    # Parametric mountain profile with natural curved slope
    dy = np.clip((y_idx - peak_y) / (base_y - peak_y), 0.0, 1.0)
    curve_factor = dy ** 1.35
    mountain_half_width = peak_half_w + (base_half_w - peak_half_w) * curve_factor

    dx = np.abs(x_idx - fuji_cx)
    is_fuji = (y_idx >= peak_y) & (y_idx <= base_y) & (dx <= mountain_half_width)

    # 3D Normal computation
    # X normal is proportional to distance from center line
    norm_x = (x_idx - fuji_cx) / np.maximum(mountain_half_width, 1.0)
    norm_y = -0.55 # Angled slope
    norm_z = np.sqrt(np.maximum(0.01, 1.0 - norm_x**2))
    
    # Light direction: sun is slightly from top-right & front
    light_dir = np.array([-0.35, -0.6, 0.7], dtype=np.float32)
    light_dir /= np.linalg.norm(light_dir)

    diffuse = np.maximum(0.15, norm_x * light_dir[0] + norm_y * light_dir[1] + norm_z * light_dir[2])
    # Rim light from sunset horizon
    rim = np.clip((1.0 - norm_z) ** 2.2, 0.0, 1.0)

    # Mountain base colors (3D stylized deep slate blue / indigo with warm sunset tint)
    fuji_base_dark = np.array([45, 48, 85], dtype=np.float32)
    fuji_base_light = np.array([125, 95, 145], dtype=np.float32)
    fuji_body = (1.0 - diffuse[:, :, None]) * fuji_base_dark + diffuse[:, :, None] * fuji_base_light
    fuji_body += rim[:, :, None] * np.array([255, 175, 140], dtype=np.float32) * 0.45

    # 3D Snow Cap on Mount Fuji
    # Procedural snow serration lines running down the ridges
    snow_line_y = peak_y + (base_y - peak_y) * 0.38
    ridge_noise = np.sin((x_idx - fuji_cx) * 0.035) * 18.0 + np.sin((x_idx - fuji_cx) * 0.08) * 10.0
    is_snow = is_fuji & (y_idx < (snow_line_y + ridge_noise))

    snow_shadow = np.array([215, 218, 240], dtype=np.float32)
    snow_light = np.array([255, 252, 255], dtype=np.float32)
    snow_color = (1.0 - diffuse[:, :, None]) * snow_shadow + diffuse[:, :, None] * snow_light
    # Warm sunlight sheen on snow
    snow_color += diffuse[:, :, None] * np.array([255, 230, 200], dtype=np.float32) * 0.25

    # Composite Fuji
    fuji_pixel = np.where(is_snow[:, :, None], snow_color, fuji_body)
    
    # Soft anti-aliased edge for mountain
    edge_dist = mountain_half_width - dx
    fuji_alpha = np.clip(edge_dist / 2.0, 0.0, 1.0) * ((y_idx >= peak_y) & (y_idx <= base_y))

    img_rgb = sky_rgb * (1.0 - fuji_alpha[:, :, None]) + fuji_pixel * fuji_alpha[:, :, None]

    # Convert to PIL Image for high-level stylized 3D layers (Clouds, Hills, Trees, Torii, Lake)
    img = Image.fromarray(np.clip(img_rgb, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(img, "RGBA")

    # -------------------------------------------------------------
    # 4. Stylized 3D Fluffy Clouds (Volumetric Anime Puffs)
    # -------------------------------------------------------------
    cloud_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(cloud_layer)

    def draw_3d_cloud(center_x, center_y, scale_factor=1.0, base_color=(255, 240, 245, 235)):
        # Cluster of overlapping shaded 3D spheres
        spheres = [
            (0, 0, 48), (-45, 12, 38), (45, 10, 42),
            (-80, 22, 30), (80, 20, 32), (0, -22, 42),
            (-25, -15, 36), (28, -12, 38)
        ]
        for ox, oy, r in spheres:
            cx = center_x + ox * scale_factor
            cy = center_y + oy * scale_factor
            cr = r * scale_factor

            # Shadow bottom
            c_draw.ellipse(
                [(cx - cr, cy - cr + 6), (cx + cr, cy + cr + 6)],
                fill=(190, 150, 185, 160)
            )
            # Main body
            c_draw.ellipse(
                [(cx - cr, cy - cr), (cx + cr, cy + cr)],
                fill=base_color
            )
            # Top highlight (sunlit rim)
            c_draw.ellipse(
                [(cx - cr*0.75, cy - cr*0.9), (cx + cr*0.75, cy + cr*0.1)],
                fill=(255, 255, 255, 180)
            )

    # Place dreamy clouds
    draw_3d_cloud(width * 0.22, height * 0.38, 1.25)
    draw_3d_cloud(width * 0.82, height * 0.35, 1.4)
    draw_3d_cloud(width * 0.38, height * 0.48, 0.95)
    draw_3d_cloud(width * 0.65, height * 0.49, 1.1)

    cloud_layer = cloud_layer.filter(ImageFilter.GaussianBlur(1.8))
    img.paste(cloud_layer, (0, 0), cloud_layer)

    # -------------------------------------------------------------
    # 5. Distant Rolling Green & Indigo Hills
    # -------------------------------------------------------------
    hill_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(hill_layer)

    # Midground hill 1 (Left)
    pts_hill_left = [(0, base_y)]
    for px in range(0, int(width * 0.52), 20):
        py = base_y - 45 * math.sin(px / (width * 0.5) * math.pi) - 20
        pts_hill_left.append((px, py))
    pts_hill_left.extend([(width * 0.52, height), (0, height)])
    h_draw.polygon(pts_hill_left, fill=(40, 58, 88, 245))

    # Midground hill 2 (Right)
    pts_hill_right = [(int(width * 0.48), height)]
    for px in range(int(width * 0.48), width + 20, 20):
        py = base_y - 65 * math.sin((px - width*0.48) / (width * 0.52) * math.pi) - 15
        pts_hill_right.append((px, py))
    pts_hill_right.extend([(width, height), (int(width * 0.48), height)])
    h_draw.polygon(pts_hill_right, fill=(32, 50, 78, 255))

    # Foreground rolling hill (Warm green-teal moss)
    fg_hill = [(0, height * 0.64)]
    for px in range(0, int(width * 0.45), 20):
        py = height * 0.64 - 35 * math.sin(px / (width * 0.45) * math.pi)
        fg_hill.append((px, py))
    fg_hill.extend([(int(width * 0.45), height), (0, height)])
    h_draw.polygon(fg_hill, fill=(28, 65, 72, 255))

    img.paste(hill_layer, (0, 0), hill_layer)

    # -------------------------------------------------------------
    # 6. Reflective Lake Kawaguchi with Glossy 3D Water Waves
    # -------------------------------------------------------------
    water_y = int(height * 0.58)
    lake_box = (0, water_y, width, height)
    
    # Extract sky & mountain reflection
    reflected = img.crop((0, 0, width, water_y)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    reflected = reflected.resize((width, height - water_y), Image.Resampling.LANCZOS)
    
    # Apply water distortion and tint
    refl_np = np.array(reflected, dtype=np.float32)
    refl_v = np.linspace(0.0, 1.0, height - water_y)[:, None, None]
    
    # Water color: Deep sapphire blue fading to turquoise cyan
    water_deep = np.array([20, 42, 75], dtype=np.float32)
    water_near = np.array([35, 75, 105], dtype=np.float32)
    water_base = (1.0 - refl_v) * water_deep + refl_v * water_near

    # Blend reflection with water depth
    final_water = refl_np * 0.48 + water_base * 0.52

    # Add 3D horizontal water wave ripples
    w_h, w_w, _ = final_water.shape
    wy, wx = np.mgrid[0:w_h, 0:w_w]
    ripple = np.sin(wy * 0.35 + np.sin(wx * 0.05) * 3.0) * np.sin(wy * 0.12)
    ripple_mask = np.clip(ripple * 0.5 + 0.5, 0.0, 1.0)[:, :, None]
    
    # Golden sunset sparkles on water ripples
    sun_col_mask = np.exp(-((wx - sun_cx) / 160.0)**2)[:, :, None]
    sparkle = ripple_mask * sun_col_mask * np.array([255, 220, 160], dtype=np.float32) * 0.35
    final_water += sparkle

    water_img = Image.fromarray(np.clip(final_water, 0, 255).astype(np.uint8), "RGB")
    img.paste(water_img, (0, water_y))

    draw = ImageDraw.Draw(img, "RGBA")

    # -------------------------------------------------------------
    # 7. Iconic 3D Red Floating Torii Gate
    # -------------------------------------------------------------
    torii_x = width * 0.50
    torii_y = height * 0.69
    torii_w = 90
    torii_h = 105

    torii_red = (225, 45, 35, 255)
    torii_shadow = (145, 20, 15, 255)
    torii_top_black = (30, 25, 30, 255)

    # Torii Reflection in water
    draw.polygon([
        (torii_x - torii_w * 0.45, torii_y + 4),
        (torii_x + torii_w * 0.45, torii_y + 4),
        (torii_x + torii_w * 0.35, torii_y + torii_h * 0.5),
        (torii_x - torii_w * 0.35, torii_y + torii_h * 0.5),
    ], fill=(160, 30, 25, 120))

    # Two main pillars (with 3D cylinder lighting)
    pw = 11
    col_l = torii_x - torii_w * 0.38
    col_r = torii_x + torii_w * 0.38
    
    # Left pillar
    draw.rounded_rectangle([(col_l - pw/2, torii_y - torii_h), (col_l + pw/2, torii_y)], radius=4, fill=torii_red)
    draw.rectangle([(col_l + 1, torii_y - torii_h), (col_l + pw/2, torii_y)], fill=torii_shadow)
    # Right pillar
    draw.rounded_rectangle([(col_r - pw/2, torii_y - torii_h), (col_r + pw/2, torii_y)], radius=4, fill=torii_red)
    draw.rectangle([(col_r + 1, torii_y - torii_h), (col_r + pw/2, torii_y)], fill=torii_shadow)

    # Lower crossbeam (Nuki)
    draw.rounded_rectangle([(col_l - 12, torii_y - torii_h * 0.72), (col_r + 12, torii_y - torii_h * 0.72 + 8)], radius=2, fill=torii_red)
    # Upper curved roof beam (Kasagi) with classic Japanese upturned ends
    roof_pts = [
        (torii_x - torii_w * 0.65, torii_y - torii_h * 1.05 - 6),
        (torii_x, torii_y - torii_h * 1.05),
        (torii_x + torii_w * 0.65, torii_y - torii_h * 1.05 - 6),
        (torii_x + torii_w * 0.62, torii_y - torii_h * 1.05 + 8),
        (torii_x, torii_y - torii_h * 1.05 + 10),
        (torii_x - torii_w * 0.62, torii_y - torii_h * 1.05 + 8),
    ]
    draw.polygon(roof_pts, fill=torii_top_black)

    # -------------------------------------------------------------
    # 8. Stylized 3D Cherry Blossom (Sakura) Trees & Petals
    # -------------------------------------------------------------
    sakura_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(sakura_layer)

    def draw_3d_sakura_cluster(cx, cy, radius, base_pink=(255, 175, 195)):
        # 3D shaded puff of blossoms
        # Ambient shadow
        s_draw.ellipse(
            [(cx - radius, cy - radius + 4), (cx + radius, cy + radius + 4)],
            fill=(base_pink[0] - 50, base_pink[1] - 40, base_pink[2] - 30, 230)
        )
        # Main sphere
        s_draw.ellipse(
            [(cx - radius, cy - radius), (cx + radius, cy + radius)],
            fill=(base_pink[0], base_pink[1], base_pink[2], 255)
        )
        # Highlight top
        s_draw.ellipse(
            [(cx - radius*0.65, cy - radius*0.8), (cx + radius*0.65, cy - radius*0.1)],
            fill=(255, 235, 245, 240)
        )

    # Left Foreground Sakura Branch & Clusters
    branch_pts = [
        (0, height * 0.68), (width * 0.08, height * 0.60),
        (width * 0.16, height * 0.52), (width * 0.24, height * 0.44),
        (width * 0.32, height * 0.40)
    ]
    s_draw.line(branch_pts, fill=(55, 38, 35, 255), width=14)

    # Fluffy 3D Blossom clusters along the branch
    clusters = [
        (width * 0.05, height * 0.64, 52),
        (width * 0.10, height * 0.56, 64),
        (width * 0.16, height * 0.48, 70),
        (width * 0.22, height * 0.42, 60),
        (width * 0.28, height * 0.37, 50),
        (width * 0.34, height * 0.38, 42),
        # Extra framing clusters on the top right
        (width * 0.88, height * 0.08, 65),
        (width * 0.94, height * 0.14, 75),
        (width * 0.82, height * 0.12, 55),
        (width * 0.90, height * 0.20, 60),
    ]

    for cx, cy, rad in clusters:
        draw_3d_sakura_cluster(cx, cy, rad)
        draw_3d_sakura_cluster(cx + rad * 0.4, cy - rad * 0.2, rad * 0.7, (255, 205, 220))
        draw_3d_sakura_cluster(cx - rad * 0.3, cy + rad * 0.2, rad * 0.65, (245, 150, 180))

    # Drifting 3D Sakura Petals in the wind
    np.random.seed(42)
    num_petals = 75
    for _ in range(num_petals):
        px = np.random.uniform(width * 0.15, width * 0.85)
        py = np.random.uniform(height * 0.35, height * 0.90)
        p_len = np.random.uniform(6.0, 14.0)
        p_angle = np.random.uniform(-math.pi / 4, math.pi / 4)
        
        # Rotated oval petal
        p_dx = math.cos(p_angle) * p_len
        p_dy = math.sin(p_angle) * p_len * 0.55
        
        x0 = min(px - p_dx, px + p_dx)
        x1 = max(px - p_dx, px + p_dx)
        y0 = min(py - p_dy, py + p_dy)
        y1 = max(py - p_dy, py + p_dy)
        
        s_draw.ellipse(
            [(x0, y0), (x1, y1)],
            fill=(255, int(np.random.randint(180, 220)), int(np.random.randint(200, 235)), int(np.random.randint(210, 255)))
        )

    img.paste(sakura_layer, (0, 0), sakura_layer)

    # -------------------------------------------------------------
    # 9. Cinematic Vignette & Warm 3D Glow
    # -------------------------------------------------------------
    vignette = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vignette)
    
    # Soft cinema border
    v_draw.rectangle([(0, 0), (width, height)], outline=(35, 20, 50, 120), width=6)

    img = Image.alpha_composite(img.convert("RGBA"), vignette).convert("RGB")

    # Output path
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "images")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "mount_fuji_3d_animation.png")
    
    img.save(out_path, "PNG", quality=98)
    print(f"Generated 3D Animation Mount Fuji: {out_path}")

    # Also save a 1080p JPEG version
    jpg_path = os.path.join(out_dir, "mount_fuji_3d_animation.jpg")
    img.save(jpg_path, "JPEG", quality=95)
    print(f"Generated JPEG version: {jpg_path}")

    return out_path

if __name__ == "__main__":
    render_3d_mount_fuji()
