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

    def get_domain_signature(line):
        if '$' not in line or 'domain=' not in line:
            return None, None
        
        base, opts_str = line.split('$', 1)
        opts = [o.strip() for o in opts_str.split(',') if o.strip()]

        if 'badfilter' in opts:
            return None, None

        domain_val = None
        other_opts = []
        for opt in opts:
            if opt.startswith('domain='):
                domain_val = opt.split('domain=', 1)[1]
            elif opt.startswith('denyallow='):
                da_val = opt.split('denyallow=', 1)[1]
                sorted_da = "|".join(sorted(list(set([d.strip() for d in da_val.split('|') if d.strip()]))))
                other_opts.append(f"denyallow={sorted_da}")
            else:
                other_opts.append(opt)
        if not domain_val:
            return None, None
        sorted_other = ",".join(sorted(other_opts))
        sig = f"{base}${sorted_other}" if sorted_other else f"{base}$"
        return sig, domain_val

    sig_groups = {}
    for line in unique_lines:
        sig, d_val = get_domain_signature(line)
        if sig:
            if sig not in sig_groups:
                sig_groups[sig] = []
            sig_groups[sig].append((d_val, line))

    for sig, items in sig_groups.items():
        if len(items) <= 1:
            continue
        all_domains = []
        matched_lines = []
        for d_val, raw_line in items:
            matched_lines.append(raw_line)
            all_domains.extend(d_val.split('|'))
        unique_domains = sorted(list(set([d.strip() for d in all_domains if d.strip()])))
        merged_tail = "|".join(unique_domains)

        base, opts_part = sig.split('$', 1)
        if opts_part:
            new_rule = f"{base}${opts_part},domain={merged_tail}"
        else:
            new_rule = f"{base}$domain={merged_tail}"

        matched_set = set(matched_lines)
        unique_lines = [l for l in unique_lines if l not in matched_set]
        unique_lines.append(new_rule)

    final_lines = [l.replace('换行符正则表达式n', '\\') for l in unique_lines]

    with open(target_file, 'w', encoding='utf-8') as f:
        f.write("\n".join(final_lines) + "\n")

def sort_denyallow_Combine(target_file):
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

    def get_denyallow_signature(line):
        if '$' not in line or 'denyallow=' not in line:
            return None, None, None
        base, opts_str = line.split('$', 1)
        opts = [o.strip() for o in opts_str.split(',') if o.strip()]

        if 'badfilter' in opts:
            return None, None, None

        denyallow_val = None
        domain_val = None
        other_opts = []
        for opt in opts:
            if opt.startswith('denyallow='):
                denyallow_val = opt.split('denyallow=', 1)[1]
            elif opt.startswith('domain='):
                domain_val = opt.split('domain=', 1)[1]
            else:
                other_opts.append(opt)
        if not denyallow_val:
            return None, None, None
        
        if domain_val is not None and denyallow_val == domain_val:
            sorted_other = ",".join(sorted(other_opts))
            sig = f"{base}${sorted_other}#SAME_DOMAIN_DENYALLOW"
        else:
            if domain_val is not None:
                sorted_d = "|".join(sorted(list(set([d.strip() for d in domain_val.split('|') if d.strip()]))))
                other_opts.append(f"domain={sorted_d}")
            sorted_other = ",".join(sorted(other_opts))
            sig = f"{base}${sorted_other}" if sorted_other else f"{base}$"
            
        return sig, denyallow_val, domain_val

    sig_groups = {}
    for line in unique_lines:
        sig, da_val, d_val = get_denyallow_signature(line)
        if sig:
            if sig not in sig_groups:
                sig_groups[sig] = []
            sig_groups[sig].append((da_val, d_val, line))

    for sig, items in sig_groups.items():
        if len(items) <= 1:
            continue
        
        matched_lines = [item[2] for item in items]
        all_vals = []
        for item in items:
            all_vals.extend(item[0].split('|'))
        unique_vals = sorted(list(set([v.strip() for v in all_vals if v.strip()])))
        merged_val = "|".join(unique_vals)

        if sig.endswith("#SAME_DOMAIN_DENYALLOW"):
            base_sig = sig.replace("#SAME_DOMAIN_DENYALLOW", "")
            base, opts_part = base_sig.split('$', 1)
            if opts_part:
                new_rule = f"{base}${opts_part},denyallow={merged_val},domain={merged_val}"
            else:
                new_rule = f"{base}$denyallow={merged_val},domain={merged_val}"
        else:
            base, opts_part = sig.split('$', 1)
            if opts_part:
                new_rule = f"{base}${opts_part},denyallow={merged_val}"
            else:
                new_rule = f"{base}$denyallow={merged_val}"

        matched_set = set(matched_lines)
        unique_lines = [l for l in unique_lines if l not in matched_set]
        unique_lines.append(new_rule)

    final_lines = [l.replace('换行符正则表达式n', '\\') for l in unique_lines]

    with open(target_file, 'w', encoding='utf-8') as f:
        f.write("\n".join(final_lines) + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"用法: python {sys.argv[0]} [css|domain|denyallow] <规则文件路径>")
        sys.exit(1)
    mode = sys.argv[1]
    target = sys.argv[2]
    if mode == "css":
        sort_Css_Combine(target)
    elif mode == "domain":
        sort_domain_Combine(target)
    elif mode == "denyallow":
        sort_denyallow_Combine(target)
    else:
        print("模式错误，请使用 'css'、'domain' 或 'denyallow'")
        sys.exit(1)
