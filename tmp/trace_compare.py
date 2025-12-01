import re
import sys
from collections import Counter


def analyze(path):
    current_token = None
    splits = Counter()
    max_stack = 0
    stack_alive = set([0])
    max_alive = 1
    for line in open(path, "r", encoding="utf-8", errors="ignore"):
        line = line.strip()
        if line.startswith("Next token is token"):
            parts = line.split()
            if len(parts) >= 5:
                current_token = parts[4]
            else:
                current_token = None
        elif "Splitting off stack" in line:
            m = re.search(r"Splitting off stack (\d+)", line)
            if m:
                new_id = int(m.group(1))
                max_stack = max(max_stack, new_id)
            if current_token:
                splits[current_token] += 1
            # track alive stack count crudely
            stack_alive.add(new_id)
            max_alive = max(max_alive, len(stack_alive))
        elif "Stack " in line and "dies" in line:
            m = re.search(r"Stack (\d+)", line)
            if m:
                sid = int(m.group(1))
                stack_alive.discard(sid)
        elif line.startswith("Rename stack"):
            # treat rename: remove old, add new
            m = re.search(r"Rename stack (\d+) -> (\d+)", line)
            if m:
                old = int(m.group(1))
                new = int(m.group(2))
                if old in stack_alive:
                    stack_alive.discard(old)
                    stack_alive.add(new)
        elif line.startswith("Cleanup:"):
            stack_alive.clear()
        elif line.startswith("[PASS]") or line.startswith("[FAIL]"):
            stack_alive.clear()
    return splits, max_stack, max_alive


def main():
    if len(sys.argv) != 3:
        print("Usage: trace_compare.py <traceA> <traceB>")
        return
    for path in sys.argv[1:]:
        splits, max_stack, max_alive = analyze(path)
        print(f"=== {path} ===")
        print(f"Max stack id: {max_stack}")
        print(f"Peak concurrent stacks (approx): {max_alive}")
        for token, count in splits.most_common(10):
            print(f"{token}: {count}")


if __name__ == "__main__":
    main()
