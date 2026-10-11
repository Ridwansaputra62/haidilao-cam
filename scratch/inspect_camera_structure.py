path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\camera_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "Shutter Flash" in line or "_flyingPhotoFile" in line or "stack_end_target" in line or "Bottom Space Area" in line:
        print(f"Line {i+1}: {line.strip()}")
