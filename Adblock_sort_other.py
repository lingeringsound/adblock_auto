import sys
import re
import os

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

    strip_patterns = [
        r'\$third-party$', r'\$popup$', r'\$third-party,important$', 
        r'\$popup,third-party$', r'\$third-party,popup$', r'\$script$', 
        r'\$image$', r'\$image,third-party$', r'\$third-party,image$', 
        r'\$script,third-party$', r'\$third-party,script$'
    ]
    
    counts = {}
    domain_rules = []
    
    for line in lines:
        if line.startswith('||'):
            cleaned = line
            for pat in strip_patterns:
                cleaned = re.sub(pat, '', cleaned)
            if 'domain=' in cleaned or cleaned.startswith('!') or not cleaned.strip():
                continue
            domain_rules.append((line, cleaned))
            counts[cleaned] = counts.get(cleaned, 0) + 1

    duplicates = {k for k, v in counts.items() if v > 1}
    
    if not duplicates:
        return

    new_lines = []
    for line in lines:
        is_deleted = False
        for dup in duplicates:
            escaped_dup = re.escape(dup).replace(r'\$', r'\\\$')
            if re.match(f"^{escaped_dup}\\$", line):
                is_deleted = True
                break
        if not is_deleted:
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

    remove_set = set()
    for line in lines:
        if 'domain=~' in line:
            if '#' in line:
                continue
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
        (r'\$app=', ''),
        (r'=“', '="'),
        (r'^[ \t\r\n\x00-\x1f\x7f]', ''),
        (r'\*=“', '*="'),
        (r'\^=“', '^="'),
        (r'\$=“', '$="'),
        (r'”\]', '"]'),
        (r'\]\]', ']'),
        (r'\[\[', '['),
        (r'([^#])[ \t\r\n\x00-\x1f\x7f\.\/\$]##', r'\1##'),
        (r'([^#])##[ \t\r\n\x00-\x1f\x7f\$]', r'\1##'),
        (r'###[ \t\r\n\x00-\x1f\x7f\.#\$]', '###'),
        (r'##([0-9]+)', r'##\\\1'),
        (r'##\.\[', '##['),
        (r'^##[ \t\r\n\x00-\x1f\x7f\$]', '##'),
        (r'[ \t]+\|', '|'),
        (r'\|[ \t]+', '|'),
        (r'([^:])\:(after|before)', r'\1::\2')
    ]

    def lowercase_match(match):
        return match.group(0).lower()

    new_lines = []
    for line in lines:
        for pat, rep in replacements:
            line = re.sub(pat, rep, line)
        line = re.sub(r'##[A-Z]+\[', lowercase_match, line)
        new_lines.append(line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines) + '\n')

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)
    action = sys.argv[1]
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
