import re
from collections import Counter

tag_re = re.compile(r'<(/?)([A-Za-z_][A-Za-z0-9_]*)\b[^>]*?(/?)>')

files = [l.strip() for l in open('scratch_trigger_files.txt', encoding='utf-8') if l.strip()]
non_seq_parents = []
multi_per_seq = []

for path in files:
    try:
        with open(path, encoding='utf-8-sig', errors='replace') as f:
            text = f.read()
    except Exception:
        continue
    stack = []
    seq_trigger_count = {}  # id(seq marker) -> count, use stack depth index as marker via list of (name) with counters attached
    # We'll track using a parallel stack of trigger-counts per Sequence frame
    seq_stack = []  # stack of counters, pushed when Sequence opened
    for m in tag_re.finditer(text):
        closing, name, selfclose = m.groups()
        if selfclose == '/':
            if name == 'Triggers':
                parent = stack[-1] if stack else None
                if parent != 'Sequence':
                    non_seq_parents.append((path, parent))
                elif seq_stack:
                    seq_stack[-1] += 1
            continue
        if closing == '/':
            if name == 'Sequence' and seq_stack:
                cnt = seq_stack.pop()
                if cnt > 1:
                    multi_per_seq.append((path, cnt))
            if stack and stack[-1] == name:
                stack.pop()
            elif name in stack:
                idx = len(stack) - 1 - stack[::-1].index(name)
                stack = stack[:idx]
        else:
            if name == 'Sequence':
                seq_stack.append(0)
            if name == 'Triggers':
                parent = stack[-1] if stack else None
                if parent != 'Sequence':
                    non_seq_parents.append((path, parent))
                elif seq_stack:
                    seq_stack[-1] += 1
            stack.append(name)

print("non-Sequence trigger parents:", len(non_seq_parents))
for row in non_seq_parents[:30]:
    print(row)
print()
print("Sequences with >1 Triggers:", len(multi_per_seq))
for row in multi_per_seq[:30]:
    print(row)
