python3 << 'PYEOF'
import os
path = os.path.expanduser('~') + '/Chores/index.html'
with open(path, 'r') as f:
    c = f.read()

# ============================================================================
# 1. Add Plus icon component (after Upload icon definition)
# ============================================================================
old_plus_anchor = "const Download = (p) => <Icon"
new_plus_anchor = "const Plus = (p) => <Icon {...p} d={<><line x1=\"12\" y1=\"5\" x2=\"12\" y2=\"19\"/><line x1=\"5\" y1=\"12\" x2=\"19\" y2=\"12\"/></>} />;\nconst Download = (p) => <Icon"
assert old_plus_anchor in c, "Plus icon anchor not found"
c = c.replace(old_plus_anchor, new_plus_anchor)

# ============================================================================
# 2. Quiet version row below masthead title
# ============================================================================
old_masthead = """          <h1 className="text-5xl sm:text-6xl font-extrabold leading-none tracking-tight" style={{
            fontVariationSettings: '"opsz" 144', letterSpacing: '-0.03em',
          }}>
            The House<br/>
            <span className="italic font-light" style={{ color: 'var(--sub)' }}>Ledger</span>
          </h1>
          <p className="mono text-xs mt-3 tracking-wide" style={{ color: 'var(--sub)' }}>
            A record of household chores · kept faithfully
          </p>"""

new_masthead = """          <h1 className="text-5xl sm:text-6xl font-extrabold leading-none tracking-tight" style={{
            fontVariationSettings: '"opsz" 144', letterSpacing: '-0.03em',
          }}>
            The House<br/>
            <span className="italic font-light" style={{ color: 'var(--sub)' }}>Ledger</span>
          </h1>
          <p className="mono text-xs mt-3 tracking-wide" style={{ color: 'var(--sub)' }}>
            A record of household chores · kept faithfully
          </p>
          <p className="mono text-[10px] mt-1 tracking-widest uppercase" style={{ color: 'var(--sub)', opacity: 0.6 }}>
            v{VERSION} · {VERSION_DATE} · {typeof window !== 'undefined' && window.fbDb ? '☁ synced' : 'local only'}
          </p>"""

assert old_masthead in c, "masthead anchor not found"
c = c.replace(old_masthead, new_masthead)

# ============================================================================
# 3. Footer can be simplified now that version is up top
# ============================================================================
old_footer = """          Tap row to log today · 📅 for a different date · ↻ for full history
          <div className="mt-2 opacity-70">v{VERSION} · {VERSION_DATE} · {window.fbDb ? '☁ synced' : 'local only'}</div>
        </footer>"""

new_footer = """          Tap row to log today · 📅 for a different date · ↻ for full history
        </footer>"""

assert old_footer in c, "footer anchor not found"
c = c.replace(old_footer, new_footer)

# ============================================================================
# 4. Add state for "add new chore" modal and a helper to create one
# ============================================================================
old_state = "  const [historyTask, setHistoryTask] = useState(null);"
new_state = """  const [historyTask, setHistoryTask] = useState(null);
  const [showAddChore, setShowAddChore] = useState(false);"""

assert old_state in c, "state anchor not found"
c = c.replace(old_state, new_state)

# ============================================================================
# 5. Add helper functions: addCustomChore and removeCustomChore
# Insert right after the updateCadence function
# ============================================================================
old_helpers = """  const updateCadence = (taskId, newCadence) => {
    setTasks((ts) => ts.map((t) => (t.id === taskId ? { ...t, cadence: newCadence } : t)));
  };"""

new_helpers = """  const updateCadence = (taskId, newCadence) => {
    setTasks((ts) => ts.map((t) => (t.id === taskId ? { ...t, cadence: newCadence } : t)));
  };

  const addCustomChore = ({ label, group, cadence }) => {
    const id = `custom-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    const newTask = { id, label, group, cadence, custom: true };
    setTasks((ts) => [...ts, newTask]);
    // Also push to Firebase /customTasks so other devices see it
    if (window.fbDb) {
      window.fbDb.ref('customTasks/' + id).set(newTask).catch((err) => {
        console.error('Failed to sync custom chore:', err);
      });
    }
  };

  const removeCustomChore = (taskId) => {
    setTasks((ts) => ts.filter((t) => t.id !== taskId));
    // Also remove its history
    setHistory((h) => {
      const next = { ...h };
      delete next[taskId];
      return next;
    });
    if (window.fbDb) {
      window.fbDb.ref('customTasks/' + taskId).remove();
    }
  };"""

assert old_helpers in c, "helpers anchor not found"
c = c.replace(old_helpers, new_helpers)

# ============================================================================
# 6. Subscribe to /customTasks in the load effect
# ============================================================================
old_subscribe = """    // 2. Subscribe to Firebase history changes
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

new_subscribe = """    // 2. Subscribe to Firebase history changes
    if (!window.fbDb) return;
    const historyRef = window.fbDb.ref('history');
    const historyListener = historyRef.on('value', (snap) => {
      const val = snap.val();
      if (val) {
        setHistory(val);
      } else {
        try {
          const raw = localStorage.getItem(STORAGE_KEY);
          if (raw) {
            const parsed = JSON.parse(raw);
            if (parsed.history && Object.keys(parsed.history).length > 0) {
              historyRef.set(parsed.history);
            }
          }
        } catch (e) {}
      }
    }, (err) => {
      console.error('Firebase history read failed:', err);
    });

    // 3. Subscribe to Firebase customTasks - merge into local task list
    const customTasksRef = window.fbDb.ref('customTasks');
    const customListener = customTasksRef.on('value', (snap) => {
      const val = snap.val();
      const remoteCustoms = val ? Object.values(val) : [];
      setTasks((current) => {
        // Keep defaults + any local-only customs (shouldn't really exist long, since we push immediately)
        // Then layer remote customs on top
        const remoteIds = new Set(remoteCustoms.map((t) => t.id));
        const withoutRemoteCustoms = current.filter((t) => !remoteIds.has(t.id));
        // Add remote customs that aren't already in the list
        const existingIds = new Set(withoutRemoteCustoms.map((t) => t.id));
        const newCustoms = remoteCustoms.filter((t) => !existingIds.has(t.id));
        return [...withoutRemoteCustoms, ...newCustoms];
      });
    }, (err) => {
      console.error('Firebase customTasks read failed:', err);
    });

    return () => {
      historyRef.off('value', historyListener);
      customTasksRef.off('value', customListener);
    };
  }, []);"""

assert old_subscribe in c, "subscribe anchor not found"
c = c.replace(old_subscribe, new_subscribe)

# ============================================================================
# 7. Add Plus button to the controls row (next to cadences / export / import)
# ============================================================================
old_controls = """              <div className="flex items-center gap-3">
                <button onClick={() => setShowSettings((s) => !s)} className="underline underline-offset-4 hover:no-underline" style={{ color: 'var(--text)' }}>
                  {showSettings ? 'close' : 'cadences'}
                </button>
                <button onClick={exportData} className="hover:opacity-70" title="Export backup" aria-label="Export backup"><Download size={12} /></button>
                <label className="hover:opacity-70 cursor-pointer" title="Import backup" aria-label="Import backup">
                  <Upload size={12} />
                  <input type="file" accept="application/json" className="hidden" onChange={(e) => { if (e.target.files[0]) importData(e.target.files[0]); e.target.value = ''; }} />
                </label>
              </div>"""

new_controls = """              <div className="flex items-center gap-3">
                <button onClick={() => setShowAddChore(true)} className="hover:opacity-70 flex items-center gap-1" style={{ color: 'var(--text)' }} title="Add new chore" aria-label="Add new chore">
                  <Plus size={12} /> add
                </button>
                <button onClick={() => setShowSettings((s) => !s)} className="underline underline-offset-4 hover:no-underline" style={{ color: 'var(--text)' }}>
                  {showSettings ? 'close' : 'cadences'}
                </button>
                <button onClick={exportData} className="hover:opacity-70" title="Export backup" aria-label="Export backup"><Download size={12} /></button>
                <label className="hover:opacity-70 cursor-pointer" title="Import backup" aria-label="Import backup">
                  <Upload size={12} />
                  <input type="file" accept="application/json" className="hidden" onChange={(e) => { if (e.target.files[0]) importData(e.target.files[0]); e.target.value = ''; }} />
                </label>
              </div>"""

assert old_controls in c, "controls anchor not found"
c = c.replace(old_controls, new_controls)

# ============================================================================
# 8. Render AddChoreModal when showAddChore is true
# Insert near the other modal renders at the end of ChoreTracker
# ============================================================================
old_modals = """      {historyTask && (
        <HistoryModal task={enriched.find((t) => t.id === historyTask.id)}
          onClose={() => setHistoryTask(null)}
          onRemove={(iso) => removeEntry(historyTask.id, iso)}
          onAdd={(iso) => addEntry(historyTask.id, iso)} />
      )}
    </div>
  );
}"""

new_modals = """      {historyTask && (
        <HistoryModal task={enriched.find((t) => t.id === historyTask.id)}
          onClose={() => setHistoryTask(null)}
          onRemove={(iso) => removeEntry(historyTask.id, iso)}
          onAdd={(iso) => addEntry(historyTask.id, iso)} />
      )}

      {showAddChore && (
        <AddChoreModal
          onClose={() => setShowAddChore(false)}
          onConfirm={(payload) => { addCustomChore(payload); setShowAddChore(false); }}
        />
      )}
    </div>
  );
}

function AddChoreModal({ onClose, onConfirm }) {
  const [label, setLabel] = useState('');
  const [group, setGroup] = useState('Misc');
  const [cadence, setCadence] = useState(14);

  const canSubmit = label.trim().length > 0 && cadence >= 1;

  const handleSubmit = () => {
    if (!canSubmit) return;
    onConfirm({ label: label.trim(), group, cadence: parseInt(cadence) || 14 });
  };

  return (
    <ModalShell onClose={onClose} title="Add new chore" subtitle="Custom · syncs across devices">
      <label className="block mb-3">
        <span className="mono text-xs uppercase tracking-widest" style={{ color: 'var(--sub)' }}>Name</span>
        <input type="text" value={label} autoFocus
          onChange={(e) => setLabel(e.target.value)}
          placeholder="e.g. Wipe down skirting boards"
          className="w-full mt-1 px-3 py-2.5 text-base"
          style={{ background: 'var(--bg-3)', border: '1.5px solid var(--border)', color: 'var(--text)' }} />
      </label>

      <label className="block mb-3">
        <span className="mono text-xs uppercase tracking-widest" style={{ color: 'var(--sub)' }}>Group</span>
        <select value={group} onChange={(e) => setGroup(e.target.value)}
          className="mono w-full mt-1 px-3 py-2.5 text-base"
          style={{ background: 'var(--bg-3)', border: '1.5px solid var(--border)', color: 'var(--text)' }}>
          {GROUP_ORDER.map((g) => (
            <option key={g} value={g}>{g}</option>
          ))}
        </select>
      </label>

      <label className="block mb-4">
        <span className="mono text-xs uppercase tracking-widest" style={{ color: 'var(--sub)' }}>Cadence (days)</span>
        <input type="number" min="1" max="365" value={cadence}
          onChange={(e) => setCadence(e.target.value)}
          className="mono w-full mt-1 px-3 py-2.5 text-base"
          style={{ background: 'var(--bg-3)', border: '1.5px solid var(--border)', color: 'var(--text)' }} />
        <span className="mono text-[10px] mt-1 block" style={{ color: 'var(--sub)' }}>
          7 = weekly · 14 = fortnightly · 28 = monthly
        </span>
      </label>

      <div className="flex gap-2">
        <button onClick={onClose} className="flex-1 px-4 py-2.5 text-sm font-semibold"
          style={{ background: 'var(--bg-2)', border: '1.5px solid var(--border)', color: 'var(--text)' }}>
          Cancel
        </button>
        <button onClick={handleSubmit} disabled={!canSubmit}
          className="flex-1 px-4 py-2.5 text-sm font-semibold transition-opacity"
          style={{ background: '#7a8b5c', color: '#f4ede0', border: '1.5px solid var(--border)', boxShadow: '2px 2px 0 var(--shadow)', opacity: canSubmit ? 1 : 0.5 }}>
          Add chore
        </button>
      </div>
    </ModalShell>
  );
}"""

assert old_modals in c, "modals anchor not found"
c = c.replace(old_modals, new_modals)

# ============================================================================
# 9. Add a delete button to TaskRow for custom chores only
# ============================================================================
old_taskrow_end = """      <button onClick={onOpenHistory}
        className="px-3 flex items-center justify-center hover:bg-black/5 transition-colors"
        style={{ borderLeft: '1.5px solid var(--border)', color: 'var(--sub)' }}
        aria-label="View history" title="View history">
        <RotateCcw size={14} />
      </button>
    </div>
  );
}"""

new_taskrow_end = """      <button onClick={onOpenHistory}
        className="px-3 flex items-center justify-center hover:bg-black/5 transition-colors"
        style={{ borderLeft: '1.5px solid var(--border)', color: 'var(--sub)' }}
        aria-label="View history" title="View history">
        <RotateCcw size={14} />
      </button>
      {task.custom && onDelete && (
        <button onClick={() => {
          if (confirm(`Delete "${task.label}"? This removes the chore and all its history.`)) onDelete();
        }}
          className="px-3 flex items-center justify-center hover:bg-black/5 transition-colors"
          style={{ borderLeft: '1.5px solid var(--border)', color: 'var(--over-fg)' }}
          aria-label="Delete custom chore" title="Delete custom chore">
          <Trash2 size={14} />
        </button>
      )}
    </div>
  );
}"""

assert old_taskrow_end in c, "taskrow end anchor not found"
c = c.replace(old_taskrow_end, new_taskrow_end)

# ============================================================================
# 10. Pass onDelete prop to TaskRow
# ============================================================================
old_taskrow_call = """                      <TaskRow
                        key={task.id} task={task}
                        onQuickDone={() => addEntry(task.id, todayISO())}
                        onPickDate={() => setLogTask(task)}
                        onOpenHistory={() => setHistoryTask(task)}
                      />"""

new_taskrow_call = """                      <TaskRow
                        key={task.id} task={task}
                        onQuickDone={() => addEntry(task.id, todayISO())}
                        onPickDate={() => setLogTask(task)}
                        onOpenHistory={() => setHistoryTask(task)}
                        onDelete={task.custom ? () => removeCustomChore(task.id) : null}
                      />"""

assert old_taskrow_call in c, "taskrow call anchor not found"
c = c.replace(old_taskrow_call, new_taskrow_call)

# ============================================================================
# 11. Update TaskRow function signature to accept onDelete
# ============================================================================
old_sig = "function TaskRow({ task, onQuickDone, onPickDate, onOpenHistory }) {"
new_sig = "function TaskRow({ task, onQuickDone, onPickDate, onOpenHistory, onDelete }) {"
assert old_sig in c, "TaskRow signature not found"
c = c.replace(old_sig, new_sig)

# ============================================================================
# 12. Bump version
# ============================================================================
c = c.replace("const VERSION = '1.6'", "const VERSION = '1.7'")
c = c.replace("const VERSION_DATE = '2026-05-09'", "const VERSION_DATE = '2026-05-09'")

with open(path, 'w') as f:
    f.write(c)

print("✓ index.html patched for v1.7")
print("  AddChoreModal defined:", "function AddChoreModal" in c)
print("  Plus icon defined:", "const Plus = " in c)
print("  addCustomChore helper:", "const addCustomChore = " in c)
print("  customTasks subscription:", "customTasksRef" in c)
print("  Version at top of masthead:", c.count("v{VERSION} · {VERSION_DATE}") >= 1)
print("  Version:", [l for l in c.split('\n') if "const VERSION =" in l][0].strip())
PYEOF
