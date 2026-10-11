path = r"c:\Users\koid\Documents\haidilao-cam\lib\screens\camera_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

depth = 0
for i, line in enumerate(lines):
    open_c = line.count('{')
    close_c = line.count('}')
    depth += open_c - close_c
    if i < 750 and depth <= 1:
        print(f"Line {i+1} (depth {depth}): {line.strip()}")
