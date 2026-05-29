"""
一键放大所有 .gd 文件中的字体
用法: 在项目根目录运行
    python scale_fonts.py            # 默认放大 1.5 倍
    python scale_fonts.py 1.8        # 自定义倍率
    python scale_fonts.py --dry-run  # 预览（不改文件）
"""
import re
import os
import sys
import glob


def scale_fonts_in_file(filepath: str, factor: float, dry_run: bool = False) -> int:
    """放大一个文件中所有 add_theme_font_size_override 的字号，返回改动数"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    count = 0

    def replace_font_size(m: re.Match) -> str:
        nonlocal count
        prefix = m.group("prefix")
        size = int(m.group("size"))
        suffix = m.group("suffix")
        new_size = max(10, round(size * factor))
        if new_size != size:
            count += 1
        return f'{prefix}{new_size}{suffix}'

    pattern = re.compile(
        r'(?P<prefix>add_theme_font_size_override\("(?:font_size|normal_font_size)",\s*)'
        r'(?P<size>\d+)'
        r'(?P<suffix>\s*\))'
    )
    content = pattern.sub(replace_font_size, content)

    if count == 0:
        return 0

    if dry_run:
        print(f"\n  [{filepath}]  将修改 {count} 处字体")
        # 显示几处改动示例
        for m in pattern.finditer(original):
            size = int(m.group("size"))
            new_size = max(10, round(size * factor))
            if new_size != size:
                print(f"    {size} → {new_size}")
        return count

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    return count


def main():
    factor = 1.5
    dry_run = False

    for arg in sys.argv[1:]:
        if arg == '--dry-run':
            dry_run = True
        else:
            try:
                factor = float(arg)
            except ValueError:
                print(f"⚠ 参数无效: {arg}，使用默认倍率 1.5")

    project_dir = os.path.dirname(os.path.abspath(__file__))
    scripts_dir = os.path.join(project_dir, 'scripts')
    gd_files = glob.glob(os.path.join(scripts_dir, '**', '*.gd'), recursive=True)

    if not gd_files:
        print("找不到 .gd 文件，路径: " + scripts_dir)
        return

    total_count = 0
    changed_files = 0

    print(f"{'[预览模式] ' if dry_run else ''}放大倍率: {factor}x")
    print(f"扫描文件数: {len(gd_files)}\n")

    for fp in sorted(gd_files):
        rel = os.path.relpath(fp, project_dir)
        try:
            n = scale_fonts_in_file(fp, factor, dry_run)
            if n > 0:
                changed_files += 1
                total_count += n
                if not dry_run:
                    print(f"  ✓ {rel}: {n} 处字号已修改")
        except Exception as e:
            print(f"  ✗ {rel}: 错误 - {e}")

    print(f"\n{'[预览] ' if dry_run else ''}修改完成: {changed_files} 个文件，共 {total_count} 处字体")
    if not dry_run and total_count > 0:
        print("请在 Godot 中刷新项目查看效果！")
    if dry_run:
        print("\n去除 --dry-run 参数以实际执行修改。")


if __name__ == '__main__':
    main()
