import sys
from PIL import Image

def remove_background(input_path, output_path, tolerance=30):
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    
    # Get the top-left pixel as the background color
    bg_color = data[0]
    
    new_data = []
    for item in data:
        # Check if the pixel color is within the tolerance of the bg_color
        if (abs(item[0] - bg_color[0]) <= tolerance and
            abs(item[1] - bg_color[1]) <= tolerance and
            abs(item[2] - bg_color[2]) <= tolerance and
            item[3] > 0):
            new_data.append((255, 255, 255, 0)) # Transparent
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(output_path, "PNG")

if __name__ == "__main__":
    remove_background(sys.argv[1], sys.argv[2])
