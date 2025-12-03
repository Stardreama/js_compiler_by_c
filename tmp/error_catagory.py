import re
from collections import Counter

def analyze_parser_errors(filename):
    """
析解析错误日志文件，统计各种错误类型"""
    
    error_pattern = r': (.+)$'
    error_types = []
    
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                # 提取错误信息（冒号后的内容）
                match = re.search(error_pattern, line)
                if match:
                    error_msg = match.group(1)
                    error_types.append(error_msg)
    
    # 统计错误类型
    error_counts = Counter(error_types)
    
    # 输出统计结果
    print("=" * 80)
    print("错误类型统计报告")
    print("=" * 80)
    print(f"\n总错误数: {len(error_types)}")
    print(f"唯一错误类型数: {len(error_counts)}\n")
    
    print("-" * 80)
    print(f"{'错误类型':<60} {'出现次数':>10} {'占比':>8}")
    print("-" * 80)
    
    # 按出现次数降序排列
    for error_type, count in error_counts.most_common():
        percentage = (count / len(error_types)) * 100
        print(f"{error_type:<60} {count:>10} {percentage:>7.2f}%")
    
    print("=" * 80)
    
    # 额外统计：按主要错误类别分组
    print("\n按主要错误类别分组:")
    print("-" * 80)
    
    categories = {
        'memory exhausted': 0,
        'syntax is ambiguous': 0,
        'unexpected': 0,
        'end of file': 0,
        'other': 0
    }
    
    for error_msg in error_types:
        if 'memory exhausted' in error_msg:
            categories['memory exhausted'] += 1
        elif 'syntax is ambiguous' in error_msg:
            categories['syntax is ambiguous'] += 1
        elif 'unexpected' in error_msg:
            categories['unexpected'] += 1
        elif 'end of file' in error_msg:
            categories['end of file'] += 1
        else:
            categories['other'] += 1
    
    for category, count in sorted(categories.items(), key=lambda x: x[1], reverse=True):
        if count > 0:
            percentage = (count / len(error_types)) * 100
            print(f"{category:<30} {count:>10} {percentage:>7.2f}%")
    
    return error_counts

if __name__ == "__main__":
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    filename = os.path.join(script_dir, "..", "build", "parser_error_locations.log")
    analyze_parser_errors(filename)