
from PIL import Image, ImageOps

icon_path = 'assets/icon/app_icon.png'
padding_percent = 0.25  # 25% padding on each side

try:
    img = Image.open(icon_path).convert("RGBA")
    width, height = img.size
    
    # Calculate new size with padding
    new_width = int(width * (1 + 2 * padding_percent))
    new_height = int(height * (1 + 2 * padding_percent))
    
    # Create new black background image
    new_img = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 255))
    
    # Calculate position to paste original image (centered)
    paste_x = (new_width - width) // 2
    paste_y = (new_height - height) // 2
    
    new_img.paste(img, (paste_x, paste_y), img)
    
    # Resize back to original size (optional, but good for launcher icon consistency)
    # Actually, let's keep it high res if possible, but for launcher icon generation it doesn't matter much.
    # But to overwrite, let's resize back to original dimensions for simplicity?
    # No, let's keep aspect ratio and just resize to standard size like 1024x1024 if needed.
    # Let's just resize back to original dimensions to be safe.
    final_img = new_img.resize((width, height), Image.LANCZOS)
    
    final_img.save(icon_path)
    print(f"Successfully padded {icon_path}")

except Exception as e:
    print(f"Error processing image: {e}")
