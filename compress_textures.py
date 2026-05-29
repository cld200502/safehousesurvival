"""压缩超大PNG纹理图片，减少pck体积"""
import os
from PIL import Image

TEXTURES_DIR = r"C:\Users\丹\CodeBuddy\20260524170342\assets\textures"

# 需要压缩的大文件（>500KB的）
files = os.listdir(TEXTURES_DIR)
png_files = [f for f in files if f.endswith('.png')]

saved_total = 0

for f in png_files:
    path = os.path.join(TEXTURES_DIR, f)
    size_kb = os.path.getsize(path) / 1024
    
    if size_kb < 200:  # 小于200KB的跳过
        continue
    
    original_bytes = os.path.getsize(path)
    img = Image.open(path)
    
    # 超过1024像素宽度的缩小到1024
    w, h = img.size
    new_w, new_h = w, h
    if w > 1024 or h > 1024:
        scale = 1024 / max(w, h)
        new_w = int(w * scale)
        new_h = int(h * scale)
        img = img.resize((new_w, new_h), Image.LANCZOS)
    
    # 转RGB（去掉alpha如果不需要）
    if img.mode == 'RGBA':
        # 检查alpha是否全是255（全不透明）
        alpha = img.split()[-1]
        if alpha.getextrema() == (255, 255):
            img = img.convert('RGB')
    
    # 保存压缩
    img.save(path, 'PNG', optimize=True)
    new_bytes = os.path.getsize(path)
    saved = (original_bytes - new_bytes) / 1024
    saved_total += saved
    print(f"  {f}: {size_kb:.0f}KB → {new_bytes/1024:.0f}KB (节省 {saved:.0f}KB, {new_w}x{new_h})")

print(f"\n总共节省: {saved_total/1024:.1f} MB")
