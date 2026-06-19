python3 << 'PYEOF'
import os
path = os.path.expanduser('~') + '/Chores/index.html'
with open(path, 'r') as f:
    c = f.read()

# 1. Pin Tailwind to known-good 3.4.17
old_tw = '<script src="https://cdn.tailwindcss.com"></script>'
new_tw = '<script src="https://cdn.tailwindcss.com/3.4.17"></script>'
assert old_tw in c, "Tailwind script anchor not found"
c = c.replace(old_tw, new_tw)

# 2. Pin Babel to last v7 release (7.26.x line; @7 redirects to latest 7.x)
old_babel = '<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>'
new_babel = '<script src="https://unpkg.com/@babel/standalone@7/babel.min.js"></script>'
assert old_babel in c, "Babel script anchor not found"
c = c.replace(old_babel, new_babel)

# 3. Bump version
c = c.replace("const VERSION = '1.7'", "const VERSION = '1.8'")
# Use a sentinel for date that python can substitute in
import datetime
today = datetime.date.today().isoformat()
old_date_lines = [l for l in c.split('\n') if 'VERSION_DATE =' in l]
if old_date_lines:
    old_date_line = old_date_lines[0].strip()
    new_date_line = f"const VERSION_DATE = '{today}';"
    c = c.replace(old_date_line, new_date_line)

with open(path, 'w') as f:
    f.write(c)

print("✓ index.html patched - CDN versions pinned")
print("  Tailwind pinned:", "tailwindcss.com/3.4.17" in c)
print("  Babel pinned to v7:", "standalone@7/" in c)
print("  Version:", [l for l in c.split('\n') if "const VERSION =" in l][0].strip())
print("  Date:", [l for l in c.split('\n') if "VERSION_DATE =" in l][0].strip())
PYEOF
