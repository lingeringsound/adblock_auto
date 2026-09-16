import os
import sys
import tempfile
from pathlib import Path

def convert_enc_to_UTF(file_path: str, output_path: str = None) -> bool:
    src = Path(file_path)
    if not src.is_file():
        return False

    out = Path(output_path) if output_path else src
    enc = None
    bom_len = 0
    
    with open(src, "rb") as f:
        header = f.read(4)

    if header.startswith(b"\xef\xbb\xbf"):
        enc, bom_len = "utf-8-sig", 3
    elif header.startswith(b"\xff\xfe\x00\x00"):
        enc, bom_len = "utf-32-le", 4
    elif header.startswith(b"\x00\x00\xfe\xff"):
        enc, bom_len = "utf-32-be", 4
    elif header.startswith(b"\xff\xfe"):
        enc, bom_len = "utf-16-le", 2
    elif header.startswith(b"\xfe\xff"):
        enc, bom_len = "utf-16-be", 2

    raw_data = None
    if not enc:
        with open(src, "rb") as f:
            sample_data = f.read(32768)

        candidates = (
            "utf-8",
            "gb18030", "gbk", "gb2312", "cp936", "hz",
            "big5", "cp950", "big5hkscs", "euc_tw",
            "shift_jis", "cp932", "euc_jp", "iso2022_jp",
            "iso2022_jp_1", "iso2022_jp_2", "iso2022_jp_2004",
            "euc_kr", "cp494", "cp949", "iso2022_kr", "johab",
            "cp1252", "latin_1", "iso8859_15",
            "cp1250", "cp1254", "cp1253", "cp1257",
            "cp1251", "koi8_r", "koi8_u",
            "cp866", "cp1131", "cp855",
            "cp1255", "cp1256", "cp1258",
            "iso8859_2", "iso8859_3", "iso8859_4",
            "iso8859_5", "iso8859_6", "iso8859_7",
            "iso8859_8", "iso8859_9", "iso8859_10",
            "iso8859_13", "iso8859_14", "iso8859_15", "iso8859_16",
            "cp874", "tis_620",
            "cp437", "cp737", "cp775", "cp852", "cp853",
            "cp855", "cp857", "cp858", "cp860", "cp861",
            "cp863", "cp864", "cp865", "cp869",
            "mac_roman", "mac_centraleurope", "mac_croatian",
            "mac_cyrillic", "mac_greek", "mac_turkish", "mac_latin2",
            "hp_roman8"
        )

        for candidate in candidates:
            try:
                sample_data.decode(candidate)
                enc = candidate
                break
            except (UnicodeDecodeError, LookupError):
                continue

    if not enc:
        print(f"无法识别编码: {src.name}")
        return False

    if enc == "utf-8" and src.resolve() == out.resolve():
        content = src.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        src.write_bytes(content)
        return True

    display_enc = "UTF-8-BOM" if enc == "utf-8-sig" else enc.upper()
    print(f"※转换 {src.name} 编码: {display_enc} --> UTF-8")

    try:
        with open(src, "rb") as f:
            f.seek(bom_len)
            content_bytes = f.read()

        decode_enc = "utf-8" if enc == "utf-8-sig" else enc
        text = content_bytes.decode(decode_enc)

        normalized_bytes = text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")
        out.write_bytes(normalized_bytes)
        return True
    except Exception as e:
        print(f"转换失败 {src.name}: {e}")
        return False

def show_help():
    help_text = """用法:
  python convert_enc.py <源文件路径> [输出文件路径]

参数说明:
  源文件路径    指定要转换编码的目标文本文件路径。
  输出文件路径  可选。指定转换后的保存路径；若未提供，将直接覆盖源文件。
  -h, --help    显示当前帮助信息并退出。

说明:
  自动检测源文件的 BOM 头 (UTF-8-BOM / UTF-16 / UTF-32) 或穷举常见编码格式，
  将其统一转换为不带 BOM 的 UTF-8 格式，同时将 Windows 换行符 (CRLF) 规范化为 LF。
"""
    print(help_text)


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or "-h" in args or "--help" in args:
        show_help()
        sys.exit(0 if args else 1)

    src_file = args[0]
    out_file = args[1] if len(args) > 1 else None
    success = convert_enc_to_UTF(src_file, out_file)
    sys.exit(0 if success else 1)
