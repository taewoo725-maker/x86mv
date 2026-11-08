# 만든이: KimTaeWoo
# 도와준이: Lee.J.H
# 8x10 Hangul dot font built from jamo strokes (X86MV V1.11.26).  glyph(ch) -> 10 strings of 8 chars
W, H = 8, 10
def line(c, x0, y0, x1, y1):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        t = i / n if n else 0
        c.add((round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)))
def hl(c, x0, x1, y):
    for x in range(x0, x1 + 1): c.add((x, y))
def vl(c, x, y0, y1):
    for y in range(y0, y1 + 1): c.add((x, y))

# ---- consonants in the box x0..x1, y0..y1 ----
def c_g(c, x0, y0, x1, y1): hl(c, x0, x1, y0); vl(c, x1, y0, y1)
def c_n(c, x0, y0, x1, y1): vl(c, x0, y0, y1); hl(c, x0, x1, y1)
def c_d(c, x0, y0, x1, y1): hl(c, x0, x1, y0); vl(c, x0, y0, y1); hl(c, x0, x1, y1)
def c_r(c, x0, y0, x1, y1):
    ym = (y0 + y1) // 2
    hl(c, x0, x1, y0); vl(c, x1, y0, ym); hl(c, x0, x1, ym); vl(c, x0, ym, y1); hl(c, x0, x1, y1)
def c_m(c, x0, y0, x1, y1): hl(c, x0, x1, y0); hl(c, x0, x1, y1); vl(c, x0, y0, y1); vl(c, x1, y0, y1)
def c_b(c, x0, y0, x1, y1):
    ym = (y0 + y1) // 2 if y1 - y0 >= 4 else y0 + (y1 - y0) // 2 + 0
    vl(c, x0, y0, y1); vl(c, x1, y0, y1); hl(c, x0, x1, ym); hl(c, x0, x1, y1)
def c_s(c, x0, y0, x1, y1):
    w = x1 - x0 + 1
    if w % 2:  # odd: one-pixel apex
        cx = (x0 + x1) // 2
        line(c, cx, y0, x0, y1); line(c, cx, y0, x1, y1)
    else:
        a, b = (x0 + x1) // 2, (x0 + x1) // 2 + 1
        line(c, a, y0, x0, y1); line(c, b, y0, x1, y1); c.add((a, y0)); c.add((b, y0))
def c_o(c, x0, y0, x1, y1):
    hl(c, x0 + 1, x1 - 1, y0); hl(c, x0 + 1, x1 - 1, y1); vl(c, x0, y0 + 1, y1 - 1); vl(c, x1, y0 + 1, y1 - 1)
def c_j(c, x0, y0, x1, y1):
    hl(c, x0, x1, y0); c_s(c, x0, y0 + 1, x1, y1)
def c_k(c, x0, y0, x1, y1):
    c_g(c, x0, y0, x1, y1); hl(c, x0, x1, (y0 + y1) // 2)
def c_p(c, x0, y0, x1, y1):
    hl(c, x0, x1, y0); hl(c, x0, x1, y1); vl(c, x0 + 1, y0, y1); vl(c, x1 - 1, y0, y1)
def c_h(c, x0, y0, x1, y1):
    if x1 - x0 == 3 and y1 - y0 >= 4:        # narrow box: drawn by hand
        art = ['.##.', '####', '#..#', '#..#', '#..#', '.##.']
        art = art[:3] + art[3:3 + (y1 - y0 - 3)] + art[5:] if y1 - y0 == 5 else art[:4] + art[5:]
        for dy, r in enumerate(art):
            for dx, ch in enumerate(r):
                if ch == '#': c.add((x0 + dx, y0 + dy))
        return
    cx = (x0 + x1) // 2
    hl(c, cx - 1, cx + 1 if (x1 - x0) % 2 == 0 else cx, y0); hl(c, x0, x1, y0 + 1)
    c_o(c, x0 + 1, y0 + 3, x1 - 1, y1)
def c_t(c, x0, y0, x1, y1):
    hl(c, x0, x1, y0); hl(c, x0, x1, y1); hl(c, x0, x1, (y0 + y1) // 2); vl(c, x0, y0, y1)
def c_gg(c, x0, y0, x1, y1):
    w = x1 - x0 + 1; h = w // 2
    c_g(c, x0, y0, x0 + h - 1 if h > 1 else x0 + 1, y1); c_g(c, x1 - h + 1 if h > 1 else x1 - 1, y0, x1, y1)
def c_ss(c, x0, y0, x1, y1):
    w = x1 - x0 + 1; h = w // 2
    c_s(c, x0, y0, x0 + h - 1, y1); c_s(c, x1 - h + 1, y0, x1, y1)
def c_bs(c, x0, y0, x1, y1):
    c_b(c, x0, y0, x0 + 3, y1); c_s(c, x1 - 3, y0, x1, y1)
CONS = {'ㄱ': c_g, 'ㄴ': c_n, 'ㄷ': c_d, 'ㄹ': c_r, 'ㅁ': c_m, 'ㅂ': c_b, 'ㅅ': c_s, 'ㅇ': c_o, 'ㅈ': c_j, 'ㅋ': c_k,
        'ㅍ': c_p, 'ㅎ': c_h, 'ㅌ': c_t, 'ㄲ': c_gg, 'ㅆ': c_ss, 'ㅄ': c_bs}
CHO = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ'
JUNG = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ'
JONG = ' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ'
def split(ch):
    n = ord(ch) - 0xAC00
    return CHO[n // 588], JUNG[(n % 588) // 28], JONG[n % 28]

def glyph(ch, over=None):
    if over and ch in over: return over[ch]
    i, v, f = split(ch)
    c = set()
    fin = f != ' '
    if v in 'ㅏㅐㅓㅕㅣ':              # vertical vowel on the right
        top = 4 if fin else 9
        y0 = 0 if fin else 1
        y1 = 4 if fin else 8
        stem = 6
        cx1 = {'ㅏ': 4, 'ㅣ': 4, 'ㅐ': 3, 'ㅓ': 3, 'ㅕ': 3}[v]
        CONS[i](c, 0, y0, cx1, y1)
        if v == 'ㅐ': stem = 7
        vl(c, stem, 0, top + (1 if fin else 0))
        ym = 2 if fin else 4
        if v == 'ㅏ': c.add((7, ym))
        if v == 'ㅓ': c.add((5, ym))
        if v == 'ㅕ': c.add((5, ym - 1)); c.add((5, ym + 1))
        if v == 'ㅐ': vl(c, 5, 0, top + (1 if fin else 0)); c.add((6, ym))
    elif v in 'ㅗㅜㅡㅛㅠ':             # horizontal vowel below
        if fin:
            ch_ = 3 if v in 'ㅗㅛ' else 3
            CONS[i](c, 1, 0, 6, 2 if v in 'ㅗㅛ' else 3)
            by = 4
        else:
            CONS[i](c, 1, 0, 6, 5 if v in 'ㅗㅛ' else 5)
            by = 8 if v in 'ㅗㅛ' else 6
            if v == 'ㅡ': by = 7
        hl(c, 0, 7, by)
        if v == 'ㅗ': vl(c, 3, by - 1, by - 1); c.add((4, by - 1))
        if v == 'ㅛ': c.add((2, by - 1)); c.add((5, by - 1))
        if v == 'ㅜ': c.add((3, by + 1)); c.add((4, by + 1))
        if v == 'ㅠ': c.add((2, by + 1)); c.add((5, by + 1))
        if v == 'ㅜ' and not fin: c.add((3, by + 2)); c.add((4, by + 2))
    elif v in 'ㅘㅟ':                  # mixed: a horizontal part under the consonant, a vertical stem on the right
        top = 4 if fin else 9
        CONS[i](c, 0, 0, 3, 3 if fin else 5)
        by = 4 if fin else 7
        hl(c, 0, 4, by)
        if v == 'ㅘ': c.add((2, by - 1)); c.add((1, by - 1)) if False else None
        if v == 'ㅟ': c.add((2, by + 1)); c.add((2, by + 2)) if not fin else None
        vl(c, 6, 0, top + (1 if fin else 0))
        if v == 'ㅘ': c.add((7, 2 if fin else 4))
    else:
        raise ValueError(ch)
    if fin:
        if f == 'ㄹ': CONS[f](c, 1, 5, 6, 9)
        elif f == 'ㅇ': CONS[f](c, 1, 6, 6, 9)
        else: CONS[f](c, 1, 6, 6, 9)
    return c

def render(c):
    return [''.join('#' if (x, y) in c else '.' for x in range(W)) for y in range(H)]

if __name__ == '__main__':
    import sys
    s = sys.argv[1]
    rows = [''] * H
    for ch in s:
        g = render(glyph(ch))
        for y in range(H): rows[y] += g[y] + '.'
    print('\n'.join(rows))
