import argparse
import os
import re
from typing import List, Tuple

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEFAULT_LOG_PATH = os.path.join(PROJECT_ROOT, "test", "parser_error_locations3.log")
LINE_PATTERN = re.compile(r"^(?P<path>[^:]+):(?P<line>\d+):(?P<col>\d+):(?P<rest>.*)$")


def resolve_path(rel_or_abs: str) -> str:
    if os.path.isabs(rel_or_abs):
        return rel_or_abs
    return os.path.normpath(os.path.join(PROJECT_ROOT, rel_or_abs))


def load_entries(log_path: str) -> List[Tuple[int, int, str]]:
    entries: List[Tuple[int, int, str]] = []
    with open(log_path, "r", encoding="utf-8") as handle:
        for idx, raw_line in enumerate(handle):
            line = raw_line.rstrip("\n")
            if not line.strip():
                continue
            match = LINE_PATTERN.match(line)
            if not match:
                print(f"[warn] 无法解析的行 #{idx + 1}: {line}")
                continue
            rel_path = match.group("path")
            target_file = resolve_path(rel_path)
            if not os.path.isfile(target_file):
                print(f"[warn] 文件不存在，跳过: {target_file}")
                continue
            size = os.path.getsize(target_file)
            entries.append((size, idx, line))
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(
        description="按照关联文件大小对日志条目进行重新排序"
    )
    parser.add_argument(
        "--log",
        default=DEFAULT_LOG_PATH,
        help=f"日志文件路径（默认: {DEFAULT_LOG_PATH})",
    )
    parser.add_argument(
        "--output",
        help="可选输出文件；未提供时直接打印排序后的内容",
    )
    parser.add_argument(
        "--ascending",
        action="store_true",
        help="改为按文件大小升序排序，默认降序",
    )
    args = parser.parse_args()

    log_path = resolve_path(args.log)
    if not os.path.isfile(log_path):
        raise FileNotFoundError(f"日志文件不存在: {log_path}")

    entries = load_entries(log_path)
    if not entries:
        print("未找到可排序的条目")
        return

    entries.sort(key=lambda record: (record[0], record[1]), reverse=not args.ascending)
    sorted_lines = [line for _, _, line in entries]

    if args.output:
        output_path = resolve_path(args.output)
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write("\n".join(sorted_lines) + "\n")
        print(f"已将排序结果写入 {output_path}")
    else:
        for line in sorted_lines:
            print(line)


if __name__ == "__main__":
    main()
