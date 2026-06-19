python3 << 'PYEOF'
import os
path = os.path.expanduser('~') + '/Chores/index.html'
with open(path, 'r') as f:
    c = f.read()

# Pin React 18 - currently uses `react@18` which floats within the 18.x line.
# That's normally safe, but let's pin to a known good 18.3.1.
old_react = '<script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>'
new_react = '<script crossorigin src="https://unpkg.com/react@18.3.1/umd/react.production.min.js"></script>'
assert old_react in c, "React script anchor not found"
c = c.replace(old_react, new_react)

old_react_dom = '<script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>'
new_react_dom = '<script crossorigin src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js"></script>'
assert old_react_dom in c, "ReactDOM script anchor not found"
c = c.replace(old_react_dom, new_react_dom)

# Firebase is already pinned to 10.7.1 - verify and leave as-is
assert "firebase-app-compat.js" in c
assert "10.7.1" in c, "Firebase version 10.7.1 not found - expected pinned"

# Tailwind + Babel already pinned in v1.8 - verify
assert "tailwindcss.com/3.4.17" in c, "Tailwind pin missing (should have come from v1.8)"
assert "standalone@7/" in c, "Babel v7 pin missing (should have come from v1.8)"

# Bump version
c = c.replace("const VERSION = '1.8'", "const VERSION = '1.9'")
import datetime
today = datetime.date.today().isoformat()
old_date_lines = [l for l in c.split('\n') if 'VERSION_DATE =' in l]
if old_date_lines:
    old_date_line = old_date_lines[0].strip()
    new_date_line = f"const VERSION_DATE = '{today}';"
    c = c.replace(old_date_line, new_date_line)

with open(path, 'w') as f:
    f.write(c)

print("✓ index.html patched - all CDN versions pinned")
print("  React pinned:", "react@18.3.1" in c)
print("  ReactDOM pinned:", "react-dom@18.3.1" in c)
print("  Firebase pinned (existing):", "10.7.1" in c)
print("  Tailwind pinned (from v1.8):", "tailwindcss.com/3.4.17" in c)
print("  Babel pinned (from v1.8):", "standalone@7/" in c)
print("  Version:", [l for l in c.split('\n') if "const VERSION =" in l][0].strip())
PYEOF
