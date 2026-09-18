import os
import re
import sys
from collections import Counter

def sort_Css_Combine(target_file):
    if not os.path.isfile(target_file):
        return
    with open(target_file, 'r', encoding='utf-8', errors='ignore') as f:
        raw_lines = f.readlines()
    css_common_record = []

    for line in raw_lines:
        s_line = line.strip()
        if s_line.startswith('#') and not s_line.startswith('!'):
            css_common_record.append(line.rstrip('\r\n'))
    content = "".join(raw_lines)
    content = content.replace('\\n', '换行符正则表达式nn')
    lines = content.splitlines()
    unique_lines = []
    seen = set()

    for line in lines:
        s_line = line.strip()
        if not s_line or s_line.startswith('!') or (s_line.startswith('[') and s_line.endswith(']')):
            continue
        if line not in seen:
            seen.add(line)
            unique_lines.append(line)
    selectors_pool = []

    for line in unique_lines:
        if '#' in line:
            if line.startswith('#') or line.startswith('!') or line.startswith('||') or line.startswith('/'):
                continue
            cleaned_suffix = re.sub(r'.*\.[A-Za-z]{2,8}#', '', line)
            selectors_pool.append(cleaned_suffix)
    counter = Counter(selectors_pool)
    duplicated_selectors = [sel for sel, count in counter.items() if count > 1]

    for target_content in duplicated_selectors:
        css_suffix = "#" + target_content
        matched_lines = [l for l in unique_lines if l.endswith(css_suffix)]
        if not matched_lines:
            continue
        domain_parts = [l.split('#')[0] for l in matched_lines]
        has_comma = any(',' in d for d in domain_parts)
        if has_comma:
            sub_domains = []
            for d in domain_parts:
                sub_domains.extend(d.split(','))
            unique_sub_domains = sorted(list(set([sd.strip() for sd in sub_domains if sd.strip()])))
            merged_domains = ",".join(unique_sub_domains)
        else:
            unique_sub_domains = sorted(list(set([d.strip() for d in domain_parts if d.strip()])))
            merged_domains = ",".join(unique_sub_domains)

        if merged_domains or css_suffix:
            new_rule = merged_domains + css_suffix
            unique_lines = [l for l in unique_lines if not l.endswith(css_suffix)]
            unique_lines.append(new_rule)

    unique_lines.extend(css_common_record)
    final_lines = [l.replace('换行符正则表达式n', '\\') for l in unique_lines]

    with open(target_file, 'w', encoding='utf-8') as f:
        f.write("\n".join(final_lines) + "\n")


def sort_domain_Combine(target_file):
    if not os.path.isfile(target_file):
        return

    with open(target_file, 'r', encoding='utf-8', errors='ignore') as f:
        raw_lines = f.readlines()

    content = "".join(raw_lines)
    content = content.replace('\\n', '换行符正则表达式nn')
    
    lines = content.splitlines()
    unique_lines = []
    seen = set()
    for line in lines:
        s_line = line.strip()
        if not s_line or s_line.startswith('!') or (s_line.startswith('[') and s_line.endswith(']')):
            continue
        if line not in seen:
            seen.add(line)
            unique_lines.append(line)

    prefixes_pool = []
    for line in unique_lines:
        if 'domain=' in line:
            prefix = line.split('domain=')[0]
            if prefix.strip() != '':
                prefixes_pool.append(prefix)

    counter = Counter(prefixes_pool)
    duplicated_prefixes = [p for p, count in counter.items() if count > 1]

    option_keywords = re.compile(
        r',(important|third-party|script|media|subdocument|document|xmlhttprequest|other|stealth|'
        r'image|stylesheet|content|match-case|font|sitekey|popup|xhr|object|generichide|genericblock|'
        r'elemhide|all|badfilter|websocket|~important|~third-party|~script|~media|~subdocument|'
        r'~document|~xmlhttprequest|~other|~stealth|~image|~stylesheet|~content|~match-case|~font|'
        r'~sitekey|~popup|~xhr|~object|~generichide|~genericblock|~elemhide|~all|~badfilter|~websocket)$'
    )

    for target_prefix in duplicated_prefixes:
        search_str = target_prefix + "domain="
        matched_lines = [l for l in unique_lines if l.startswith(search_str)]
        if not matched_lines:
            continue
        tails = [l.split('domain=', 1)[1] for l in matched_lines]
        has_comma = any(',' in t for t in tails)
        
        if has_comma:
            cleaned_tails = []
            for t in tails:
                t_rstrip = t.rstrip()
                if option_keywords.search(t_rstrip):
                    continue
                cleaned_tails.append(t_rstrip)
            
            cleaned_tails = sorted(list(set([ct for ct in cleaned_tails if ct.strip()])))
            if len(cleaned_tails) <= 1:
                continue

            if any('|' in t for t in cleaned_tails):
                domains = []
                for t in cleaned_tails:
                    domains.extend(t.split('|'))
                unique_domains = sorted(list(set([d.strip() for d in domains if d.strip()])))
                merged_tail = "|".join(unique_domains)
            else:
                unique_domains = sorted(list(set([t.strip() for t in cleaned_tails if t.strip()])))
                merged_tail = "|".join(unique_domains)
        else:
            if any('|' in t for t in tails):
                domains = []
                for t in tails:
                    domains.extend(t.split('|'))
                unique_domains = sorted(list(set([d.strip() for d in domains if d.strip()])))
                merged_tail = "|".join(unique_domains)
            else:
                unique_domains = sorted(list(set([t.strip() for t in tails if t.strip()])))
                merged_tail = "|".join(unique_domains)

        if merged_tail:
            new_rule = search_str + merged_tail
            unique_lines = [l for l in unique_lines if not l.startswith(search_str)]
            unique_lines.append(new_rule)

    final_lines = [l.replace('换行符正则表达式n', '\\') for l in unique_lines]

    with open(target_file, 'w', encoding='utf-8') as f:
        f.write("\n".join(final_lines) + "\n")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: python script.py [css|domain] <规则文件路径>")
        sys.exit(1)
    mode = sys.argv[1]
    target = sys.argv[2]
    if mode == "css":
        sort_Css_Combine(target)
    elif mode == "domain":
        sort_domain_Combine(target)
    else:
        print("模式错误，请使用 'css' 或 'domain'")
        sys.exit(1)