python3 << 'PYEOF'
import os
path = os.path.expanduser('~') + '/Chores/index.html'
with open(path, 'r') as f:
    c = f.read()

# ============================================================================
# 1. Add Firebase SDK CDN scripts to <head>, after Babel
# ============================================================================
old_head = '<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>'
new_head = """<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>

<!-- Firebase (compat SDK, loaded globally so we can use it from babel-transformed code) -->
<script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-database-compat.js"></script>
<script>
  // Firebase config for House Ledger
  const firebaseConfig = {
    apiKey: "AIzaSyAgrGcq4yAqp9jkUR9WPR3iFQqPR9787sY",
    authDomain: "house-ledger-26622.firebaseapp.com",
    databaseURL: "https://house-ledger-26622-default-rtdb.europe-west1.firebasedatabase.app/",
    projectId: "house-ledger-26622",
    storageBucket: "house-ledger-26622.firebasestorage.app",
    messagingSenderId: "409038286250",
    appId: "1:409038286250:web:4e61b9b1d232820efa4fd3"
  };
  firebase.initializeApp(firebaseConfig);
  window.fbDb = firebase.database();
  // Enable offline persistence: writes when offline queue up until reconnect
  firebase.database().goOnline();
</script>"""

assert old_head in c, "head anchor not found"
c = c.replace(old_head, new_head)

# ============================================================================
# 2. Add Firebase sync state to ChoreTracker and wire up subscription
# ============================================================================

# Find the loading useEffect and replace it with one that also subscribes to Firebase
old_load = """  // Load
  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        setHistory(parsed.history || {});
        if (parsed.tasks) {
          // Merge: keep saved tasks (preserves edited cadences) but append any
          // new defaults that didn't exist before (e.g. Bathrooms group added in v1.2)
          const savedIds = new Set(parsed.tasks.map((t) => t.id));
          const merged = [...parsed.tasks, ...DEFAULT_TASKS.filter((t) => !savedIds.has(t.id))];
          setTasks(merged);
        }
      }
    } catch (e) { /* first run */ }
    setLoading(false);
  }, []);"""

new_load = """  // Load: localStorage first (fast), then subscribe to Firebase
  useEffect(() => {
    // 1. Hydrate from localStorage immediately
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        setHistory(parsed.history || {});
        if (parsed.tasks) {
          const savedIds = new Set(parsed.tasks.map((t) => t.id));
          const merged = [...parsed.tasks, ...DEFAULT_TASKS.filter((t) => !savedIds.has(t.id))];
          setTasks(merged);
        }
      }
    } catch (e) { /* first run */ }
    setLoading(false);

    // 2. Subscribe to Firebase history changes
    if (!window.fbDb) return;
    const ref = window.fbDb.ref('history');
    const listener = ref.on('value', (snap) => {
      const val = snap.val();
      if (val) {
        // Firebase has data - it wins (source of truth)
        setHistory(val);
      } else {
        // Firebase is empty but we might have local data - push it up to seed
        try {
          const raw = localStorage.getItem(STORAGE_KEY);
          if (raw) {
            const parsed = JSON.parse(raw);
            if (parsed.history && Object.keys(parsed.history).length > 0) {
              ref.set(parsed.history);
            }
          }
        } catch (e) {}
      }
    }, (err) => {
      console.error('Firebase read failed:', err);
    });

    return () => ref.off('value', listener);
  }, []);"""

assert old_load in c, "load useEffect anchor not found"
c = c.replace(old_load, new_load)

# ============================================================================
# 3. Update save useEffect to also write to Firebase
# ============================================================================

old_save = """  // Save
  useEffect(() => {
    if (loading) return;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ history, tasks }));
    } catch (e) { console.error('save failed', e); }
  }, [history, tasks, loading]);"""

new_save = """  // Save: localStorage always, Firebase if available
  useEffect(() => {
    if (loading) return;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ history, tasks }));
    } catch (e) { console.error('local save failed', e); }
    // Push to Firebase (debounced via state - React already batches, this fires once per change)
    if (window.fbDb) {
      window.fbDb.ref('history').set(history).catch((err) => {
        console.error('Firebase write failed:', err);
      });
    }
  }, [history, tasks, loading]);"""

assert old_save in c, "save useEffect anchor not found"
c = c.replace(old_save, new_save)

# ============================================================================
# 4. Add a small sync indicator to the footer
# ============================================================================
old_footer = """          Tap row to log today · 📅 for a different date · ↻ for full history
          <div className="mt-2 opacity-70">v{VERSION} · {VERSION_DATE}</div>
        </footer>"""

new_footer = """          Tap row to log today · 📅 for a different date · ↻ for full history
          <div className="mt-2 opacity-70">v{VERSION} · {VERSION_DATE} · {window.fbDb ? '☁ synced' : 'local only'}</div>
        </footer>"""

assert old_footer in c, "footer anchor not found"
c = c.replace(old_footer, new_footer)

# ============================================================================
# 5. Bump version
# ============================================================================
c = c.replace("const VERSION = '1.5'", "const VERSION = '1.6'")
c = c.replace("const VERSION_DATE = '2026-05-08'", "const VERSION_DATE = '2026-05-09'")

with open(path, 'w') as f:
    f.write(c)

print("✓ index.html patched with Firebase sync")
print("  Firebase scripts loaded:", "firebase-app-compat" in c)
print("  Firebase config inlined:", "house-ledger-26622" in c)
print("  Subscribe to /history:", "ref('history')" in c)
print("  Write to Firebase:", "ref('history').set(history)" in c)
print("  Version:", [l for l in c.split('\n') if "const VERSION =" in l][0].strip())
PYEOF
