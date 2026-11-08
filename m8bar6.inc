; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  m8bar6.inc - V1.11.28 (all formats; V1.11.27: MV6): the playback bar of design D (blue bar in rows 192..211 under the picture, the SCR6 badge top right, the pause sign).
;  Everything is drawn into RAM canvases (2 bits a dot, like SCREEN 6) and copied to the page that is not on screen after the picture:
;    bar canvas   BARC  512 x 20  (128 bytes a row)           -> rows 192..211, one 2560 byte write
;    badge canvas BDGD/BDGM 9 bytes x 14 rows (16 a row)      -> dots + mask, mixed into the picture rows 4..17 (bytes 118..126)
;    pause canvas BUF (free after the picture) 16 x 40        -> dots + mask, mixed into rows 76..115 (bytes 56..71)
;  The canvases are drawn again only when the bar changed (second, volume, colours, shown / hidden); the progress knob alone redraws 10 rows.
;  Colours come from the palette of the picture (m8_pal, 4 entries): dark = darkest, light = lightest, bar = the bluest of the rest, text = dark on a
;  bright bar, light on a dark one.
; ============================================================
; ---- V1.11.28: one source for every format (MODFMT = the letter of the module).  The canvases always have 2 bits a dot (a role: dark, light, bar,
;      text; in MV6 the number of a palette entry).  MV6 sends them as they are; the other formats expand them to their own dots (b6_ex).
;      Layout: 512 dots wide (MV6, MV7) or 256 (MV5, MV8, MVA-MVC: the same look at half the width).
IF (MODFMT = '6') OR (MODFMT = '7')
CVR     equ     128                     ; canvas bytes a row
CVSH    equ     7
XPREV   equ     9
XPILL   equ     28
PILLW   equ     32
XPICON  equ     38
XNEXT   equ     67
XCUR    equ     92
XTRK    equ     128
TRKW    equ     262
XREM    equ     398
XVOL    equ     446
XSTEP   equ     462
XSET    equ     498
BDGRX   equ     2                       ; the badge in its canvas (origin = byte 118 = dot 472)
BDGTX   equ     6
BDGOB   equ     118
PAUOB   equ     56                      ; the pause sign: origin dot 224
PAUW    equ     64
PAUIW   equ     60
PAUB1   equ     17
PAUB2   equ     39
PAUBW   equ     8
PITCH6  equ     1                       ; volume steps 6 dots apart
ELSE
CVR     equ     64
CVSH    equ     6
XPREV   equ     3
XPILL   equ     16
PILLW   equ     24
XPICON  equ     22
XNEXT   equ     44
XCUR    equ     60
XTRK    equ     93
TRKW    equ     63
XREM    equ     159
XVOL    equ     198
XSTEP   equ     212
XSET    equ     239
BDGRX   equ     4                       ; origin dot 216
BDGTX   equ     8
BDGOB   equ     54
PAUOB   equ     28                      ; origin dot 112
PAUW    equ     32
PAUIW   equ     28
PAUB1   equ     9
PAUB2   equ     20
PAUBW   equ     4
PITCH6  equ     0                       ; 5 dots apart
ENDIF
IF MODFMT = '6'
EXP     equ     1                       ; picture bytes for one canvas byte (4 dots)
ELSE
IF (MODFMT = '7') OR (MODFMT = '5')
EXP     equ     2
ELSE
EXP     equ     4
ENDIF
ENDIF
IF (MODFMT = '6') OR (MODFMT = '5')
OS      equ     128                     ; bytes of a picture row in the VRAM
BARADD  equ     1                       ; the bar rows 192..211: R#14 + 1, address 2000h
BARHI   equ     60h
ELSE
OS      equ     256
BARADD  equ     3                       ; R#14 + 3, address 0
BARHI   equ     40h
ENDIF
IF (MODFMT = '5') OR (MODFMT = '7')
NPAL    equ     16
ELSE
NPAL    equ     4
ENDIF
H1      equ     (TRKW+1)/2              ; the track is drawn in two halves (a width is one byte)
H2      equ     TRKW-H1
CLW     equ     (TRKW+10)/2
BARC    equ     OVB                     ; CVR * 20 bytes
BDGD    equ     OVB+CVR*20              ; 224 bytes (14 rows of 16)
BDGM    equ     OVB+CVR*20+224
BDGA    equ     4*OS+BDGOB*EXP          ; the badge: picture row 4
PAUA    equ     76*OS+PAUOB*EXP         ; the pause sign: picture rows 76..115
PAUD    equ     BUF                     ; 640 bytes, then the mask 640 bytes (BUF is free here; the font at BUF+3200h is not touched)
PAUM    equ     BUF+640
RB1     equ     BUF+1300                ; one picture row (64 bytes), its dots and its mask expanded
RB2     equ     BUF+1364
RB3     equ     BUF+1428
TABD    equ     0B1C0h                  ; the expansion tables (BUF+31C0h..31FFh: free, the font starts at BUF+3200h)
TABM    equ     0B1E0h

; ---- the canvas primitives.  x is relative to the canvas (a multiple of 4 is its left edge), y too.  cv_b = base, cv_sh = log2 (bytes a row), cv_c = colour ----
; address of the dot: HL = x, E = y -> HL = byte address, A = dot in byte (0..3); clobbers B, C, DE.  y << cv_sh = y rotated by cv_rt, split by the mask cv_mk
b_adr:  ld      a,l
        and     3
        push    af
        srl     h
        rr      l
        srl     h
        rr      l
        ld      a,(cv_rt)
        ld      b,a
        ld      a,e
ba_r:   rrca
        djnz    ba_r
        ld      c,a
        ld      a,(cv_mk)
        ld      d,a
        and     c
        ld      e,a
        ld      a,d
        cpl
        and     c
        ld      d,a
        add     hl,de
        ld      de,(cv_b)
        add     hl,de
        pop     af
        ret

; one dot (HL = x, E = y), nothing is changed in the registers
b_px:   push    hl
        push    de
        push    bc
        call    b_adr
        ld      c,a
        ld      a,(cv_c)
        rrca
        rrca
        ld      d,a                     ; the colour in the top two bits
        ld      e,0C0h                  ; the mask of dot 0
        inc     c
        jr      bp_t
bp_l:   srl     e
        srl     e
        srl     d
        srl     d
bp_t:   dec     c
        jr      nz,bp_l
        ld      a,e
        cpl
        and     (hl)
        or      d
        ld      (hl),a
        pop     bc
        pop     de
        pop     hl
        ret

; the colour A (0..3) in all four dots of a byte -> A; clobbers B
b_c55:  ld      b,a
        add     a,a
        add     a,a
        or      b
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      b
        ret

; a horizontal line: HL = x, E = y, B = width.  Whole bytes where it can, single dots at the ends
b_hs:   ld      a,b
        or      a
        ret     z
        ld      a,l
        and     3
        jr      nz,hs_p
        ld      a,b
        cp      4
        jr      c,hs_p
        push    hl
        push    de
        push    bc
        call    b_adr
        ld      a,(cv_c)
        call    b_c55
        pop     bc
        ld      c,a                     ; the byte
        ld      a,b
        rrca
        rrca
        and     3Fh                     ; width / 4 bytes
        ld      d,a
        ld      a,c
hs_f:   ld      (hl),a
        inc     hl
        dec     d
        jr      nz,hs_f
        pop     de
        pop     hl
        ld      a,b
        and     0FCh
        add     a,l
        ld      l,a
        jr      nc,hs_n
        inc     h
hs_n:   ld      a,b
        and     3
        ld      b,a
        jr      b_hs
hs_p:   call    b_px
        inc     hl
        dec     b
        jr      b_hs

; a rectangle: HL = x, E = y, B = width, C = height
b_rc:   ld      a,c
        or      a
        ret     z
        push    hl
        push    de
        push    bc
        call    b_hs
        pop     bc
        pop     de
        pop     hl
        inc     e
        dec     c
        jr      b_rc

; a rectangle with the four corners cut in steps of ch_n dots: HL = x, E = y, B = width, C = height
b_ch:   xor     a
        ld      (ch_i),a
ch_l:   ld      a,c
        or      a
        ret     z
        dec     a
        ld      d,a                     ; the rows below this one
        ld      a,(ch_i)
        cp      d
        jr      c,ch_m
        ld      a,d
ch_m:   ld      d,a                     ; the depth (rows from the nearer edge)
        ld      a,(ch_n)
        sub     d
        jr      nc,ch_o
        xor     a
ch_o:   ld      d,a                     ; the cut of this row
        push    hl
        push    bc
        ld      a,l
        add     a,d
        ld      l,a
        jr      nc,ch_a
        inc     h
ch_a:   ld      a,d
        add     a,a
        ld      d,a
        ld      a,b
        sub     d
        ld      b,a
        call    b_hs
        pop     bc
        pop     hl
        inc     e
        ld      a,(ch_i)
        inc     a
        ld      (ch_i),a
        dec     c
        jr      ch_l

; patterns of 6 dots (bits 7..2), bm_c rows, step bm_s bytes: IX = first byte, HL = x, E = y -> HL = x + 6.  The address is worked out once a row
b_bm:   push    de
        ld      (bm_x),hl
        ld      a,e
        ld      (bm_y),a
        ld      a,(cv_c)
        call    b_c55
        ld      (cv_cc),a
bm_r:   ld      a,(bm_y)
        ld      e,a
        ld      hl,(bm_x)
        call    b_adr
        ld      c,0C0h                  ; the mask of the first dot
        or      a
        jr      z,bm_m
bm_s:   srl     c
        srl     c
        dec     a
        jr      nz,bm_s
bm_m:   ld      d,(ix+0)
        ld      b,6
bm_b:   sla     d
        jr      nc,bm_k
        ld      a,c
        cpl
        and     (hl)
        ld      e,a
        ld      a,(cv_cc)
        and     c
        or      e
        ld      (hl),a
bm_k:   srl     c
        srl     c
        jr      nz,bm_n
        ld      c,0C0h
        inc     hl
bm_n:   djnz    bm_b
        ld      a,(bm_s0)
        ld      e,a
        ld      d,0
        add     ix,de
        ld      hl,bm_y
        inc     (hl)
        ld      hl,bm_c
        dec     (hl)
        jr      nz,bm_r
        ld      hl,(bm_x)
        ld      de,6
        add     hl,de
        pop     de
        ret

; a 12 x 6 icon: IX = its 12 bytes, HL = x, E = y
b_ic:   ld      a,6
        ld      (bm_c),a
        ld      a,2
        ld      (bm_s0),a
        push    ix
        call    b_bm
        pop     ix
        inc     ix
        ld      a,6
        ld      (bm_c),a
        jp      b_bm

; a glyph of the main program's 6 x 8 font: A = character, HL = x, E = y -> HL = x + 6
b_gl:   push    hl
        sub     20h
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,fontc
        add     hl,bc
        push    hl
        pop     ix
        pop     hl
        ld      a,8
        ld      (bm_c),a
        ld      a,1
        ld      (bm_s0),a
        jp      b_bm

; a text: HL = x, DE = the 0 ended string, bs_y = y
b_st:   ld      a,(de)
        or      a
        ret     z
        inc     de
        push    de
        ld      c,a
        ld      a,(bs_y)
        ld      e,a
        ld      a,c
        call    b_gl
        pop     de
        jr      b_st

; ---- minutes and seconds: HL = seconds, DE = the place for "MM:SS",0 ----
b6_mm:  push    de
        ld      de,60
        call    div16                   ; HL = minutes, DE = seconds
        push    de
        ld      a,h
        or      a
        ld      a,99
        jr      nz,mm_1
        ld      a,l
        cp      100
        jr      c,mm_1
        ld      a,99
mm_1:   pop     bc                      ; C = seconds
        pop     hl                      ; the place
        call    b6_d2
        ld      (hl),':'
        inc     hl
        ld      a,c
        call    b6_d2
        ld      (hl),0
        ret
b6_d2:  ld      b,'0'                   ; A = 0..99 -> two digits at (HL)
d2_l:   sub     10
        jr      c,d2_e
        inc     b
        jr      d2_l
d2_e:   add     a,'0'+10
        ld      (hl),b
        inc     hl
        ld      (hl),a
        inc     hl
        ret

IF (MODFMT = '5') OR (MODFMT = '6') OR (MODFMT = '7')
; ---- the colours of this picture: b6_dk, b6_lt, b6_bar, b6_tx (palette entries 0..3 of m8_pal: RB, G) ----
b6_pick:ld      hl,m8_pal
        ld      de,b6_br
        ld      b,NPAL
pk_l:   push    bc
        ld      a,(hl)                  ; R*16 + B
        inc     hl
        ld      c,a
        ld      a,(hl)                  ; G
        inc     hl
        and     7
        ld      b,a
        ld      a,c
        and     7
        add     a,b
        ld      b,a
        ld      a,c
        rrca
        rrca
        rrca
        rrca
        and     7
        add     a,b
        pop     bc
        ld      (de),a                  ; brightness
        inc     de
        djnz    pk_l
        ld      hl,b6_br                ; dark = the first smallest, light = the first largest
        ld      a,(hl)
        ld      c,a
        ld      (pk_mx),a
        ld      e,0
        ld      d,0
        ld      b,1
        inc     hl
pk_m:   ld      a,(hl)
        cp      c
        jr      nc,pk_n
        ld      c,a
        ld      e,b
pk_n:   ld      a,(pk_mx)
        cp      (hl)
        jr      nc,pk_o
        ld      a,(hl)
        ld      (pk_mx),a
        ld      d,b
pk_o:   inc     hl
        inc     b
        ld      a,b
        cp      NPAL
        jr      c,pk_m
        ld      a,e
        ld      (b6_mp),a
        ld      a,d
        ld      (b6_mp+1),a
        ; bar = the bluest of the others: score 2B - R - G + 16
        ld      hl,m8_pal
        ld      b,0
        ld      d,0                     ; its index
pk_b:   ld      a,(b6_mp)
        cp      b
        jr      z,pk_x
        ld      a,(b6_mp+1)
        cp      b
        jr      z,pk_x
        ld      a,(hl)
        push    af
        and     7
        add     a,a
        ld      e,a                     ; 2B
        pop     af
        rrca
        rrca
        rrca
        rrca
        and     7
        ld      c,a                     ; R (the score below keeps its own register)
        ld      a,e
        sub     c
        inc     hl
        ld      c,a
        ld      a,(hl)
        dec     hl
        and     7
        ld      e,a
        ld      a,c
        sub     e
        add     a,16
        ld      c,a                     ; score of this entry
        ld      a,(pk_bs)
        cp      c
        jr      nc,pk_x
        ld      a,c
        ld      (pk_bs),a
        ld      d,b
pk_x:   inc     hl
        inc     hl
        inc     b
        ld      a,b
        cp      NPAL
        jr      c,pk_b
        ld      a,d
        ld      (b6_mp+2),a
        ; text: dark on a bright bar (brightness >= 11), else light
        ld      hl,b6_br
        ld      c,a
        ld      b,0
        add     hl,bc
        ld      a,(hl)
        cp      11
        ld      a,(b6_mp)
        jr      nc,pk_t
        ld      a,(b6_mp+1)
pk_t:   ld      (b6_mp+3),a
        ld      a,0
        ld      (pk_bs),a
        ret
pk_bs:  defb    0
pk_mx:  defb    0

ELSE
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
ENDIF

; ---- progress: HL = TRKW * cur / nframes (0..TRKW) ----
b6_prog:ld      hl,(cur)
        ld      de,(nframes)
bp_a:   ld      a,d
        or      a
        jr      nz,bp_b
        ld      a,e
        cp      251
        jr      c,bp_c
bp_b:   srl     d
        rr      e
        srl     h
        rr      l
        jr      bp_a
bp_c:   ld      a,h
        or      a
        jr      nz,bp_f
        ld      a,e
        or      a
        jr      z,bp_f
        ld      b,l
        ld      hl,0
        ld      a,b
        or      a
        jr      z,bp_d
        push    de
        ld      de,TRKW
bp_m:   add     hl,de
        djnz    bp_m
        pop     de
bp_d:   call    div16
        ld      de,TRKW+1
        or      a
        sbc     hl,de
        add     hl,de
        ret     c
bp_f:   ld      hl,TRKW
        ret

; ---- canvas set up: HL = base, A = log2 of the bytes a row ----
b6_cvs: ld      (cv_b),hl
        ld      b,a
        ld      a,8
        sub     b
        ld      (cv_rt),a
        ld      a,0FFh
cs_l:   add     a,a
        djnz    cs_l
        ld      (cv_mk),a
        ret
b6_zero:ld      (hl),0                  ; HL = start, BC = bytes - 1
        ld      d,h
        ld      e,l
        inc     de
        ldir
        ret

; ---- the whole bar again (shown or hidden) ----
b6_stat:
IF EXP > 1
        call    b6_tab
ENDIF
        ld      hl,BARC
        ld      a,CVSH
        call    b6_cvs
        ld      a,(b6_sn+2)
        or      a
        ld      a,(b6_dk)
        jr      z,bs_f                  ; hidden: all dark
        ld      a,(b6_bar)
bs_f:   call    b_c55
        ld      hl,BARC
        ld      (hl),a
        ld      de,BARC+1
        ld      bc,CVR*20-1
        ldir
        ld      a,(b6_sn+2)
        or      a
        ret     z
        ld      a,(b6_tx)
        ld      (cv_c),a
        ld      ix,ic6_prev
        ld      hl,XPREV
        ld      e,6
        call    b_ic
        ld      ix,ic6_next
        ld      hl,XNEXT
        ld      e,6
        call    b_ic
        ld      ix,ic6_vol
        ld      hl,XVOL
        ld      e,7
        call    b_ic
        ld      ix,ic6_set
        ld      hl,XSET
        ld      e,7
        call    b_ic
        ld      a,6
        ld      (bs_y),a
        ld      hl,(b6_sn+4)            ; the time now
        ld      de,b6_t1
        call    b6_mm
        ld      hl,XCUR
        ld      de,b6_t1
        call    b_st
        ld      a,(b6_lt)
        ld      (cv_c),a
        ld      a,2                     ; the play / pause pill
        ld      (ch_n),a
        ld      hl,XPILL
        ld      e,2
        ld      b,PILLW
        ld      c,16
        call    b_ch
        ld      a,(b6_bar)
        ld      (cv_c),a
        ld      ix,ic6_pause
        ld      a,(b6_sn+3)
        or      a
        jr      z,bs_p
        ld      ix,ic6_play
bs_p:   ld      hl,XPICON
        ld      e,7
        call    b_ic
        ld      hl,(nframes)            ; the time left
        ld      de,15
        call    div16
        ld      de,(b6_sn+4)
        or      a
        sbc     hl,de
        jr      nc,bs_r
        ld      hl,0
bs_r:   ld      de,b6_t2+1
        ld      a,'-'
        ld      (b6_t2),a
        call    b6_mm
        ld      a,(b6_lt)
        ld      (cv_c),a
        ld      hl,XREM
        ld      de,b6_t2
        call    b_st
        ; the volume steps: 5 columns of width 4, height 2 4 6 8 10, the lowest dot in row 207
        xor     a
        ld      (vs_i),a
vs_l:   ld      a,(vs_i)
        ld      e,a
IF PITCH6
        add     a,a
        add     a,e
        add     a,a
ELSE
        add     a,a
        add     a,a
        add     a,e
ENDIF
        ld      l,a
        ld      h,0
        ld      bc,XSTEP
        add     hl,bc
        ld      a,(vs_i)
        inc     a
        add     a,a
        ld      c,a                     ; height
        ld      a,16
        sub     c
        ld      e,a                     ; top row
        ld      a,(b6_sn+6)
        ld      b,a
        ld      a,(vs_i)
        add     a,b
        cp      5
        jr      nc,vs_off
        ld      a,(b6_lt)
        ld      (cv_c),a
        ld      b,4
        call    b_rc
        jr      vs_n
vs_off: ld      (vs_x),hl               ; a step that is off: a checker of 2 x 2 dark squares
        ld      a,e
        ld      (vs_y),a
        ld      a,(b6_dk)
        ld      (cv_c),a
        ld      a,(vs_i)
        inc     a
        ld      c,a
        ld      d,0
ck_r:   push    bc
        push    de
        ld      hl,(vs_x)
        ld      a,d
        and     1
        jr      z,ck_a
        inc     hl
        inc     hl
ck_a:   ld      a,d
        add     a,a
        ld      b,a
        ld      a,(vs_y)
        add     a,b
        ld      e,a
        ld      bc,0202h
        call    b_rc
        pop     de
        pop     bc
        inc     d
        dec     c
        jr      nz,ck_r
vs_n:   ld      hl,vs_i
        inc     (hl)
        ld      a,(hl)
        cp      5
        jr      c,vs_l
        call    b6_bdg                  ; the badge (its own canvas)
        ; and the progress
b6_trk: ld      hl,BARC
        ld      a,CVSH
        call    b6_cvs
        ld      a,(b6_bar)              ; the 10 rows of the track: clear
        ld      (cv_c),a
        ld      hl,XTRK-4
        ld      e,5
        ld      bc,CLW*256+10
        call    b_rc
        ld      hl,XTRK-4+CLW
        ld      e,5
        ld      bc,CLW*256+10
        call    b_rc
        ld      a,(b6_dk)               ; the track
        ld      (cv_c),a
        ld      hl,XTRK
        ld      e,8
        ld      bc,H1*256+4
        call    b_rc
        ld      hl,XTRK+H1
        ld      e,8
        ld      bc,H2*256+4
        call    b_rc
        ld      a,(b6_lt)               ; the part played
        ld      (cv_c),a
        ld      hl,(b6_sn)
        ld      a,h
        or      a
        jr      nz,tk_b
        ld      a,l
        cp      H1+1
        jr      c,tk_a
tk_b:   ld      a,H1
tk_a:   ld      b,a
        ld      hl,XTRK
        ld      e,8
        ld      c,4
        call    b_rc
        ld      hl,(b6_sn)
        ld      de,H1
        or      a
        sbc     hl,de
        jr      c,tk_k
        ld      a,l
        or      h
        jr      z,tk_k
        ld      b,l
        ld      hl,XTRK+H1
        ld      e,8
        ld      c,4
        call    b_rc
tk_k:   ld      hl,(b6_sn)              ; the knob: dark frame 6 x 10, light inside 4 x 8
        ld      de,XTRK-3
        add     hl,de
        push    hl
        ld      a,(b6_dk)
        ld      (cv_c),a
        ld      e,5
        ld      b,6
        ld      c,10
        call    b_rc
        pop     hl
        inc     hl
        ld      a,(b6_lt)
        ld      (cv_c),a
        ld      e,6
        ld      b,4
        ld      c,8
        jp      b_rc

; ---- the badge: dots into BDGD, the shape (mask) into BDGM ----
b6_bdg: ld      hl,BDGD
        ld      bc,447
        call    b6_zero
        ld      hl,BDGD
        ld      a,4
        call    b6_cvs
        ld      a,2
        ld      (ch_n),a
        ld      a,(b6_bar)
        ld      (cv_c),a
        ld      hl,BDGRX
        ld      e,0
        ld      b,32
        ld      c,14
        call    b_ch
        ld      a,(b6_tx)
        ld      (cv_c),a
        ld      a,3
        ld      (bs_y),a
        ld      hl,BDGTX
        ld      de,b6_name
        call    b_st
        ld      hl,BDGM
        ld      a,4
        call    b6_cvs
        ld      a,3
        ld      (cv_c),a
        ld      hl,BDGRX
        ld      e,0
        ld      b,32
        ld      c,14
        jp      b_ch

; the sign for a paused picture, drawn into BUF and mixed into the picture rows 76..115
b6_pau: ld      hl,PAUD
        ld      bc,1279
        call    b6_zero
        ld      hl,PAUD
        ld      a,4
        call    b6_cvs
        ld      a,3
        ld      (ch_n),a
        ld      a,(b6_lt)
        ld      (cv_c),a
        ld      hl,0
        ld      e,0
        ld      b,PAUW
        ld      c,40
        call    b_ch
        ld      a,2
        ld      (ch_n),a
        ld      a,(b6_dk)
        ld      (cv_c),a
        ld      hl,2
        ld      e,2
        ld      b,PAUIW
        ld      c,36
        call    b_ch
        ld      a,(b6_lt)
        ld      (cv_c),a
        ld      hl,PAUB1
        ld      e,12
        ld      b,PAUBW
        ld      c,16
        call    b_rc
        ld      hl,PAUB2
        ld      e,12
        ld      b,PAUBW
        ld      c,16
        call    b_rc
        ld      hl,PAUM
        ld      a,4
        call    b6_cvs
        ld      a,3
        ld      (ch_n),a
        ld      (cv_c),a
        ld      hl,0
        ld      e,0
        ld      b,PAUW
        ld      c,40
        call    b_ch
        ld      hl,PAUA
        ld      (rm_a),hl
        ld      hl,PAUD
        ld      (rm_d),hl
        ld      hl,PAUM
        ld      (rm_m),hl
        ld      a,PAUW/4
        ld      (rm_w),a
        ld      a,40
        ld      (rm_n),a
        jr      b_rmw

b6_put: ld      hl,BDGA                 ; the badge: picture rows 4..17
        ld      (rm_a),hl
        ld      hl,BDGD
        ld      (rm_d),hl
        ld      hl,BDGM
        ld      (rm_m),hl
        ld      a,9
        ld      (rm_w),a
        ld      a,14
        ld      (rm_n),a
; rows of the picture mixed with a canvas: (picture and not mask) or dots.  rm_a = address of the first row in the page that is not on screen,
; rm_w = canvas bytes a row (the picture row has rm_w * EXP bytes)
b_rmw:  ld      hl,(rm_a)
        xor     a
        call    b_va
        ld      hl,RB1
        call    rm_pw
        ld      c,98h
        inir
IF EXP > 1
        ld      hl,(rm_d)
        ld      de,RB2
        ld      a,(rm_w)
        ld      b,a
        ld      a,TABD & 0FFh
        call    b6_ex
        ld      hl,(rm_m)
        ld      de,RB3
        ld      a,(rm_w)
        ld      b,a
        ld      a,TABM & 0FFh
        call    b6_ex
        ld      de,RB2
        ld      ix,RB3
ELSE
        ld      de,(rm_d)
        ld      ix,(rm_m)
ENDIF
        ld      hl,RB1
        call    rm_pw
rm_c:   ld      a,(ix+0)
        cpl
        and     (hl)
        ld      c,a
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     hl
        inc     de
        inc     ix
        djnz    rm_c
        ld      hl,(rm_a)
        ld      a,40h
        call    b_va
        ld      hl,RB1
        call    rm_pw
        ld      c,98h
        otir
        ld      hl,(rm_a)
        ld      de,OS
        add     hl,de
        ld      (rm_a),hl
        ld      hl,(rm_d)
        ld      de,16
        add     hl,de
        ld      (rm_d),hl
        ld      hl,(rm_m)
        ld      de,16
        add     hl,de
        ld      (rm_m),hl
        ld      hl,rm_n
        dec     (hl)
        jp      nz,b_rmw
        ret
rm_pw:  ld      a,(rm_w)                ; B = the bytes of the picture row
IF EXP > 1
        add     a,a
ENDIF
IF EXP > 2
        add     a,a
ENDIF
        ld      b,a
        ret

; VRAM address HL (16 bits in the page) of the page not on screen, A = 0 read / 40h write
b_va:   ld      c,a
        ld      a,h
        rlca
        rlca
        and     3
        ld      b,a
        ld      a,(b6_r14)
        add     a,b
        di
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a
        ld      a,l
        out     (VDP_C),a
        ld      a,h
        and     3Fh
        or      c
        out     (VDP_C),a
        ei
        ret

; the bar canvas -> rows 192..211 of the page not on screen
b6_up:
IF EXP > 1
        ld      hl,BARC
        ld      de,BUF
        ld      a,CVR*20/256
        ld      (up_n),a
up_x:   ld      a,TABD & 0FFh
        ld      b,0
        call    b6_ex
        ld      a,(up_n)
        dec     a
        ld      (up_n),a
        jr      nz,up_x
ENDIF
        ld      a,(b6_r14)
        add     a,BARADD
        di
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a
        xor     a
        out     (VDP_C),a
        ld      a,BARHI
        out     (VDP_C),a
        ei
IF EXP > 1
        ld      hl,BUF
ELSE
        ld      hl,BARC
ENDIF
        ld      c,VDP_D
        ld      d,20*OS/256
bu_l:   ld      b,0
        otir
        dec     d
        jr      nz,bu_l
        ret

IF EXP > 1
; canvas bytes -> the dots of this format.  HL = canvas, DE = where they go (both go on), B = number of canvas bytes (0 = 256),
; A = the table (low byte: TABD dots, TABM mask).  A nibble (2 dots) gives 1 byte (4 bit formats) or 2 bytes (8 bit formats) of the table.
b6_ex:  ld      (ex_o+1),a
        ld      a,b
        ld      (ex_n),a
        ld      b,TABD >> 8
ex_l:   ld      a,(hl)
        inc     hl
        push    af
        rrca
        rrca
        rrca
        rrca
        call    ex_p
        pop     af
        call    ex_p
        ld      a,(ex_n)
        dec     a
        ld      (ex_n),a
        jr      nz,ex_l
        ret
ex_p:   and     0Fh
IF EXP > 2
        add     a,a
ENDIF
ex_o:   or      0C0h
        ld      c,a
        ld      a,(bc)
        ld      (de),a
        inc     de
IF EXP > 2
        inc     c
        ld      a,(bc)
        ld      (de),a
        inc     de
ENDIF
        ret

; the tables of the pairs of dots from the colours b6_mp: TABD = the dots, TABM = the mask (set dot = all bits)
b6_tab: ld      ix,TABD
        ld      iy,TABM
        ld      c,0
tb_l:   ld      a,c
        rrca
        rrca
        and     3
        ld      b,a                     ; the first dot of the pair
        ld      a,c
        and     3
        ld      d,a                     ; the second
IF EXP > 2
        ld      a,b
        or      a
        jr      z,tb_a
        ld      a,0FFh
tb_a:   ld      (iy+0),a
        ld      a,d
        or      a
        jr      z,tb_b
        ld      a,0FFh
tb_b:   ld      (iy+1),a
        inc     iy
        inc     iy
ELSE
        ld      e,0
        ld      a,b
        or      a
        jr      z,tb_a
        ld      e,0F0h
tb_a:   ld      a,d
        or      a
        jr      z,tb_b
        ld      a,e
        or      0Fh
        ld      e,a
tb_b:   ld      (iy+0),e
        inc     iy
ENDIF
        ld      a,b
        call    tb_m
        ld      b,a
        ld      a,d
        call    tb_m
IF EXP > 2
        ld      (ix+1),a
        ld      (ix+0),b
        inc     ix
        inc     ix
ELSE
        ld      e,a
        ld      a,b
        rlca
        rlca
        rlca
        rlca
        or      e
        ld      (ix+0),a
        inc     ix
ENDIF
        inc     c
        ld      a,c
        cp      16
        jr      nz,tb_l
        ret
tb_m:   push    de                      ; A = b6_mp[A]
        ld      e,a
        ld      d,0
        ld      hl,b6_mp
        add     hl,de
        ld      a,(hl)
        pop     de
        ret
ENDIF
up_n:   defb    0


b6_cmp: ld      a,(de)                  ; B bytes at HL and DE the same?  Z = yes
        cp      (hl)
        ret     nz
        inc     hl
        inc     de
        djnz    b6_cmp
        ret

; ---- once per picture, after the palette: the bar of this moment into the page that is not on screen ----
m8_bar6:ld      a,(ov_ok)
        or      a
        ret     z
        call    b6_pick
        ld      a,(m8_vhid)
        or      a
        jr      z,bb_0
        ld      a,(m8_pm)
bb_0:   ld      (b6_r14),a
        call    b6_prog
        ld      (b6_sn),hl
        ld      a,(ui_vis)
        ld      hl,paused
        or      (hl)
        jr      z,bb_v
        ld      a,1
bb_v:   ld      (b6_sn+2),a
        ld      a,(paused)
        ld      (b6_sn+3),a
        ld      hl,(cur)
        ld      de,15
        call    div16
        ld      (b6_sn+4),hl
        ld      a,(vol_lv)
        ld      (b6_sn+6),a
        ld      hl,b6_mp                ; the four colours
        ld      de,b6_sn+7
        ld      bc,4
        ldir
        ld      hl,b6_sn+2
        ld      de,b6_so+2
        ld      b,9
        call    b6_cmp
        jr      z,bb_t
        call    b6_stat
        jr      bb_d
bb_t:   ld      hl,b6_sn
        ld      de,b6_so
        ld      b,2
        call    b6_cmp
        jr      z,bb_c
        ld      a,(b6_sn+2)
        or      a
        jr      z,bb_c
        call    b6_trk
bb_d:   ld      a,2
        ld      (b6_dirty),a
bb_c:   ld      hl,b6_sn
        ld      de,b6_so
        ld      bc,11
        ldir
        ld      a,(b6_dirty)
        or      a
        jr      z,bb_n
        dec     a
        ld      (b6_dirty),a
        call    b6_up
bb_n:   ld      a,(b6_sn+2)
        or      a
        ret     z
        call    b6_put
        ld      a,(b6_sn+3)
        or      a
        ret     z
        jp      b6_pau

; the 12 x 6 icons, the texts, the variables
        include "bar6ic.inc"
IF MODFMT = 'A'
b6_name:defb    "SC10",0
          ; V1.11.28: the name follows m8_fmt (see b6_namef)
ELSE
b6_name:defb    "SCR"
        defb    MODFMT,0
ENDIF
cv_b:   defw    0
cv_rt:  defb    1
cv_mk:  defb    80h
cv_c:   defb    0
ch_n:   defb    0
ch_i:   defb    0
bm_x:   defw    0
bm_c:   defb    0
bm_s0:  defb    0
bm_y:   defb    0
cv_cc:  defb    0
bs_y:   defb    0
rm_a:   defw    0
rm_d:   defw    0
rm_m:   defw    0
rm_w:   defb    0
rm_n:   defb    0
vs_i:   defb    0
vs_x:   defw    0
vs_y:   defb    0
b6_dk:  defb    0
b6_lt:  defb    1
b6_bar: defb    2
b6_tx:  defb    3
IF MODFMT = '6'
b6_mp   equ     b6_dk                   ; MV6: the canvases hold palette entries, the colours are the roles
ELSE
b6_mp:  defs    4                       ; the colour (4 bit, GRB or Y byte) of the roles 0..3 dark, light, bar, text
ENDIF
b6_dirty:defb   0
b6_r14: defb    0
b6_br:  defs    NPAL
b6_sn:  defs    11
b6_so:  defb    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
b6_t1:  defs    8
b6_t2:  defs    8
ex_n:   defb    0
