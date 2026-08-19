import re
tag_re = re.compile(r'<(/?)([A-Za-z_][A-Za-z0-9_]*)\b([^>]*?)(/?)>')
files = [l.strip() for l in open('scratch_trigger_files.txt', encoding='utf-8') if l.strip()]
from collections import Counter
endtype_counter = Counter()
examples = {}
no_endtype_with_trigger = []

for path in files:
    try:
        with open(path, encoding='utf-8-sig', errors='replace') as f:
            text = f.read()
    except Exception:
        continue
    stack = []  # (name, attrs)
    seq_stack = []  # stack of [endtype, has_trigger_flag(list for mutability), name]
    for m in tag_re.finditer(text):
        closing, name, attrs, selfclose = m.groups()
        if selfclose == '/':
            if name == 'Triggers' and seq_stack:
                et = seq_stack[-1][0]
                endtype_counter[et] += 1
                if et not in examples:
                    examples[et] = (path, seq_stack[-1][2])
                if et is None:
                    no_endtype_with_trigger.append((path, seq_stack[-1][2]))
            continue
        if closing == '/':
            if name == 'Sequence' and seq_stack:
                seq_stack.pop()
            if stack and stack[-1][0] == name:
                stack.pop()
            elif any(s[0]==name for s in stack):
                idx = len(stack) - 1 - [s[0] for s in stack[::-1]].index(name)
                stack = stack[:idx]
        else:
            if name == 'Sequence':
                m2 = re.search(r'EndType="([^"]*)"', attrs)
                et = m2.group(1) if m2 else None
                nm = re.search(r'Name="([^"]*)"', attrs)
                nmv = nm.group(1) if nm else '?'
                seq_stack.append([et, False, nmv])
            if name == 'Triggers' and seq_stack:
                et = seq_stack[-1][0]
                endtype_counter[et] += 1
                if et not in examples:
                    examples[et] = (path, seq_stack[-1][2])
                if et is None:
                    no_endtype_with_trigger.append((path, seq_stack[-1][2]))
            stack.append((name, attrs))

print("EndType distribution for Sequences carrying Triggers:")
for k,v in endtype_counter.most_common():
    print(k, v, examples.get(k))
print()
print("count with no EndType attr:", len(no_endtype_with_trigger))
for row in no_endtype_with_trigger[:10]:
    print(row)
