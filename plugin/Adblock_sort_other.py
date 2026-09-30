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
  wipe_badfilter         去除 badfilter 对应规则
  help, -h, --help       显示本帮助信息
"""
    print(help_text)

def clear_css_selector_not_conflict(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()

    def split_top_level_commas(text):
        parts = []
        depth = 0
        quote = None
        escape = False
        start = 0
        for i, ch in enumerate(text):
            if escape:
                escape = False
                continue
            if ch == '\\':
                escape = True
                continue
            if quote:
                if ch == quote:
                    quote = None
                continue
            if ch in ('"', "'"):
                quote = ch
                continue
            if ch in '([':
                depth += 1
            elif ch in ')]':
                depth -= 1
            elif ch == ',' and depth == 0:
                parts.append(text[start:i])
                start = i + 1
        parts.append(text[start:])
        return [p.strip() for p in parts if p.strip()]

    def normalize_not_arg(arg):
        arg = arg.strip()
        if arg.startswith('##'):
            arg = arg[1:]
        return arg

    def parse_css_not_rule(sline):
        if sline.startswith('#@#'):
            rule_type = '#@#'
            rest = sline[3:]
        elif sline.startswith('##'):
            rule_type = '##'
            rest = sline[2:]
        else:
            return None

        idx = rest.find(':not(')
        if idx == -1:
            return None
        base = rest[:idx]
        nots = []
        pos = idx
        while pos < len(rest):
            if not rest.startswith(':not(', pos):
                return None
            depth = 1
            j = pos + 5
            quote = None
            escape = False
            while j < len(rest) and depth > 0:
                ch = rest[j]
                if escape:
                    escape = False
                elif ch == '\\':
                    escape = True
                elif quote:
                    if ch == quote:
                        quote = None
                elif ch in ('"', "'"):
                    quote = ch
                elif ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            if depth != 0:
                return None
            content = rest[pos + 5:j]
            for arg in split_top_level_commas(content):
                arg = normalize_not_arg(arg)
                if arg not in nots:
                    nots.append(arg)
            pos = j + 1
        return (rule_type, base, nots)

    def parse_css_plain_rule(sline):
        if sline.startswith('#@#'):
            rule_type = '#@#'
            rest = sline[3:]
        elif sline.startswith('##'):
            rule_type = '##'
            rest = sline[2:]
        else:
            return None
        if ':not(' in rest:
            return None
        return (rule_type, rest)

    groups = {}
    plain_groups = {}

    for idx, line in enumerate(lines):
        sline = line.strip()
        if not sline:
            continue
        parsed = parse_css_not_rule(sline)
        if parsed:
            rule_type, base, nots = parsed
            key = (rule_type, base)
            if key not in groups:
                groups[key] = {'indices': [], 'nots': []}
            groups[key]['indices'].append(idx)
            for n in nots:
                if n not in groups[key]['nots']:
                    groups[key]['nots'].append(n)
            continue
        parsed_plain = parse_css_plain_rule(sline)
        if parsed_plain:
            rule_type, base = parsed_plain
            key = (rule_type, base)
            if key not in plain_groups:
                plain_groups[key] = []
            plain_groups[key].append(idx)

    if not groups:
        return

    inter_merge = {}
    for (rule_type, base), group in groups.items():
        if rule_type == '##':
            inter_merge[base] = group['nots']

    to_remove = set()
    inserts = {}

    for (rule_type, base), group in groups.items():
        if rule_type == '##':
            nots = group['nots']
            merged_line = '##' + base + ''.join(f':not({n})' for n in nots)
            first_idx = min(group['indices'])
            inserts[first_idx] = merged_line
            to_remove.update(group['indices'])
            for idx in plain_groups.get(('##', base), []):
                to_remove.add(idx)
        elif rule_type == '#@#':
            if base in inter_merge:
                nots = inter_merge[base]
            else:
                nots = group['nots']
            merged_line = '#@#' + base + ''.join(f':not({n})' for n in nots)
            first_idx = min(group['indices'])
            inserts[first_idx] = merged_line
            to_remove.update(group['indices'])

    for base, nots in inter_merge.items():
        if ('#@#', base) in groups:
            continue
        plain_indices = plain_groups.get(('#@#', base), [])
        if not plain_indices:
            continue
        merged_line = '#@#' + base + ''.join(f':not({n})' for n in nots)
        first_idx = plain_indices[0]
        if first_idx in inserts:
            if isinstance(inserts[first_idx], list):
                inserts[first_idx].append(merged_line)
            else:
                inserts[first_idx] = [inserts[first_idx], merged_line]
        else:
            inserts[first_idx] = merged_line

    new_lines = []
    for idx, line in enumerate(lines):
        if idx in inserts:
            val = inserts[idx]
            if isinstance(val, list):
                new_lines.extend(val)
            else:
                new_lines.append(val)
        if idx not in to_remove:
            new_lines.append(line)

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

    def parse_line(line):
        sline = line.strip()
        if not sline or sline.startswith('!'):
            return None
        prefix = ''
        if sline.startswith('@@'):
            prefix = '@@'
            sline = sline[2:]
            
        if '$' in sline:
            pattern, opts_str = sline.rsplit('$', 1)
            options = [o.strip() for o in opts_str.split(',') if o.strip()]
        else:
            pattern = sline
            options = []
        return (prefix, pattern, options, line)

    def is_pure_domain(options):
        if len(options) != 1:
            return False
        opt = options[0]
        return opt.startswith('domain=') and not opt.startswith('domain=~')

    def extract_domain_set(options):
        for opt in options:
            if opt.startswith('domain=') and not opt.startswith('domain=~'):
                return frozenset(opt[7:].split('|'))
        return None

    groups = {}
    for idx, line in enumerate(lines):
        parsed = parse_line(line)
        if not parsed:
            continue
        prefix, pattern, options, _ = parsed
        
        if not pattern:
            continue
            
        key = (prefix, pattern)
        if key not in groups:
            groups[key] = []
        groups[key].append((idx, options))

    to_remove = set()

    for key, group in groups.items():
        if len(group) <= 1:
            continue

        process_group = []
        for idx, options in group:
            has_domain = any(opt.startswith('domain=') for opt in options)
            has_redirect = any(opt.startswith('redirect-rule=') or opt.startswith('redirect=') for opt in options)
            has_important = any(opt == 'important' for opt in options)
            if (has_domain and len(options) > 1) or has_redirect or has_important:
                continue
            process_group.append((idx, options))

        if not process_group:
            continue

        no_opt = [(idx, opt) for idx, opt in process_group if not opt]
        with_opt = [(idx, opt) for idx, opt in process_group if opt]

        pure_domain_seen = set()
        new_with_opt = []
        for idx, opt in with_opt:
            if is_pure_domain(opt):
                ds = extract_domain_set(opt)
                if ds is None:
                    new_with_opt.append((idx, opt))
                    continue
                if ds in pure_domain_seen:
                    to_remove.add(idx)
                else:
                    pure_domain_seen.add(ds)
            else:
                new_with_opt.append((idx, opt))
        with_opt = new_with_opt

        if no_opt:
            has_tp = any('third-party' in opt for _, opt in with_opt)
            has_neg_tp = any('~third-party' in opt for _, opt in with_opt)
            has_neg_xhr = any(any(o.startswith('~') and o != '~third-party' for o in opt) for _, opt in with_opt)
            has_priority = any(('third-party' in opt) or ('image' in opt) for _, opt in with_opt)
            if has_neg_xhr:
                for idx, opt in no_opt:
                    to_remove.add(idx)
                for idx, opt in with_opt:
                    if any(o.startswith('~') and o != '~third-party' for o in opt):
                        continue
                    else:
                        to_remove.add(idx)
            elif has_tp and has_neg_tp:
                for idx, opt in with_opt:
                    to_remove.add(idx)
            elif has_priority:
                for idx, opt in no_opt:
                    to_remove.add(idx)
                for idx, opt in with_opt:
                    if 'third-party' in opt or 'image' in opt:
                        continue
                    else:
                        to_remove.add(idx)
            else:
                for idx, opt in with_opt:
                    to_remove.add(idx)
        else:
            if not with_opt:
                continue
            if key[0] == '@@':
                min_len = min(len(opt) for _, opt in with_opt)
                for idx, opt in with_opt:
                    if len(opt) > min_len:
                        to_remove.add(idx)
            else:
                has_neg = any(any(o.startswith('~') and o != '~third-party' for o in opt) for _, opt in with_opt)
                if has_neg:
                    for idx, opt in with_opt:
                        if any(o.startswith('~') and o != '~third-party' for o in opt):
                            continue
                        else:
                            to_remove.add(idx)
                else:
                    min_len = min(len(opt) for _, opt in with_opt)
                    for idx, opt in with_opt:
                        if len(opt) > min_len:
                            to_remove.add(idx)

    new_lines = [line for idx, line in enumerate(lines) if idx not in to_remove]

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

def wipe_badfilter(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.read().splitlines()

    badfilter_pattern = re.compile(r'(\$|,)badfilter')
    to_remove = set()

    for line in lines:
        sline = line.strip()
        if not badfilter_pattern.search(sline):
            continue
        select_after = re.sub(r',badfilter$', '', sline)
        select_after = re.sub(r',badfilter,', ',', select_after)
        select_after = re.sub(r'\$badfilter', '', select_after)
        to_remove.add(select_after)

    new_lines = [line for line in lines if line.strip() not in to_remove]

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

    def parse_rule_info(sline):
        if '$' not in sline:
            return sline, [], None
        prefix, opts_str = sline.split('$', 1)
        opts = opts_str.split(',')
        other_opts = []
        domain_opt = None
        for opt in opts:
            if opt.startswith('domain='):
                domain_opt = opt[7:]
            else:
                other_opts.append(opt)
        other_opts.sort()
        return prefix, other_opts, domain_opt

    white_exact_signatures = set()
    white_prefixes_has_neg_domain = set()

    for line in lines:
        sline = line.strip()
        if not sline or sline.startswith('!') or '#' in sline:
            continue
        prefix, other_opts, domain_opt = parse_rule_info(sline)
        if domain_opt and '~' in domain_opt:
            white_prefixes_has_neg_domain.add(prefix)
            sig = f"{prefix}${','.join(other_opts)}" if other_opts else prefix
            white_exact_signatures.add(sig)

    if not white_exact_signatures:
        return

    new_lines = []
    for line in lines:
        sline = line.strip()
        if not sline or sline.startswith('!') or '#' in sline:
            new_lines.append(line)
            continue

        prefix, other_opts, domain_opt = parse_rule_info(sline)

        if domain_opt:
            if '~' in domain_opt:
                new_lines.append(line)
            else:
                sig = f"{prefix}${','.join(other_opts)}" if other_opts else prefix
                if sig in white_exact_signatures:
                    continue
                new_lines.append(line)
        else:
            if not other_opts:
                if prefix in white_prefixes_has_neg_domain:
                    continue
            else:
                sig = f"{prefix}${','.join(other_opts)}"
                if sig in white_exact_signatures:
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
    elif action == "wipe_badfilter":
        wipe_badfilter(target_file)
    else:
        print(f"错误: 未知的 action '{action}'\n")
        print_help()
        sys.exit(1)
