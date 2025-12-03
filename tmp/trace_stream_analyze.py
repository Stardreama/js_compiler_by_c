import sys
import re

def main():
    current = None
    splits = {}
    split_rules = {}
    max_stack = 0
    alive = {0}
    max_alive = 1
    last_rule = {}
    for line in sys.stdin:
        if line.startswith('Next token is token'):
            parts = line.strip().split()
            current = parts[4] if len(parts) >= 5 else None
        if 'Splitting off stack' in line:
            m = re.search(r'Splitting off stack (\d+) from (\d+)', line)
            if m:
                new = int(m.group(1))
                parent = int(m.group(2))
                max_stack = max(max_stack, new)
                if current:
                    splits[current] = splits.get(current, 0) + 1
                alive.add(new)
                max_alive = max(max_alive, len(alive))
                pr = last_rule.get(parent)
                if pr:
                    split_rules[pr] = split_rules.get(pr, 0) + 1
        elif 'Stack ' in line and 'dies' in line:
            m = re.search(r'Stack (\d+)', line)
            if m:
                alive.discard(int(m.group(1)))
        elif line.startswith('Rename stack'):
            m = re.search(r'Rename stack (\d+) -> (\d+)', line)
            if m:
                old = int(m.group(1))
                new = int(m.group(2))
                if old in alive:
                    alive.remove(old)
                    alive.add(new)
        elif line.startswith('Reduced stack'):
            m = re.search(r'Reduced stack (\d+) by rule (\d+) \(line (\d+)\)', line)
            if m:
                last_rule[int(m.group(1))] = (int(m.group(2)), int(m.group(3)))
    print('max_stack', max_stack)
    print('max_alive', max_alive)
    print('top tokens', sorted(splits.items(), key=lambda kv: kv[1], reverse=True)[:10])
    print('top rules', sorted(split_rules.items(), key=lambda kv: kv[1], reverse=True)[:10])

if __name__ == '__main__':
    main()
