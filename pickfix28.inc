; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ---- the colours of this format: b6_mp = dark, light, bar, text (MV8: a GRB byte, MVA-MVC: grey Y values; there is no palette in the file) ----
b6_pick:ld      hl,b6_fix
        ld      de,b6_mp
        ld      bc,4
        ldir
IF MODFMT = 'A'
        ld      a,(m8_fmt)              ; the badge says SC10 / SC11 / SC12; SCREEN 12 has 5 bits of Y (F8h), 10 and 11 have 4 (F0h)
        ld      c,a
        sub     'A'-'0'
        ld      (b6_name+3),a
        ld      a,c
        cp      'C'
        ret     nz
        ld      a,0F8h
        ld      (b6_mp+1),a
        ld      (b6_mp+3),a
ENDIF
        ret
IF MODFMT = '8'
b6_fix: defb    00h,0FFh,27h,0FFh
ELSE
b6_fix: defb    00h,0F0h,40h,0F0h
ENDIF
