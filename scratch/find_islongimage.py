path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\gallery_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "isLongImage" in line:
        print(f"Line {i+1}: {line.strip()}")
