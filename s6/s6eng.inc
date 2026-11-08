; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  s6eng.inc - SCREEN 6 (512 x 212, 4 colours) drawing engine for the X86MV list screens
;  needs: FONTC (96 glyphs x 8 rows, bit7 = leftmost), FONTW (96 advance widths), ROWBUF (8*RB bytes), TBUF (16 bytes, page aligned), s6vars.inc
;  colours: 0 white, 1 black, 2 blue, 3 yellow
; ============================================================
RB      equ     65                      ; bytes of one composed text row (1 bit pixels): at most 520 pixels

; wait until the VDP command engine is idle (S#2 bit 0)
s6_vwait:
        di
        ld      a,2
        out     (99h),a
        ld      a,8Fh
        out     (99h),a
sv1:    in      a,(99h)
        rrca
        jr      c,sv1
        xor     a
        out     (99h),a
        ld      a,8Fh
        out     (99h),a
        ei
        ret

; fill rectangle s6_rx, s6_ry, s6_rw, s6_rh (words) with colour s6_rc: HMMV when x and w are multiples of 4, else LMMV (slow: thin lines only)
s6_fill:
        call    s6_vwait
        ld      a,(s6_rc)
        and     3
        ld      b,a
        ld      a,(s6_rx)
        ld      c,a
        ld      a,(s6_rw)
        or      c
        and     3
        ld      a,b
        ld      c,80h                   ; LMMV (IMP)
        jr      nz,sf_g
        add     a,a
        add     a,a
        or      b
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      b
        ld      c,0C0h                  ; HMMV
sf_g:   ld      (s6_fc),a
        di
        ld      a,36
        out     (99h),a
        ld      a,91h                   ; R#17 = 36, auto increment
        out     (99h),a
        ld      hl,s6_rx
        ld      b,8
        push    bc
        ld      c,9Bh
        otir                            ; R#36..43: DX DY NX NY
        pop     bc
        ld      a,(s6_fc)
        out     (9Bh),a                 ; R#44 colour
        xor     a
        out     (9Bh),a                 ; R#45
        ld      a,c
        out     (9Bh),a                 ; R#46 command
        ei
        ret

; call s6_rect / defw x,y,w,h / defb colour
s6_rect:
        ex      (sp),hl
        ld      de,s6_rx
        ld      bc,9
        ldir
        ex      (sp),hl
        jp      s6_fill

; 1 pixel frame b_x, b_y, b_w, b_h (words) in colour b_c
pp_box: ld      hl,(b_x)                ; V1.11.16: the same frame with b_x.. already set (the popups call it: it was a copy of this body)
        ld      (s6_rx),hl
        ld      hl,(b_y)
        ld      (s6_ry),hl
        ld      hl,(b_w)
        ld      (s6_rw),hl
        ld      hl,1
        ld      (s6_rh),hl
        ld      a,(b_c)
        ld      (s6_rc),a
        call    s6_fill                 ; top
        ld      hl,(b_y)
        ld      de,(b_h)
        add     hl,de
        dec     hl
        ld      (s6_ry),hl
        call    s6_fill                 ; bottom
        ld      hl,(b_y)
        ld      (s6_ry),hl
        ld      hl,(b_h)
        ld      (s6_rh),hl
        ld      hl,1
        ld      (s6_rw),hl
        call    s6_fill                 ; left
        ld      hl,(b_x)
        ld      de,(b_w)
        add     hl,de
        dec     hl
        ld      (s6_rx),hl
        jp      s6_fill                 ; right

; clear the composed rows, start the position at the pixel phase of x
s6_clr: ld      a,i                     ; V1.11.27: the 780 bytes are cleared with PUSH (4 times faster than LDIR): 50 strings a page
        di
        ld      (clr_sp),sp
        ld      sp,ROWBUF+12*RB
        ld      hl,0
        ld      b,12*RB/4
cl_l:   push    hl
        push    hl
        djnz    cl_l
        ld      sp,(clr_sp)
        jp      po,cl_n
        ei
cl_n:
        ld      a,(s6_tx)
        and     3
        ld      l,a
        ld      h,0
        ld      (s6_cx),hl              ; pixel position in the composed rows
        ret
; compose the ASCII string at s6_s into the rows (from row s6_ro) at s6_cx
s6_run:
st_c:   ld      hl,(s6_s)
        ld      a,(hl)
        inc     hl
        ld      (s6_s),hl
        or      a
        ret     z
        sub     20h
        cp      60h
        jr      c,st_o
        ld      a,1Fh                   ; '?'
st_o:   ld      e,a
        ld      d,0
        ld      hl,FONTW
        add     hl,de
        ld      c,(hl)
        ld      a,c
        ld      (s6_adv),a
        ld      l,e
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,FONTC
        add     hl,de
        ld      (s6_gp),hl
st_g:   ld      a,(s6_adv)
        ld      c,a
        ld      hl,(s6_cx)
        ld      b,0
        add     hl,bc                   ; end of this glyph
        ld      (s6_ncx),hl
        ld      hl,(s6_lim)
        ld      a,(s6_tx)
        and     3
        add     a,l
        ld      l,a
        jr      nc,st_l1
        inc     h
st_l1:  ld      de,(s6_ncx)
        or      a
        sbc     hl,de                   ; limit + phase - end
        ret     c                       ; would not fit: stop
        ld      hl,(s6_cx)
        ld      a,l
        and     7
        ld      (s6_sh),a
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l                       ; byte index
        ld      de,ROWBUF
        add     hl,de
        ld      a,(s6_ro)
        or      a
        jr      z,st_ro
        ld      de,RB
        add     hl,de
st_ro:  ld      (s6_rp),hl
        ld      c,8
st_r:   ld      hl,(s6_gp)
        ld      a,(hl)
        inc     hl
        ld      (s6_gp),hl
        ld      d,a
        ld      e,0
        ld      a,(s6_sh)
        or      a
        jr      z,st_ns
        ld      b,a
st_sh:  srl     d
        rr      e
        djnz    st_sh
st_ns:  ld      hl,(s6_rp)
        ld      a,(hl)
        or      d
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        or      e
        ld      (hl),a
        ld      hl,(s6_rp)
        ld      de,RB
        add     hl,de
        ld      (s6_rp),hl
        dec     c
        jr      nz,st_r
        ld      hl,(s6_ncx)
        ld      (s6_cx),hl
        jp      st_c
; colour table and send: s6_nr rows of the composed text to the VRAM at (s6_tx, s6_ty)
s6_send:
        ; colour table T[n] = (E[n] & fg*55h) | (~E[n] & bg*55h), n = 0..15
        ld      a,(s6_fg)
        and     3
        ld      b,a
        add     a,a
        add     a,a
        or      b
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      b
        ld      (s6_fp),a
        ld      a,(s6_bg)
        and     3
        ld      b,a
        add     a,a
        add     a,a
        or      b
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      b
        ld      (s6_bp),a
        ld      hl,s6_ex4
        ld      de,TBUF
        ld      b,16
st_t:   ld      a,(hl)                  ; E
        inc     hl
        push    hl
        ld      c,a
        ld      a,(s6_fp)
        and     c
        ld      l,a                     ; E & fg
        ld      a,c
        cpl
        ld      c,a
        ld      a,(s6_bp)
        and     c                       ; ~E & bg
        or      l
        pop     hl
        ld      (de),a
        inc     de
        djnz    st_t
        ; bytes per row = (cx + 7) / 8
        ld      hl,(s6_cx)
        ld      de,7
        add     hl,de
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      a,l
        or      a
        ret     z
        ld      (s6_nb),a
        call    s6_vwait
        ; VRAM byte of the first pixel row: y * 128 + x / 4
        ld      hl,(s6_tx)
        srl     h
        rr      l
        srl     h
        rr      l
        ld      (s6_bx),hl
        ld      a,(s6_ty)
        ld      h,a
        ld      l,0
        srl     h
        rr      l                       ; y * 128
        ld      de,(s6_bx)
        add     hl,de
        ld      (s6_va),hl
        ld      hl,ROWBUF
        ld      (s6_rp),hl
        ld      a,(s6_nr)
        ld      c,a
st_w:   ld      hl,(s6_va)
        call    s6_vset
        ld      hl,(s6_rp)
        ld      a,(s6_nb)
        ld      b,a
        ld      d,TBUF/256
st_x:   ld      a,(hl)
        inc     hl
        push    af
        rrca
        rrca
        rrca
        rrca
        and     0Fh
        ld      e,a
        ld      a,(de)
        out     (98h),a
        pop     af
        and     0Fh
        ld      e,a
        ld      a,(de)
        out     (98h),a
        djnz    st_x
        ld      hl,(s6_rp)
        ld      de,RB
        add     hl,de
        ld      (s6_rp),hl
        ld      hl,(s6_va)
        ld      de,128
        add     hl,de
        ld      (s6_va),hl
        dec     c
        jr      nz,st_w
        ret


; compose the bitmap at BMB (s6_bh rows of s6_bpr bytes, 8 pixels per byte, bit7 = leftmost) at s6_cx
s6_blt: ld      hl,(s6_cx)
        ld      a,l
        and     7
        ld      (s6_sh),a
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      de,ROWBUF
        add     hl,de
        ld      (s6_rp),hl
        ld      hl,BMB
        ld      (s6_gp),hl
        ld      a,(s6_bh)
        ld      c,a
bl_r:   ld      a,(s6_bpr)
        ld      (u_k),a
        ld      hl,(s6_rp)
        ld      (u_q),hl
bl_k:   ld      hl,(s6_gp)
        ld      a,(hl)
        inc     hl
        ld      (s6_gp),hl
        ld      d,a
        ld      e,0
        ld      a,(s6_sh)
        or      a
        jr      z,bl_n
        ld      b,a
bl_s:   srl     d
        rr      e
        djnz    bl_s
bl_n:   ld      hl,(u_q)
        ld      a,(hl)
        or      d
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        or      e
        ld      (hl),a
        ld      (u_q),hl
        ld      hl,u_k
        dec     (hl)
        jr      nz,bl_k
        ld      hl,(s6_rp)
        ld      de,RB
        add     hl,de
        ld      (s6_rp),hl
        dec     c
        jr      nz,bl_r
        ret

; mixed string (UTF-8): HL = ASCIIZ, s6_tx s6_ty s6_fg s6_bg s6_lim set.  English letters use the built-in font, runs of bytes from 80h up
; (Korean, ...) are drawn by the cartridge (command 30h).  ASCII rows start at row 1 of 11 composed rows, the Korean bitmap at row 0.
s6_u8:  ld      (u8_p),hl
        ld      a,1
        ld      (s6_ro),a
        ld      a,11
        ld      (s6_nr),a
        call    s6_clr
u8_l:   ld      hl,(u8_p)
        ld      a,(hl)
        or      a
        jp      z,u8_e
        cp      80h
        jr      nc,u8_k
        ld      b,0                     ; run of ASCII bytes
u8_a:   ld      a,(hl)
        or      a
        jr      z,u8_a1
        cp      80h
        jr      nc,u8_a1
        inc     hl
        inc     b
        jr      u8_a
u8_a1:  ld      a,(hl)                  ; HL = end of the run
        ld      (u8_sv),a
        ld      (hl),0
        push    hl
        ld      hl,(u8_p)
        ld      (s6_s),hl
        call    s6_run
        pop     hl
        ld      a,(u8_sv)
        ld      (hl),a
        ld      (u8_p),hl
        ld      hl,(s6_ncx)
        ld      de,(s6_cx)
        or      a
        sbc     hl,de                   ; did the run end by the limit (the last glyph was refused)?
        jr      u8_l
u8_e:   ld      a,(s6_al)               ; V1.11.25: s6_al = 1: the text ends at s6_tx (the composed width is known only now, Korean included)
        or      a
        jp      z,s6_send
        xor     a
        ld      (s6_al),a
        ld      a,(s6_tx)
        and     3
        ld      c,a                     ; pixel phase of the composed rows
        ld      b,0
        ld      hl,(s6_cx)
        or      a
        sbc     hl,bc                   ; width
        ex      de,hl
        ld      hl,(s6_tx)
        or      a
        sbc     hl,de                   ; wanted left edge
        jr      nc,ue_p
        ld      hl,0
ue_p:   ld      a,l
        sub     c
        and     3
        ld      e,a
        ld      d,0
        or      a
        sbc     hl,de                   ; the same pixel phase as before (at most 3 pixels left)
        ld      (s6_tx),hl
        jp      s6_send
u8_k:   ld      a,(VC_CAPS)             ; V1.11.26: no cartridge: the built-in dot font draws the character
        and     4
        jp      z,hf_ch
        ld      b,0                     ; run of bytes from 80h up (at most 100)
u8_k1:  ld      a,(hl)
        cp      80h
        jr      c,u8_k2
        inc     hl
        inc     b
        ld      a,b
        cp      100
        jr      c,u8_k1
u8_k2:  ld      a,b
        ld      (u8_n),a
        ; room in pixels = lim + phase - cx
        ld      hl,(s6_lim)
        ld      a,(s6_tx)
        and     3
        add     a,l
        ld      l,a
        jr      nc,u8_r1
        inc     h
u8_r1:  ld      de,(s6_cx)
        or      a
        sbc     hl,de
        jp      c,u8_e                  ; no room
        ld      a,h
        or      a
        jr      z,u8_r2
        ld      l,255
u8_r2:  ld      a,l
        or      a
        jp      z,u8_e
        ld      (u8_room),a
        ld      a,30h
        call    vx_cmd                  ; TEXT: code 0 = UTF-8, height 9, width limit, length, the bytes
        xor     a
        call    vx_par
        ld      a,9
        call    vx_par
        ld      a,(u8_room)
        call    vx_par
        xor     a
        call    vx_par
        ld      a,(u8_n)
        call    vx_par
        ld      a,(u8_n)
        ld      b,a
        ld      hl,(u8_p)
u8_t:   ld      a,(hl)
        inc     hl
        push    bc
        call    vx_par
        pop     bc
        djnz    u8_t
        call    vx_st
        bit     3,a
        jp      nz,u8_e
        call    vx_rd                   ; bytes used
        ld      (u8_u),a
        call    vx_rd                   ; characters drawn
        call    vx_rd
        ld      (u8_w),a                ; width
        call    vx_rd
        call    vx_rd
        ld      (s6_bh),a               ; height
        ld      a,(u8_w)
        or      a
        jp      z,u8_e
        add     a,7
        rrca
        rrca
        rrca
        and     1Fh
        ld      (s6_bpr),a
        ld      a,(s6_bh)
        cp      11
        jp      nc,u8_e
        or      a
        jp      z,u8_e
        ld      c,a                     ; rows
        ld      hl,BMB
u8_b:   ld      a,(s6_bpr)
        ld      b,a
u8_b1:  call    vx_rd
        ld      (hl),a
        inc     hl
        djnz    u8_b1
        dec     c
        jr      nz,u8_b
        call    s6_blt
        ld      a,(u8_w)
        ld      e,a
        ld      d,0
        ld      hl,(s6_cx)
        add     hl,de
        ld      (s6_cx),hl
        ld      a,(u8_u)
        or      a
        jp      z,u8_e
        ld      c,a
        ld      b,0
        ld      hl,(u8_p)
        add     hl,bc
        ld      (u8_p),hl
        ld      a,(u8_n)                ; fewer bytes used than sent: out of room
        cp      c
        jp      nz,u8_e
        jp      u8_l

; label: call s6_l (left) / s6_lr (ends at x) : defw x / defb y,fg,bg / defb "English",0,"UTF-8 text",0   (the UTF-8 form when the cartridge draws text, else English)
s6_lr:  ld      a,1
        ld      (s6_al),a
        jr      sl_p
s6_l:   xor     a
        ld      (s6_al),a
sl_p:   pop     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (s6_tx),de
        ld      a,(hl)
        ld      (s6_ty),a
        inc     hl
        ld      a,(hl)
        ld      (s6_fg),a
        inc     hl
        ld      a,(hl)
        ld      (s6_bg),a
        inc     hl
        ld      de,500
        ld      (s6_lim),de
        call    lb_draw
        jp      (hl)
; HL = the pair English,0,UTF-8,0: draws the one that fits (s6_tx s6_ty s6_fg s6_bg s6_lim s6_al set); HL = behind the pair
lb_draw:ld      (u8_e0),hl
lb_1:   ld      a,(hl)
        inc     hl
        or      a
        jr      nz,lb_1
        ld      (u8_u0),hl
lb_2:   ld      a,(hl)
        inc     hl
        or      a
        jr      nz,lb_2
        push    hl
        ld      a,(VC_CAPS)
        and     4
        ld      hl,(u8_u0)
        jr      nz,lb_3                 ; the cartridge draws the Korean form
        call    hf_cov                  ; V1.11.26: no cartridge: the Korean form when the built-in dot font has all its characters
        ld      hl,(u8_u0)
        jr      nc,lb_3
        ld      hl,(u8_e0)
lb_3:   call    s6_u8
        pop     hl
        ret

; ---- the built-in Hangul dot font (V1.11.26): hf_tab (hf_ui.inc / hf_st.inc) = code point, 10 rows of 8 dots; a character is 9 dots wide ----
; HL = UTF-8 text -> DE = the code point, HL = behind the character
hf_dec: ld      a,(hl)
        inc     hl
        cp      0E0h
        jr      nc,hd_3
        cp      0C0h
        jr      nc,hd_2
        ld      e,a                     ; a stray byte: itself (no glyph has such a code)
        ld      d,0
        ret
hd_2:   and     1Fh                     ; code = (b0 and 1Fh) << 6 or (b1 and 3Fh)
        rrca
        rrca
        ld      c,a
        and     3Fh
        ld      d,a
        ld      a,c
        and     0C0h
        ld      e,a
        ld      a,(hl)
        inc     hl
        and     3Fh
        or      e
        ld      e,a
        ret
hd_3:   and     0Fh                     ; code = (b0 and 0Fh) << 12 or (b1 and 3Fh) << 6 or (b2 and 3Fh)
        rlca
        rlca
        rlca
        rlca
        ld      d,a
        ld      a,(hl)
        inc     hl
        and     3Fh
        rrca
        rrca
        ld      c,a
        and     0Fh
        or      d
        ld      d,a
        ld      a,c
        and     0C0h
        ld      e,a
        ld      a,(hl)
        inc     hl
        and     3Fh
        or      e
        ld      e,a
        ret
; DE = code point -> HL = its 10 rows, carry set when the font has no such character
hf_find:ld      hl,hf_tab
hf_f1:  ld      c,(hl)
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      a,b
        or      c
        jr      z,hf_nf
        ld      a,c
        cp      e
        jr      nz,hf_f2
        ld      a,b
        cp      d
        ret     z
hf_f2:  ld      bc,10
        add     hl,bc
        jr      hf_f1
hf_nf:  scf
        ret
; HL = UTF-8 text: carry set when a character from 80h up is not in the font
hf_cov: ld      a,(hl)
        or      a
        ret     z
        cp      80h
        jr      nc,hc_k
        inc     hl
        jr      hf_cov
hc_k:   call    hf_dec
        push    hl
        call    hf_find
        pop     hl
        ret     c
        jr      hf_cov
; u8_k without the cartridge: the character at u8_p
hf_ch:  ld      hl,(u8_p)
        call    hf_dec
        ld      (u8_p),hl
        call    hf_find
        jp      c,u8_l                  ; not in the font: left out
        push    hl
        ld      hl,(s6_lim)             ; room in pixels = lim + phase - cx, 9 are needed
        ld      a,(s6_tx)
        and     3
        add     a,l
        ld      l,a
        jr      nc,hf_r1
        inc     h
hf_r1:  ld      de,(s6_cx)
        or      a
        sbc     hl,de
        jr      c,hf_no
        ld      a,h
        or      a
        jr      nz,hf_ok
        ld      a,l
        cp      9
        jr      c,hf_no
hf_ok:  pop     hl
        ld      de,BMB
        ld      bc,10
        ldir
        ld      a,10
        ld      (s6_bh),a
        ld      a,1
        ld      (s6_bpr),a
        call    s6_blt
        ld      hl,(s6_cx)
        ld      de,9
        add     hl,de
        ld      (s6_cx),hl
        jp      u8_l
hf_no:  pop     hl
        jp      u8_e

; VRAM write address HL
s6_vset:
        di
        ld      a,h
        rlca
        rlca
        and     3
        out     (99h),a
        ld      a,8Eh
        out     (99h),a
        ld      a,l
        out     (99h),a
        ld      a,h
        and     3Fh
        or      40h
        out     (99h),a
        ei
        ret

s6_ex4: defb    00h,03h,0Ch,0Fh,30h,33h,3Ch,3Fh,0C0h,0C3h,0CCh,0CFh,0F0h,0F3h,0FCh,0FFh
; SCREEN 6 registers + palette; clears the page with colour 0
s6_init:
        ld      a,(0FFE8h)              ; RG9SAV: keep the PAL bit
        and     02h
        or      80h
        ld      (s6_r9),a
        di
        ld      hl,s6_rtab
        ld      b,s6_rcnt
si1:    ld      a,(hl)
        out     (99h),a
        inc     hl
        ld      a,(hl)
        out     (99h),a
        inc     hl
        djnz    si1
        xor     a
        out     (99h),a
        ld      a,90h
        out     (99h),a
        ld      hl,s6_pal
        ld      c,9Ah
        ld      b,8
        otir
        ei
        call    s6_rect
        defw    0,0,512,212
        defb    0
        ret
s6_rtab:defb    08h,80h                 ; R#0  SCREEN 6
        defb    60h,81h                 ; R#1  display on
        defb    1Fh,82h                 ; R#2  page 0
        defb    00h,87h                 ; R#7
        defb    0Ah,88h                 ; R#8  sprites off
s6_r9:  defb    80h,89h                 ; R#9  212 lines
        defb    00h,92h                 ; R#18
        defb    00h,97h                 ; R#23
        defb    00h,99h                 ; R#25 (no YJK)
        defb    00h,8Eh                 ; R#14
s6_rcnt equ     10
s6_pal: defb    77h,07h, 00h,00h, 07h,04h, 70h,05h      ; 0 white, 1 black, 2 blue (0,4,7), 3 yellow (7,5,0): R<<4|B, G
