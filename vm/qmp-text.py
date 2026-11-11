#!/usr/bin/env python3
import sys
sh = {'!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8', '(': '9', ')': '0', '_': 'minus', '+': 'equal',
      '{': 'bracket_left', '}': 'bracket_right', ':': 'semicolon', '"': 'apostrophe', '~': 'grave_accent', '<': 'comma', '>': 'dot', '?': 'slash', '|': 'backslash'}
plain = {'-': 'minus', '=': 'equal', '[': 'bracket_left', ']': 'bracket_right', ';': 'semicolon', "'": 'apostrophe', '`': 'grave_accent',
         ',': 'comma', '.': 'dot', '/': 'slash', '\\': 'backslash', ' ': 'spc'}
# usage: qmp-text.py FILE | qmp-text.py - TEXT  -> tokens for qmp-keys.py
text = open(sys.argv[1]).read().rstrip('\n') if sys.argv[1] != '-' else sys.argv[2]
out = []
for c in text:
    if c.isalpha() and c.isascii():
        q, s = c.lower(), c.isupper()
    elif c.isdigit():
        q, s = c, False
    elif c in sh:
        q, s = sh[c], True
    elif c in plain:
        q, s = plain[c], False
    else:
        sys.exit("unsupported char")
    out += (["shift+"] if s else []) + [q + "+", "15", q + "-"] + (["shift-"] if s else []) + ["25"]
print(" ".join(out))
