; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
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

