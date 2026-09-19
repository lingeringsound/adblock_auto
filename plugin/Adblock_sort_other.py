import sys
import re
import os

def print_help():
    help_text = f"""使用方法: python {sys.argv[0]} <action> <file_path>

可用操作 (actions):
  css_conflict       剔除与 #@# 白名单冲突的 ## CSS 规则
  wipe_selector      清理带有相同限定符参数的重复 || 域名拦截规则
  clear_white        清除已在 ||domain^ 拦截规则中存在的纯域名白名单
  clear_white_rules  清除带有 domain=~ 的域名排除规则
  fixed_error        修复规则语法中的常见错误（引号、空格、属性选择器等）
  help, -h, --help   显示本帮助信息
"""
    print(help_text)

def fixed_css_white_conflict(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()
    
    white_list = set()
    for line in lines:
        if line.startswith('#@#'):
            white_list.add('##' + line[3:])
            
    new_lines = [line for line in lines if line not in white_list]
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

def wipe_same_selector_fiter(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()

    strip_pat = re.compile(
        r'\$(third-party|popup|third-party,important|popup,third-party|'
        r'third-party,popup|script|image|image,third-party|third-party,image|'
        r'script,third-party|third-party,script)$'
    )
    
    counts = {}
    
    for line in lines:
        if line.startswith('||'):
            cleaned = strip_pat.sub('', line)
            if 'domain=' in cleaned or cleaned.startswith('!') or not cleaned.strip():
                continue
            counts[cleaned] = counts.get(cleaned, 0) + 1

    duplicates = {k for k, v in counts.items() if v > 1}
    
    if not duplicates:
        return

    targets_prefix = tuple(f"{dup}$" for dup in duplicates)
    new_lines = [line for line in lines if not line.startswith(targets_prefix)]

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

def clear_domain_white_list(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()

    domain_set = set()
    domain_pattern = re.compile(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]{1,5})?(/[^ ]*)?')
    
    for line in lines:
        if line.startswith('!') or '#' in line or '$' in line:
            continue
        if domain_pattern.match(line):
            domain_set.add(line.strip())

    existing_filters = set()
    for line in lines:
        if line.startswith('||') and '^' in line:
            core = line[2:].split('^')[0]
            existing_filters.add(core)

    to_remove = domain_set.intersection(existing_filters)
    new_lines = [line for line in lines if line.strip() not in to_remove]

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

def clear_domain_white_Rules(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()

    remove_set = set()
    for line in lines:
        if 'domain=~' in line and '#' not in line:
            cleaned = line.split('$')[0]
            remove_set.add(cleaned)

    new_lines = [line for line in lines if line not in remove_set]

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

def fixed_Rules_error(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()

    replacements = [
        (re.compile(r'\$app='), ''),
        (re.compile(r'=“'), '="'),
        (re.compile(r'^[ \t\r\n\x00-\x1f\x7f]+'), ''),
        (re.compile(r'\*=“'), '*="'),
        (re.compile(r'\^=“'), '^="'),
        (re.compile(r'\$=“'), '$="'),
        (re.compile(r'”\]'), '"]'),
        (re.compile(r'\]\]'), ']'),
        (re.compile(r'\[\['), '['),
        (re.compile(r'([^#])[ \t\r\n\x00-\x1f\x7f\.\/\$]##'), r'\1##'),
        (re.compile(r'([^#])##[ \t\r\n\x00-\x1f\x7f\$]'), r'\1##'),
        (re.compile(r'###[ \t\r\n\x00-\x1f\x7f\.#\$]'), '###'),
        (re.compile(r'##([0-9]+)'), r'##\\\1'),
        (re.compile(r'##\.\['), '##['),
        (re.compile(r'^##[ \t\r\n\x00-\x1f\x7f\$]'), '##'),
        (re.compile(r'[ \t]+\|'), '|'),
        (re.compile(r'\|[ \t]+'), '|'),
        (re.compile(r'([^:])\:(after|before)'), r'\1::\2')
    ]

    tag_pattern = re.compile(r'(##|#@#)(.*)')
    upper_tag_pattern = re.compile(
        r'(?<![a-zA-Z0-9_-])(A|ABBR|ARTICLE|ASIDE|AUDIO|B|BODY|BUTTON|CANVAS|DIV|EM|FOOTER|FORM|H1|H2|H3|H4|H5|H6|HEADER|IFRAME|IMG|INPUT|INS|LB|LI|MAIN|NAV|OL|OPTION|P|SECTION|SELECT|SPAN|STRONG|TABLE|TD|TR|UL|VIDEO)(?![a-zA-Z0-9_-])'
    )

    def lower_tags(match):
        prefix = match.group(1)
        selector = match.group(2)
        parts = re.split(r'(\[[^\]]*\])', selector)
        for i in range(0, len(parts), 2):
            parts[i] = upper_tag_pattern.sub(lambda m: m.group(1).lower(), parts[i])
        return prefix + ''.join(parts)

    new_lines = []
    for line in lines:
        for pat, rep in replacements:
            line = pat.sub(rep, line)
        if '##' in line or '#@#' in line:
            line = tag_pattern.sub(lower_tags, line)
        new_lines.append(line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print_help()
        sys.exit(1)

    action = sys.argv[1]

    if action in ("help", "-h", "--help"):
        print_help()
        sys.exit(0)

    if len(sys.argv) < 3:
        print("错误: 缺少参数 <file_path>\n")
        print_help()
        sys.exit(1)

    target_file = sys.argv[2]

    if action == "css_conflict":
        fixed_css_white_conflict(target_file)
    elif action == "wipe_selector":
        wipe_same_selector_fiter(target_file)
    elif action == "clear_white":
        clear_domain_white_list(target_file)
    elif action == "clear_white_rules":
        clear_domain_white_Rules(target_file)
    elif action == "fixed_error":
        fixed_Rules_error(target_file)
    else:
        print(f"错误: 未知的 action '{action}'\n")
        print_help()
        sys.exit(1)
