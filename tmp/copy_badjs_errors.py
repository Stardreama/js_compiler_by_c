import os
import re
import shutil
from typing import Set

LOG_PATH = os.path.join(
    os.path.dirname(__file__), "..", "build", "parser_error_locations.log"
)
DEST_DIR = os.path.join(
    os.path.dirname(__file__), "..", "test", "JavaScript_Datasets", "badjs_error"
)

# Matches lines like:
# test/JavaScript_Datasets/badjs/<name>:2:11: syntax error ...
LOG_LINE_PATTERN = re.compile(r"^(?P<path>.+?):\d+:\d+: .+$")


def ensure_dest_dir(path: str) -> None:
    if not os.path.isdir(path):
        os.makedirs(path, exist_ok=True)


def parse_error_paths(log_file: str) -> Set[str]:
    paths: Set[str] = set()
    with open(log_file, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            match = LOG_LINE_PATTERN.match(line)
            if match:
                rel_path = match.group("path")
                normalized = os.path.normpath(
                    os.path.join(os.path.dirname(LOG_PATH), "..", rel_path)
                )
                paths.add(normalized)
    return paths


def copy_error_files() -> None:
    if not os.path.isfile(LOG_PATH):
        raise FileNotFoundError(f"日志文件不存在: {LOG_PATH}")

    ensure_dest_dir(DEST_DIR)
    error_paths = parse_error_paths(LOG_PATH)

    copied = 0
    for src in sorted(error_paths):
        if not os.path.isfile(src):
            print(f"[warn] 源文件不存在，跳过: {src}")
            continue
        filename = os.path.basename(src)
        dst = os.path.join(DEST_DIR, filename)
        shutil.copy2(src, dst)
        copied += 1
        print(f"copied {src} -> {dst}")

    print(f"完成，共复制 {copied} 个文件到 {DEST_DIR}")


if __name__ == "__main__":
    copy_error_files()
