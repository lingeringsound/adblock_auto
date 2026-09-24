import sys
import re
import os

def print_help():
    help_text = f"""使用方法: python {sys.argv[0]} <action> <file_path>

可用操作 (actions):
  css_conflict           剔除与 #@# 白名单冲突的 ## CSS 规则
  wipe_selector          清理带有相同限定符参数的重复 || 域名拦截规则
  clear_white            清除已在 ||domain^ 拦截规则中存在的纯域名白名单
  clear_white_rules      清除和domain=~ 冲突的规则
  css_selector_not_clean 清除与带有 :not() 的 CSS 规则相冲突的通用 CSS 隐藏规则
  fixed_error            修复规则语法中的常见错误（引号、空格、属性选择器等）
  help, -h, --help       显示本帮助信息
"""
    print(help_text)

def clear_css_selector_not_conflict(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()

    not_pattern = re.compile(r'^(##)(.+)(:not\(.*\))$')
    conflict_targets = set()

    for line in lines:
        sline = line.strip()
        match = not_pattern.match(sline)
        if match:
            conflict_targets.add(match.group(1) + match.group(2))

    if not conflict_targets:
        return

    new_lines = [line for line in lines if line.strip() not in conflict_targets]

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

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
    bare_rules = set()
    
    for line in lines:
        sline = line.strip()
        if not sline or sline.startswith('!'):
            continue
        if '$' not in sline:
            bare_rules.add(sline)
        if sline.startswith('||'):
            if 'domain=' in sline:
                continue
            cleaned = strip_pat.sub('', sline)
            if cleaned == sline and '$' not in sline:
                bare_rules.add(cleaned)
            counts[cleaned] = counts.get(cleaned, 0) + 1

    duplicates = {k for k, v in counts.items() if v > 1}
    targets_prefix = tuple(f"{dup}$" for dup in duplicates) if duplicates else ()

    new_lines = []
    for line in lines:
        sline = line.strip()
        if not sline or sline.startswith('!'):
            new_lines.append(line)
            continue

        if '$domain=' in sline and '$domain=~' not in sline:
            prefix, opts = sline.split('$domain=', 1)
            domain_val = opts.split(',')[0]
            reconstructed = f"{prefix}$domain={domain_val}"
            if reconstructed == sline and prefix in bare_rules:
                continue

        if targets_prefix and line.startswith(targets_prefix):
            if 'redirect-rule=' in line or 'domain=' in line or 'redirect=' in line:
                new_lines.append(line)
                continue
            cleaned = strip_pat.sub('', line)
            if cleaned in bare_rules and cleaned in duplicates:
                continue
            new_lines.append(line)
        else:
            new_lines.append(line)

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

    white_rules_prefix = set()
    for line in lines:
        sline = line.strip()
        if 'domain=~' in sline and '#' not in sline:
            prefix = sline.split('$')[0].strip()
            if prefix:
                white_rules_prefix.add(prefix)

    if not white_rules_prefix:
        return

    new_lines = []
    for line in lines:
        sline = line.strip()
        if not sline or sline.startswith('!'):
            new_lines.append(line)
            continue

        if 'domain=~' in sline:
            new_lines.append(line)
            continue

        prefix = sline.split('$')[0].strip()
        if prefix in white_rules_prefix:
            continue

        new_lines.append(line)

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
    elif action == "css_selector_not_clean":
        clear_css_selector_not_conflict(target_file)
    elif action == "fixed_error":
        fixed_Rules_error(target_file)
    else:
        print(f"错误: 未知的 action '{action}'\n")
        print_help()
        sys.exit(1)
