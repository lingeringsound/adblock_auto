import sys
import re
from pathlib import Path

def fmt_short(n):
    if n >= 1_000_000:
        return f'{n / 1_000_000:.1f}m ({n})'
    if n >= 10_000:
        return f'{n / 10_000:.1f}w ({n})'
    if n >= 1_000:
        return f'{n / 1_000:.1f}k ({n})'
    return f'{n}'

def categorize_adblock_rules(file_path: str):
    path = Path(file_path)
    if not path.is_file():
        return

    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        raw_lines = f.readlines()

    cleaned_lines = []
    for line in raw_lines:
        line = line.strip()
        if not line or line.startswith("!") or line.startswith("["):
            continue
        cleaned_lines.append(line)

    unique_rules = sorted(set(cleaned_lines))

    categories = {
        "wildcard": [],
        "domain": [],
        "site_specific": [],
        "css": [],
        "whitelist": [],
        "badfilter": []
    }

    re_badfilter = re.compile(r'[\$,]badfilter\b', re.IGNORECASE)
    re_whitelist = re.compile(r'^@@|#@#')
    re_domain = re.compile(r'^\|\||^\|http')
    re_css = re.compile(r'^(##|#\?#|#%#|#@#|##\[|##\.|#\$#|#\$\?#|#@\?#)|^(#|~.*#)')
    re_site_exclude = re.compile(r'^(@@|\|\||\|http|#|/|://|_|\?|\.|-|=|\:|~|,|&|\$|\||\*)')
    re_has_css_mark = re.compile(r'#[\?%@\$]?#|##|#@\?#')

    for rule in unique_rules:
        if re_badfilter.search(rule):
            categories["badfilter"].append(rule)
        elif re_whitelist.search(rule):
            categories["whitelist"].append(rule)
        elif re_domain.search(rule):
            categories["domain"].append(rule)
        elif re_css.search(rule):
            categories["css"].append(rule)
        elif not re_site_exclude.search(rule):
            if not re_has_css_mark.search(rule) and ("/" in rule or "$" in rule):
                categories["wildcard"].append(rule)
            else:
                categories["site_specific"].append(rule)
        else:
            if re_has_css_mark.search(rule):
                categories["site_specific"].append(rule)
            else:
                categories["wildcard"].append(rule)

    sections = [
        ("通配符规则", categories["wildcard"]),
        ("域名规则", categories["domain"]),
        ("网站单独规则", categories["site_specific"]),
        ("通用Css规则", categories["css"]),
        ("放行白名单", categories["whitelist"]),
        ("Badfilter 废弃规则", categories["badfilter"]),
    ]

    output_lines = [""]
    for name, rules in sections:
        if len(rules) > 0:
             # 旧版本格式，暂时先用这个
            output_lines.append(f"! >>>>>> {name} · {fmt_short(len(rules))} <<<<<<")
            output_lines.extend(rules)
            output_lines.append(f"! >>>>>> {name} 结束 <<<<<<\n")
#            output_lines.append(f"! [{name}] ====> {fmt_short(len(rules))}")
#            output_lines.extend(rules)
#            output_lines.append(f"! [{name} 结束] <==== \n")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))

if __name__ == "__main__":
    if len(sys.argv) > 1:
        categorize_adblock_rules(sys.argv[1])
    else:
        print(f"用法: python {sys.argv[0]} <规则文件路径>")
