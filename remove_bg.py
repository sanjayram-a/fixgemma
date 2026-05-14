import sys
from rembg import remove
from PIL import Image

input_path = sys.argv[1]
output_path = sys.argv[2]

print(f"Loading {input_path}")
input_image = Image.open(input_path)

print("Removing background...")
output_image = remove(input_image)

print(f"Saving to {output_path}")
output_image.save(output_path)
print("Done!")
