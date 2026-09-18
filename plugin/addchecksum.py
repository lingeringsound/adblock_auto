#!/usr/bin/env python3
import sys
import re
import hashlib
import base64
import time
import os

def read_file(path):
    with open(path, 'rb') as f:
        return f.read()

def write_file(path, data):
    with open(path, 'wb') as f:
        f.write(data)

def md5_base64(data: bytes) -> str:
    digest = hashlib.md5(data).digest()
    return base64.b64encode(digest).decode('ascii').rstrip('=')

def calc_checksum(data: bytes) -> str:
    data = data.translate(None, b'\r')
    data = re.sub(rb'\n+', b'\n', data)
    return md5_base64(data)

def process_file(file_path):
    data = read_file(file_path)
    data = re.sub(
        rb'^.*!\s*checksum[\s\-:]+[\w\+/=]+.*\n',
        b'',
        data,
        flags=re.MULTILINE | re.IGNORECASE
    )

# 2026.09.18 废弃，只做Checksum修改这一件事
#    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
#    now = time.localtime()
#    todaysdate = f"{now.tm_mday} {months[now.tm_mon - 1]} {now.tm_year}".encode('ascii')

#    data = re.sub(
#        rb'^(.*!.*Updated:\s*)(.*?)(\r?\n|$)',
#        lambda m: m.group(1) + todaysdate + m.group(3),
#        data,
#        flags=re.MULTILINE | re.IGNORECASE
#    )

    checksum = calc_checksum(data)

    data = re.sub(
        rb'(\r?\n)',
        rb'\1! Checksum: ' + checksum.encode('ascii') + rb'\1',
        data,
        count=1
    )

    write_file(file_path, data)

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.executable} {sys.argv[0]} subscription.txt", file=sys.stderr)
        sys.exit(1)

    for file_path in sys.argv[1:]:
        if not os.path.isfile(file_path):
            print(f"Could not read file '{file_path}'", file=sys.stderr)
            sys.exit(1)
        process_file(file_path)

if __name__ == '__main__':
    main()