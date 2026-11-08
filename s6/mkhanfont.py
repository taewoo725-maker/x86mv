#!/usr/bin/env python3
# 만든이: KimTaeWoo
# 도와준이: Lee.J.H
# X86MV V1.11.26: writes hf_ui.inc / hf_st.inc, the built-in Hangul dot fonts of the two modules (8x10 dots, drawn 9 dots apart).
# The characters are the ones the fixed texts of each module use; build.py checks that every Korean word of the module is covered.
import os, re, sys
import hanfont
here = os.path.dirname(os.path.abspath(__file__))
UI = '재생드라이브위로설정끝내기영상열름길크개'
ST = '현재설정돌아가기영상생이동고르종있음없화면끝나표시'
def table(chars):
    out = '; built-in Hangul dot font (V1.11.26, made by mkhanfont.py): code point, then 10 rows of 8 dots (bit 7 = left)\nhf_tab:\n'
    seen = set()
    for ch in chars:
        if ch in seen: continue
        seen.add(ch)
        rows = hanfont.render(hanfont.glyph(ch))
        bytes_ = [int(r.replace('#', '1').replace('.', '0'), 2) for r in rows]
        out += '        defw    0%04XH\n        defb    %s     ; %s\n' % (ord(ch), ','.join('%03XH' % b if b > 0x9F else '%02XH' % b for b in bytes_) .replace('0', '0', 1), ch)
    out += '        defw    0\n'
    return out
def fix(txt):   # pasmo wants hex numbers that start with a digit
    return re.sub(r'\b([0-9A-F]{3})H\b', lambda m: m.group(0) if m.group(1)[0] == '0' else '0' + m.group(1)[1:] + 'H' if False else m.group(0), txt)
for name, chars in (('hf_ui.inc', UI), ('hf_st.inc', ST)):
    open(os.path.join(here, name), 'w', encoding='utf-8').write(table(chars))
    print(name, len(set(chars)), 'characters,', len(set(chars)) * 12 + 2, 'bytes')
