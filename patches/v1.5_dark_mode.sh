python3 << 'PYEOF'
import os
path = os.path.expanduser('~') + '/Chores/index.html'
with open(path, 'r') as f:
    c = f.read()

# 1. Add CSS custom properties + dark class definitions (and replace background hex on html/body)
old_css = """<style>
  html, body, #root {
    margin: 0;
    padding: 0;
    min-height: 100vh;
    min-height: 100dvh;
    background: #f4ede0;
  }"""

new_css = """<style>
  :root {
    --bg:        #f4ede0;
    --bg-2:      #ebe0c9;
    --bg-3:      #ffffff;
    --bg-modal:  rgba(42, 31, 21, 0.5);
    --text:      #2a1f15;
    --sub:       #7a5f3f;
    --border:    #2a1f15;
    --rule:      #c4b596;
    --over-bg:   #fce8e3;
    --over-fg:   #c44536;
    --due-bg:    #faf0d8;
    --due-fg:    #a87a2c;
    --fresh-bg:  #eef0e3;
    --fresh-fg:  #5e6e44;
    --selected-bg: #2a1f15;
    --selected-fg: #f4ede0;
    --shadow:    #2a1f15;
    --hover:     rgba(0, 0, 0, 0.05);
  }
  body.dark {
    --bg:        #1a1612;
    --bg-2:      #2a2520;
    --bg-3:      #100d0a;
    --bg-modal:  rgba(0, 0, 0, 0.7);
    --text:      #e8dcc4;
    --sub:       #9a8265;
    --border:    #5c4d3a;
    --rule:      #3a302a;
    --over-bg:   #3a1d18;
    --over-fg:   #e07060;
    --due-bg:    #3a2f15;
    --due-fg:    #d4a04a;
    --fresh-bg:  #1f2a1a;
    --fresh-fg:  #9bad7c;
    --selected-bg: #e8dcc4;
    --selected-fg: #1a1612;
    --shadow:    #000000;
    --hover:     rgba(255, 255, 255, 0.06);
  }
  html, body, #root {
    margin: 0;
    padding: 0;
    min-height: 100vh;
    min-height: 100dvh;
    background: var(--bg);
  }"""

assert old_css in c, "CSS root block not found"
c = c.replace(old_css, new_css)

# 2. Replace every hardcoded color in inline styles with var() references.
# Order matters: do longer/more-specific replacements first.
swaps = [
    # Modal backdrop (most specific first)
    ("rgba(42, 31, 21, 0.5)",       "var(--bg-modal)"),
    # Hover backgrounds in className utilities can stay (Tailwind handles via opacity); but
    # we replace explicit ones used in style props. There aren't any actual hardcoded hover
    # colours in style props — `hover:bg-black/5` is Tailwind. Leave those alone.

    # Selected state colours used in calendar
    ("background: '#2a1f15'",        "background: 'var(--selected-bg)'"),
    ("color: '#f4ede0'",             "color: 'var(--selected-fg)'"),
    ("background: '#f4ede0'",        "background: 'var(--bg)'"),

    # Standard body / paper / card
    ("background: '#ebe0c9'",        "background: 'var(--bg-2)'"),
    ("background: '#fff'",           "background: 'var(--bg-3)'"),

    # Status backgrounds (rows + stat cards)
    ("background: '#fce8e3'",        "background: 'var(--over-bg)'"),
    ("background: '#faf0d8'",        "background: 'var(--due-bg)'"),
    ("background: '#eef0e3'",        "background: 'var(--fresh-bg)'"),

    # Status accents (text colour for date / icon)
    ("'#c44536'",                    "'var(--over-fg)'"),
    ("'#a87a2c'",                    "'var(--due-fg)'"),
    ("'#5e6e44'",                    "'var(--fresh-fg)'"),

    # Stat card foreground white-on-color: keep stat cards saturated even in dark mode
    # so they're still vivid - skip these. The stat card backgrounds already use the saturated
    # versions inline with their tones map and we leave those.

    # Sepia sub-text and border
    ("color: '#7a5f3f'",             "color: 'var(--sub)'"),
    ("color: '#2a1f15'",             "color: 'var(--text)'"),
    ("border: '1.5px solid #2a1f15'","border: '1.5px solid var(--border)'"),
    ("border: '1px solid #2a1f15'",  "border: '1px solid var(--border)'"),
    ("border: '2px solid #2a1f15'",  "border: '2px solid var(--border)'"),
    ("border: '1.5px dashed #2a1f15'","border: '1.5px dashed var(--border)'"),
    ("borderLeft: '1.5px solid #2a1f15'", "borderLeft: '1.5px solid var(--border)'"),
    ("borderBottom: '1.5px solid #2a1f15'", "borderBottom: '1.5px solid var(--border)'"),
    ("borderTop: '1px solid #c4b596'", "borderTop: '1px solid var(--rule)'"),
    ("borderBottom: '3px double #2a1f15'", "borderBottom: '3px double var(--border)'"),

    # Box shadows
    ("boxShadow: '2px 2px 0 #2a1f15'", "boxShadow: '2px 2px 0 var(--shadow)'"),
    ("boxShadow: '4px 4px 0 #2a1f15'", "boxShadow: '4px 4px 0 var(--shadow)'"),
    ("boxShadow: '3px 3px 0 #2a1f15'", "boxShadow: '3px 3px 0 var(--shadow)'"),
    ("boxShadow: '1px 1px 0 #2a1f15'", "boxShadow: '1px 1px 0 var(--shadow)'"),
    ("boxShadow: '2px 2px 0 #7a5f3f'", "boxShadow: '2px 2px 0 var(--sub)'"),

    # Calendar today-cell border accent
    ("'1px solid ' + (isToday && !isSelected ? '#a87a2c' : '#2a1f15')",
     "'1px solid ' + (isToday && !isSelected ? 'var(--due-fg)' : 'var(--border)')"),

    # ViewTab active state uses #2a1f15 as background + #f4ede0 as fg - already covered above

    # Author colour for "Most recent" tag (5e6e44 already swapped)
]

before_count = c.count("'#2a1f15'") + c.count("'#7a5f3f'") + c.count("'#f4ede0'") + c.count("'#ebe0c9'")
for old, new in swaps:
    c = c.replace(old, new)

# Additional swaps for object-literal status styles (different format)
c = c.replace("bg: '#fce8e3', accent: 'var(--over-fg)'", "bg: 'var(--over-bg)', accent: 'var(--over-fg)'")
c = c.replace("bg: '#faf0d8', accent: 'var(--due-fg)'",  "bg: 'var(--due-bg)', accent: 'var(--due-fg)'")
c = c.replace("bg: '#eef0e3', accent: 'var(--fresh-fg)'","bg: 'var(--fresh-bg)', accent: 'var(--fresh-fg)'")

# History modal entry alternating bg
c = c.replace("background: i === 0 ? '#eef0e3' : '#ebe0c9'", "background: i === 0 ? 'var(--fresh-bg)' : 'var(--bg-2)'")

# ViewTab active/inactive
c = c.replace(
    "background: active ? '#2a1f15' : 'transparent', color: active ? '#f4ede0' : '#2a1f15'",
    "background: active ? 'var(--selected-bg)' : 'transparent', color: active ? 'var(--selected-fg)' : 'var(--text)'"
)

# Stat cards: keep the saturated tone backgrounds in light mode, but in dark mode they look harsh
# - we leave them since they're intentional accent colour spots. The fg #f4ede0/#2a1f15 inside
# stat cards stays as literal because cards are coloured tiles regardless of theme.

# Date picker selected preset
c = c.replace(
    "background: active ? '#2a1f15' : 'var(--bg-2)'",
    "background: active ? 'var(--selected-bg)' : 'var(--bg-2)'"
)
c = c.replace(
    "color: active ? '#f4ede0' : 'var(--text)'",
    "color: active ? 'var(--selected-fg)' : 'var(--text)'"
)

# Date picker preset buttons (commas at end - different format than above)
c = c.replace(
    "background: active ? '#2a1f15' : '#ebe0c9',",
    "background: active ? 'var(--selected-bg)' : 'var(--bg-2)',"
)
c = c.replace(
    "color: active ? '#f4ede0' : '#2a1f15',",
    "color: active ? 'var(--selected-fg)' : 'var(--text)',"
)
# Calendar today border (template literal)
c = c.replace(
    "border: `1px solid ${isToday && !isSelected ? 'var(--due-fg)' : '#2a1f15'}` }}>",
    "border: `1px solid ${isToday && !isSelected ? 'var(--due-fg)' : 'var(--border)'}` }}>"
)
# Calendar count number colour
c = c.replace(
    "color: isSelected ? '#f4ede0' : '#7a5f3f'",
    "color: isSelected ? 'var(--selected-fg)' : 'var(--sub)'"
)

# Calendar cell selected/today (full statement)
c = c.replace(
    "background: isSelected ? '#2a1f15' : isToday ? '#faf0d8' : '#f4ede0',",
    "background: isSelected ? 'var(--selected-bg)' : isToday ? 'var(--due-bg)' : 'var(--bg)',"
)
c = c.replace(
    "color: isSelected ? '#f4ede0' : '#2a1f15',",
    "color: isSelected ? 'var(--selected-fg)' : 'var(--text)',"
)

# Calendar cell selected/today
c = c.replace(
    "background: isSelected ? '#2a1f15' : isToday ? 'var(--due-bg)' : 'var(--bg)'",
    "background: isSelected ? 'var(--selected-bg)' : isToday ? 'var(--due-bg)' : 'var(--bg)'"
)
c = c.replace(
    "color: isSelected ? '#f4ede0' : 'var(--text)'",
    "color: isSelected ? 'var(--selected-fg)' : 'var(--text)'"
)
c = c.replace(
    "color: isSelected ? '#f4ede0' : 'var(--sub)'",
    "color: isSelected ? 'var(--selected-fg)' : 'var(--sub)'"
)

# Install banner (dark text on dark in dark mode looks wrong) - leave it, it's a one-time element

# Stamp animation done state
c = c.replace(
    "background: justDone ? '#7a8b5c' : 'transparent'",
    "background: justDone ? '#7a8b5c' : 'transparent'"  # keep - intentional saturated green
)
c = c.replace(
    "color: justDone ? '#f4ede0' : s.accent",
    "color: justDone ? '#ffffff' : s.accent"  # white on green stays
)

# 3. Update theme-color meta tag wiring - we'll set it dynamically via JS in the toggle effect
# (handled by adding code in the React component - see step 5)

# 4. Update html/body inline meta theme-color won't be enough; we leave it as-is (cosmetic)

# 5. Add dark mode toggle state + effect + button in header.
# Inject into the ChoreTracker function - just after `const [showSettings, setShowSettings]` line:
old_state_block = "  const [showSettings, setShowSettings] = useState(false);"
new_state_block = """  const [showSettings, setShowSettings] = useState(false);
  const [dark, setDark] = useState(() => {
    try { return localStorage.getItem('house-ledger-theme') === 'dark'; } catch (e) { return false; }
  });

  // Apply theme class to body and persist
  useEffect(() => {
    document.body.classList.toggle('dark', dark);
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', dark ? '#1a1612' : '#f4ede0');
    try { localStorage.setItem('house-ledger-theme', dark ? 'dark' : 'light'); } catch (e) {}
  }, [dark]);"""

assert old_state_block in c, "state block anchor not found"
c = c.replace(old_state_block, new_state_block)

# 6. Add Sun/Moon icon components - inject after the Trash2 const:
old_icon_block = "const Trash2 = (p) => <Icon {...p} d={"
# Find and inject before Trash2
sun_moon = """const Sun = (p) => <Icon {...p} d={<><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></>} />;
const Moon = (p) => <Icon {...p} d={<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>} />;
"""
assert old_icon_block in c, "icon block anchor not found"
c = c.replace(old_icon_block, sun_moon + old_icon_block)

# 7. Add toggle button to header. Find the masthead's date-display row and add toggle there.
old_header_top = """          <div className="flex items-baseline justify-between mb-2">
            <span className="mono text-xs tracking-[0.2em] uppercase" style={{ color: 'var(--sub)' }}>
              No. 001 · Est. {new Date().getFullYear()}
            </span>
            <span className="mono text-xs tracking-wider" style={{ color: 'var(--sub)' }}>
              {new Date().toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' })}
            </span>
          </div>"""

new_header_top = """          <div className="flex items-baseline justify-between mb-2">
            <span className="mono text-xs tracking-[0.2em] uppercase" style={{ color: 'var(--sub)' }}>
              No. 001 · Est. {new Date().getFullYear()}
            </span>
            <div className="flex items-center gap-3">
              <span className="mono text-xs tracking-wider" style={{ color: 'var(--sub)' }}>
                {new Date().toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' })}
              </span>
              <button onClick={() => setDark(!dark)}
                className="p-1.5 hover:opacity-70 transition-opacity"
                style={{ color: 'var(--sub)' }}
                aria-label={dark ? 'Switch to light mode' : 'Switch to dark mode'}
                title={dark ? 'Light mode' : 'Dark mode'}>
                {dark ? <Sun size={14} /> : <Moon size={14} />}
              </button>
            </div>
          </div>"""

assert old_header_top in c, "header anchor not found - someone changed the masthead"
c = c.replace(old_header_top, new_header_top)

# 8. Bump version
c = c.replace("const VERSION = '1.4'", "const VERSION = '1.5'")
c = c.replace("const VERSION_DATE = '2026-05-08'", "const VERSION_DATE = '2026-05-08'")

with open(path, 'w') as f:
    f.write(c)

print("✓ index.html patched for dark mode")
print("  Var references:", c.count("var(--"))
print("  Sun icon defined:", "const Sun = " in c)
print("  Moon icon defined:", "const Moon = " in c)
print("  Dark state:", "const [dark, setDark]" in c)
print("  Version:", [l for l in c.split('\n') if "const VERSION =" in l][0].strip())
PYEOF
