; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  m8.asm - X86MV module for MV8 (SCREEN 8, 256x192, 256 colours GGGRRRBB).  V1.6.0
;  File X86MV8.OVL, assembled to run at 5000h (the shift-table area: the tables are rebuilt when the list comes back).
;  x86mv.asm (m8_load) reads it next to X86MV.COM and jumps here; BUF still holds the file header, the movie handle is open.
;  Frame = 54272 bytes: picture 49152 | palette 32 (unused) | sound count N (1 byte) | N*32 bytes MP3 piece.  k = header byte 20h
;  (frame = k/15 s).  The picture is read in 4 pieces of 12288 bytes (BUF 8000h-AFFFh; the font behind BUF+3200h is not touched, B200h+)
;  and written to the page that is not on screen; the page is switched in the vertical retrace (R#2).
;  Sound: the X86 Multimedia cartridge (ports 2Ch-2Fh, like the MV2 player) gets the MP3 pieces at 150/k frames per 10 s.
;  No overlay in this version (V1.6.0): keys only.
; ============================================================
        org     5000h
        include "m8syms.inc"
        include "stampm.inc"
        include "m8mode.inc"            ; V1.11.28: MODFMT = the format letter of this module (build.py makes one module per format: X86MV5/6/7/8/A.OVL)

BDOS    equ     0005h
BUF     equ     8000h
RING    equ     4000h
VDP_D   equ     98h
VDP_C   equ     99h
PPI_A   equ     0A9h
PPI_C   equ     0AAh
JIFFY   equ     0FC9Eh
RG9SAV  equ     0FFE8h
LEADMAX equ     16
CLEAD   equ     8
CHUNK   equ     3000h           ; 12288 bytes per read (4 per picture)
fontc   equ     BUF+3200h       ; the 6x8 glyphs of the main program (96 x 8 bytes), used by the overlay
BGC     equ     02h             ; overlay colours (GGGRRRBB): bar, text, progress, track
FGC     equ     0FFh
ACC     equ     5Dh
DIMC    equ     25h

m8_entry:
        ld      hl,m8_ptab              ; the format letter (header byte 11h) -> its parameter block
        ld      a,(BUF+11h)
        ld      c,a
pt_l:   ld      a,(hl)
        or      a
        jp      z,e_ufmt                ; not a format this player knows
        cp      c
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        jr      nz,pt_l
        ex      de,hl
        ld      de,m8_par
        ld      bc,m8_parn
        ldir
        xor     a
        ld      (ov_on),a               ; the main program's tile overlay is not used in a module
        ld      a,(m8_lvl)              ; SCREEN 10-12 need a V9958
        ld      b,a
        ld      a,(vdplv)
        cp      b
        jp      c,e_gen
m8_f1:  ld a,(BUF+20h)             ; k: frame = k/15 s (0 = 3)
        or      a
        jr      nz,m8_k1
        ld      a,3
m8_k1:  cp      5
        jp      nc,e_fmt
        ld      (m8_k),a
        dec     a
        ld      e,a
        ld      d,0
        ld      hl,m8_sktab             ; seek step (frames for 5 s)
        add     hl,de
        ld      a,(hl)
        ld      (m8_sk),a
        ld      hl,m8_rtab2
        add     hl,de
        ld      a,(hl)
        ld      (m8_rate),a             ; cartridge rate (frames per 10 s)
        ld      hl,m8_hitab             ; overlay hides after 3 s
        add     hl,de
        ld      a,(hl)
        ld      (m8_hide),a
        ld      a,(BUF+21h)             ; lines: 0 = 192
        or      a
        jr      z,m8_l1
        cp      192
        jp      nz,e_fmt
m8_l1:  ld      hl,(nframes)
        ld      a,h
        or      l
        jp      z,e_fmt
        ld      a,(m8_vbit)             ; SCREEN 8 needs 128 KB of VRAM (bit 3 of the machine mask), SCREEN 5 bit 0
        ld      b,a
        ld      a,(vmask)
        and     b
        ld      de,m8_nov
        jp      z,err
        call    cart_detect             ; sound: the cartridge, else silent
        jr      c,m8_ns
        ld      a,1
        ld      (cart_on),a
        jr      m8_s1
m8_ns:  xor     a
        ld      (cart_on),a
        call    msg_nosnd
m8_s1:  call    m8_vdp
        ld      hl,0
        ld      (m8_fpos),hl
        ld      hl,0FFFFh
        ld      (cur),hl
        ld      hl,(JIFFY)
        ld      (t0),hl
        call    m8_cstart
        jp      m8_loop

; ---- VDP: SCREEN 8, display blank until the first picture is on page 1 and switched in ----
m8_vdp: ld      a,(m8_r0)
        ld      (m8_rtab),a
        ld      a,(m8_r25)
        ld      (m8_r25t),a
        xor     a
        ld      (m8_vcur),a
        inc     a
        ld      (m8_first),a
        ld      a,(RG9SAV)
        and     02h
        ld      (pal),a
        ld      b,a
        ld      a,b
        or      80h                     ; 212 lines: the bar under the picture
        ld      (m8_r9),a
        di
        ld      hl,m8_rtab
        ld      a,(vdplv)
        cp      2
        ld      b,m8_rn-3               ; V9938: no R#25..27
        jr      c,mv1
        ld      b,m8_rn
mv1:    ld      a,(hl)
        out     (VDP_C),a
        inc     hl
        ld      a,(hl)
        out     (VDP_C),a
        inc     hl
        djnz    mv1
        ei
        ret
m8_rtab:defb    0Eh,80h         ; R#0  M5 M4 M3 = Graphic 7 (MV5: Graphic 4 = 06h, patched)
        defb    0A0h,81h        ; R#1  blank, IE
        defb    1Fh,82h         ; R#2  page 0
        defb    00h,87h         ; R#7  backdrop
        defb    0Ah,88h         ; R#8  VR=1, sprites off
m8_r9:  defb    00h,89h         ; R#9  192 lines (PAL bit patched)
        defb    00h,8Eh         ; R#14
        defb    00h,97h         ; R#23
m8_r25t:defb    00h,99h         ; R#25: YJK on for SCREEN 10-12 (V9958; patched)
        defb    00h,9Ah         ; R#26
        defb    00h,9Bh         ; R#27
m8_rn   equ     11

; leave: back to the SCREEN 2 tile mode the list uses, then the common exit of x86mv.asm
m8_done:call    vdp_init
        jp      done

; ---- main loop (like mloop of x86mv.asm) ----
m8_loop:
        call    m8_keys
        ld      a,(redraw)
        or      a
        call    nz,m8_redraw
        ld      a,(paused)
        or      a
        jr      z,m8_run
        halt
        jr      m8_loop
m8_run: ld      a,(cart_on)
        or      a
        jr      z,m8_jc
        ld      a,(cart_tail)
        or      a
        jr      nz,m8_jc                ; sound is over: the JIFFY clock finishes the last frames
        call    m8_crefill
        call    c_pos                   ; HL = frame being heard (cartridge clock, frames of k/15 s)
        call    m8_watch
        jr      m8_got
m8_jc:  ld      hl,(JIFFY)
        ld      de,(t0)
        or      a
        sbc     hl,de                   ; HL = ticks since start
        call    m8_t2f
        jp      c,m8_end
m8_got: ld      b,h
        ld      c,l                     ; BC = frame due now
        ld      a,(ui_vis)              ; overlay: hide after 3 s without a key
        or      a
        jr      z,gi_ok
        ld      h,b
        ld      l,c
        ld      de,(ui_last)
        or      a
        sbc     hl,de
        jr      nc,gi_a
        ld      (ui_last),bc            ; time went backwards (seek): restart the timer
        jr      gi_ok
gi_a:   ld      a,(m8_hide)
        ld      e,a
        ld      d,0
        or      a
        sbc     hl,de
        jr      c,gi_ok
        xor     a
        ld      (ui_vis),a
gi_ok:
        ld      hl,(nframes)
        or      a
        sbc     hl,bc
        jp      z,m8_end
        jp      c,m8_end
        ld      a,(lead)                ; the picture appears about `lead` frames after this decision
        or      a
        jr      z,gl_n
        ld      e,a
        ld      d,0
        ld      h,b
        ld      l,c
        add     hl,de
        ex      de,hl
        ld      hl,(nframes)
        dec     hl
        or      a
        sbc     hl,de
        jr      nc,gl_c
        ld      de,(nframes)
        dec     de
gl_c:   ld      b,d
        ld      c,e
gl_n:   ld      hl,(cur)
        or      a
        sbc     hl,bc
        jr      z,m8_wait               ; already shown
        jr      c,gl_s                  ; a newer frame is due
        ld      a,h
        or      a
        jr      nz,gl_s
        ld      a,l
        cp      LEADMAX+1
        jr      c,m8_wait               ; the lead shrank: keep the picture
gl_s:   ld      (cur),bc
        ld      hl,(JIFFY)
        ld      (m8_ft0),hl
        call    m8_show
        jp      c,m8_done
        call    m8_lead
        jp      m8_loop
m8_wait:halt
        jp      m8_loop

; the end of the movie: repeat setting (like `ended`)
m8_end: ld      a,(rep)
        or      a
        jp      z,m8_done
        cp      2
        jr      nz,me_one
        ld      a,(br_on)
        or      a
        jr      z,me_one
        call    br_nextfile
        jr      c,me_one
        ld      sp,(sp0)
        call    stop_play
        jp      playfile
me_one: ld      hl,0
        call    m8_seek
        jp      m8_loop

; ---- HL = ticks -> HL = movie frame (carry = overflow) ----
m8_t2f: ld      a,(pal)
        or      a
        jr      nz,t2_p
        srl     h                       ; 60 Hz: frame = ticks / (4k)
        rr      l
        srl     h
        rr      l
        ld      a,(m8_k)
        cp      1
        ret     z
        ld      e,a
        ld      d,0
        call    div16
        or      a
        ret
t2_p:   ld      d,h                     ; 50 Hz: frame = ticks * 3 / (10k)
        ld      e,l
        add     hl,hl
        ret     c
        add     hl,de
        ret     c
        call    m8_dk10
        call    div16
        or      a
        ret
; DE = 10 * k
m8_dk10:ld      a,(m8_k)
        ld      e,a
        add     a,a
        add     a,a
        add     a,e                     ; 5k
        add     a,a                     ; 10k
        ld      e,a
        ld      d,0
        ret
; HL = frame -> HL = ticks since t0 (60 Hz: 4k per frame; 50 Hz: 10k/3)
m8_f2t: ld      a,(m8_k)
        ld      b,a
        ld      d,h
        ld      e,l
        dec     b
        jr      z,f2_1
f2_l:   add     hl,de
        djnz    f2_l
f2_1:   ld      a,(pal)
        or      a
        jr      nz,f2_p
        add     hl,hl
        add     hl,hl
        ret
f2_p:   ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de
        add     hl,hl                   ; x10
        ld      de,3
        jp      div16

; ---- lead: how many movie frames the last picture took (reading + drawing), smoothed ----
m8_lead:ld      hl,(JIFFY)
        ld      de,(m8_ft0)
        or      a
        sbc     hl,de
        ld      a,h
        or      a
        jr      z,ld_1
        ld      l,255
ld_1:   ld      a,(m8_lt)
        ld      e,a
        ld      d,0
        ld      h,0
        add     hl,de
        add     hl,de
        add     hl,de
        ld      de,2
        add     hl,de
        srl     h
        rr      l
        srl     h
        rr      l                       ; (3 * old + new + 2) / 4
        ld      a,l
        ld      (m8_lt),a
        ld      h,0
        ld      a,(pal)
        or      a
        jr      nz,ld_5
        ld      a,(m8_k)                ; 60 Hz: (ticks + 2k) / 4k
        add     a,a
        ld      e,a
        ld      d,0
        add     hl,de
        ld      a,(m8_k)
        add     a,a
        add     a,a
        ld      e,a
        jr      ld_d
ld_5:   ld      d,h                     ; 50 Hz: (ticks * 3 + 5k) / 10k
        ld      e,l
        add     hl,hl
        add     hl,de
        ld      a,(m8_k)
        ld      c,a
        add     a,a
        add     a,a
        add     a,c
        ld      e,a
        ld      d,0
        add     hl,de
        call    m8_dk10
        jr      ld_e
ld_d:   ld      d,0
ld_e:   call    div16
        ld      a,l
        cp      LEADMAX+1
        jr      c,ld_s
        ld      a,LEADMAX
ld_s:   ld      (lead),a
        ret

; ---- show frame BC: read the 4 picture pieces into the page that is not on screen, then switch pages.  carry = read error ----
m8_show:
        ld      hl,(m8_fpos)
        or      a
        sbc     hl,bc
        jr      z,sh_r
        call    m8_fseek
        ret     c
sh_r:   ld      a,(m8_vcur)
        xor     1
        ld      (m8_vhid),a
        xor     a
        ld      (m8_ci),a
sh_l:   ld      a,(handle)
        ld      b,a
        ld      de,BUF
        ld      hl,CHUNK
        ld      c,48h                   ; _READ
        call    BDOS
        or      a
        jp      nz,sh_e
        ld      de,CHUNK
        or      a
        sbc     hl,de
        jp      nz,sh_e
        ld      a,(m8_vhid)             ; VRAM address: page * page size + piece * 3000h (R#14 = page * pm + ...)
        or      a
        jr      z,sh_p0
        ld      a,(m8_pm)
sh_p0:  ld      hl,m8_ctab
        ld      e,a
        ld      a,(m8_ci)
        add     a,a
        ld      c,a
        ld      b,0
        add     hl,bc
        ld      a,(hl)
        add     a,e                     ; R#14
        inc     hl
        ld      e,(hl)                  ; bits 8..13 of the address
        di
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a
        xor     a
        out     (VDP_C),a
        ld      a,e
        or      40h
        out     (VDP_C),a
        ei
        ld      hl,BUF
        ld      c,VDP_D
        ld      d,CHUNK/256
sh_o:   ld      b,0
        otir
        dec     d
        jr      nz,sh_o
        ld      a,(m8_ci)
        inc     a
        ld      (m8_ci),a
        ld      hl,m8_nch
        cp      (hl)
        jr      c,sh_l
        ld      a,(m8_hp)               ; MV5 / MV6 / MV7: the palette follows the picture
        or      a
        jr      z,sh_sk
        ld      a,(handle)
        ld      b,a
        ld      de,m8_pal
        ld      hl,32
        ld      c,48h                   ; _READ
        call    BDOS
        or      a
        jr      nz,sh_e
sh_sk:  call    m8_bar6                 ; V1.11.28: the bar under the picture (BUF is free; the palette is read)
        ld      a,(handle)              ; step over the rest (the sound count and the MP3 piece)
        ld      b,a
        ld      a,1
        ld      de,0
        ld      hl,(m8_skip)
        ld      c,4Ah                   ; _SEEK from the current position
        call    BDOS
        ld      hl,(m8_fpos)
        inc     hl
        ld      (m8_fpos),hl
        call    m8_flip
        or      a
        ret
sh_e:   scf
        ret
m8_ctab:defb    0,00h, 0,30h, 1,20h, 2,10h      ; R#14 add, address bits 8..13 (piece * 3000h)

; switch the pages in the vertical retrace
m8_flip:ld      de,40000
fl_l:   di
        ld      a,2
        out     (VDP_C),a
        ld      a,8Fh
        out     (VDP_C),a
        in      a,(VDP_C)
        ld      c,a
        xor     a
        out     (VDP_C),a
        ld      a,8Fh
        out     (VDP_C),a
        ei
        bit     6,c
        jr      nz,fl_go
        dec     de
        ld      a,d
        or      e
        jr      nz,fl_l
fl_go:  ld      a,(m8_vhid)
        rrca
        rrca
        rrca                            ; page 1 = 20h
        or      1Fh
        ld      b,a
        di
        ld      a,(m8_hp)
        or      a
        jr      z,fl_np
        xor     a                       ; MV5: the palette of the new picture, together with the page switch
        out     (VDP_C),a
        ld      a,90h
        out     (VDP_C),a
        ld      hl,m8_pal
        push    bc
        ld      c,9Ah
        ld      b,32
        otir
        pop     bc
fl_np:  ld      a,b
        out     (VDP_C),a
        ld      a,82h
        out     (VDP_C),a
        ld      a,(m8_first)
        or      a
        jr      z,fl_n
        xor     a
        ld      (m8_first),a
        ld      a,0E0h                  ; display on
        out     (VDP_C),a
        ld      a,81h
        out     (VDP_C),a
fl_n:   ei
        ld      a,(m8_vhid)
        ld      (m8_vcur),a
        ret

; redraw the held frame (paused, after a seek)
m8_redraw:
        xor     a
        ld      (redraw),a
        ld      hl,(cur)
        ld      a,h
        and     l
        inc     a
        ret     z
        ld      b,h
        ld      c,l
        call    m8_show
        ret     nc
        jp      m8_done

; ---- file offsets ----
; BC = frame -> DE:HL = 16384 + frame * 54272
m8_off: ld      hl,16                   ; (offset / 1024) = frame * 53 + 16
        ld      d,0
        ld      a,(m8_kb)
mo_m:   add     hl,bc
        jr      nc,mo_n
        inc     d
mo_n:   dec     a
        jr      nz,mo_m
        sla     l                       ; x1024 = x4 then one byte up
        rl      h
        rl      d
        sla     l
        rl      h
        rl      d
        ld      e,h
        ld      h,l
        ld      l,0
        ret
; seek the movie handle to frame BC.  carry = error
m8_fseek:
        push    bc
        call    m8_off
        ld      a,(handle)
        ld      b,a
        xor     a
        ld      c,4Ah                   ; _SEEK
        call    BDOS
        pop     bc
        or      a
        jr      nz,fs_e
        ld      (m8_fpos),bc
        ret
fs_e:   scf
        ret
; seek the sound handle to the count byte of frame BC (frame offset + C200h).  carry = error
m8_cseek:
        call    m8_off
        ld      bc,(m8_sndofs)
        add     hl,bc
        jr      nc,cs_1
        inc     de
cs_1:   ld      a,(h2)
        ld      b,a
        xor     a
        ld      c,4Ah
        call    BDOS
        or      a
        ret     z
        scf
        ret

; ---- sound (X86 Multimedia cartridge) ----
m8_cstart:
        ld      a,(cart_on)
        or      a
        ret     z
        ld      de,(fname)              ; second handle on the same file, for the sound pieces
        ld      a,01h
        ld      c,43h                   ; _OPEN
        call    BDOS
        or      a
        jr      z,cst_ok
        xor     a
        ld      (cart_on),a
        ret
cst_ok: ld      a,b
        ld      (h2),a
        ld      a,(m8_rate)
        ld      l,a
        ld      h,0
        ld      a,5                     ; rate: frames per 10 s
        call    c_cmd
        ld      hl,0
        ld      (c_next),hl
        ld      a,1                     ; OPEN, first data frame = 0
        call    c_cmd
        call    m8_crefill
        ld      hl,0
        ld      a,2                     ; PLAY
        jp      c_cmd

; send MP3 pieces up to (position + CLEAD)
m8_crefill:
        ld      a,(cart_on)
        or      a
        ret     z
cr_l:   call    c_status
        and     02h
        ret     z                       ; FIFO has no room
        call    c_pos
        ld      de,CLEAD
        add     hl,de
        ex      de,hl
        ld      hl,(c_next)
        or      a
        sbc     hl,de
        ret     nc                      ; far enough ahead
        ld      hl,(nframes)
        ld      de,(c_next)
        or      a
        sbc     hl,de
        jr      z,cr_eof
        jr      c,cr_eof
        call    m8_piece
        jr      c,cr_eof
        ld      hl,(c_next)
        inc     hl
        ld      (c_next),hl
        jr      cr_l
cr_eof: ld      a,1
        ld      (c_eof),a
        ret

; the MP3 piece of frame c_next -> cartridge.  carry = error / end of file
m8_piece:
        ld      bc,(c_next)
        call    m8_cseek
        ret     c
        ld      a,(h2)
        ld      b,a
        ld      de,RING
        ld      hl,1
        ld      c,48h                   ; _READ: the count byte
        call    BDOS
        or      a
        jr      nz,mp_err
        ld      a,(RING)
        or      a
        ret     z                       ; silent frame
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; N * 32
        ld      (m8_rem),hl
mp_lp:  ld      hl,(m8_rem)
        ld      a,h
        or      l
        ret     z
        ld      de,1000h                ; RING holds 4096 bytes: longer pieces go in parts
        or      a
        sbc     hl,de
        jr      c,mp_f
        ld      (m8_rem),hl
        ld      hl,1000h
        jr      mp_g
mp_f:   add     hl,de
        push    hl
        ld      hl,0
        ld      (m8_rem),hl
        pop     hl
mp_g:   push    hl
        ld      a,(h2)
        ld      b,a
        ld      de,RING
        ld      c,48h
        call    BDOS
        pop     de
        or      a
        jr      nz,mp_err
        ld      hl,RING
        call    c_send
        jr      mp_lp
mp_err: scf
        ret

; the cartridge clock stops when its sound runs out: when everything has been sent and the position has not moved for ~0.5 s,
; go on with the JIFFY clock (cart_watch of x86mv.asm).  HL = position
m8_watch:
        ld      de,(c_wpos)
        or      a
        sbc     hl,de
        add     hl,de
        jr      nz,cw_mv
        ld      a,(c_eof)
        or      a
        jr      nz,cw_t
        push    hl
        ld      de,CLEAD
        add     hl,de
        ex      de,hl
        ld      hl,(c_next)
        or      a
        sbc     hl,de
        pop     hl
        ret     c
cw_t:   push    hl
        ld      hl,(JIFFY)
        ld      de,(c_wtick)
        or      a
        sbc     hl,de
        ld      de,30
        or      a
        sbc     hl,de
        pop     hl
        ret     c
        ld      (m8_pos),hl
        ld      a,1
        ld      (cart_tail),a
        call    m8_stj                  ; t0 = JIFFY - ticks(position)
        ld      hl,(m8_pos)
        ret
cw_mv:  ld      (c_wpos),hl
        ld      de,(JIFFY)
        ld      (c_wtick),de
        ret
; t0 = JIFFY (or the pause time) - ticks(frame m8_pos)
m8_stj: ld      hl,(m8_pos)
        call    m8_f2t
        ex      de,hl
        ld      hl,(JIFFY)
        ld      a,(paused)
        or      a
        jr      z,sj_s
        ld      hl,(pstart)
sj_s:   or      a
        sbc     hl,de
        ld      (t0),hl
        ret

; ---- seek: HL = target frame ----
m8_seek:ld      (tgt),hl
        ld      (m8_pos),hl
        ld      a,(cart_on)
        or      a
        jr      z,sk_j
        ld      de,2                    ; start 2 frames early so the MP3 decoder is in sync at the target
        or      a
        sbc     hl,de
        jr      nc,sk_1
        ld      hl,0
sk_1:   ld      (c_next),hl
        xor     a
        ld      (c_eof),a
        ld      (cart_tail),a
        ld      (c_wpos+1),a
        dec     a
        ld      (c_wpos),a
        ld      a,1
        call    c_cmd                   ; OPEN with the new first frame (HL)
        call    m8_crefill
        ld      a,(paused)
        or      a
        jr      nz,sk_c
        ld      hl,0
        ld      a,2
        call    c_cmd
        jr      sk_c
sk_j:   call    m8_stj
sk_c:   ld      a,(paused)
        or      a
        jr      z,sk_run
        ld      hl,(tgt)
        ld      (cur),hl
        ld      a,1
        ld      (redraw),a
        ret
sk_run: ld      hl,0FFFFh
        ld      (cur),hl
        ret

; ---- keys (like `keys` of ui.inc): ESC quit, SPACE pause, LEFT/RIGHT seek 5 s, UP/DOWN volume, M mute ----
m8_keys:di
        in      a,(PPI_C)
        and     0F0h
        or      07h
        out     (PPI_C),a
        in      a,(PPI_A)
        ld      d,a                     ; row 7: bit 2 = ESC
        in      a,(PPI_C)
        and     0F0h
        or      08h
        out     (PPI_C),a
        in      a,(PPI_A)
        ld      e,a                     ; row 8: SPACE b0, LEFT b4, UP b5, DOWN b6, RIGHT b7
        in      a,(PPI_C)
        and     0F0h
        or      04h
        out     (PPI_C),a
        in      a,(PPI_A)
        ld      c,a                     ; row 4: M = bit 2
        ei
        bit     2,d
        jp      z,m8_done
        ld      a,e
        cpl
        ld      b,a
        ld      a,c
        cpl
        and     04h
        ld      c,a
        ld      a,(kprev8)
        cpl
        and     b
        ld      d,a                     ; D = new presses (row 8)
        ld      a,b
        ld      (kprev8),a
        ld      a,(kprev4)
        cpl
        and     c
        ld      e,a                     ; E = new press of M
        ld      a,c
        ld      (kprev4),a
        ld      a,b                     ; auto repeat for UP/DOWN only
        and     60h
        jr      z,kh0
        ld      a,(khold)
        inc     a
        ld      (khold),a
        ld      c,3
        ld      a,(paused)
        or      a
        jr      z,kh1
        ld      c,12
kh1:    ld      a,(khold)
        cp      c
        jr      c,kh3
        ld      a,c
        ld      a,(paused)
        or      a
        ld      a,c
        jr      z,kh4
        sub     6
        jr      kh5
kh4:    dec     a
kh5:    ld      (khold),a
        ld      a,b
        and     60h
        or      d
        ld      d,a
        jr      kh3
kh0:    xor     a
        ld      (khold),a
kh3:    ld      a,d
        or      e
        ret     z
        ld      a,1                     ; a key: show the overlay
        ld      (ui_vis),a
        ld      hl,(cur)
        ld      (ui_last),hl
        ld      a,d
        ld      (kd),a
        ld      a,e
        ld      (ke),a
        ld      a,(kd)
        bit     0,a
        call    nz,m8_space
        ld      a,(kd)
        bit     4,a
        call    nz,m8_left
        ld      a,(kd)
        bit     7,a
        call    nz,m8_right
        ld      a,(kd)
        bit     5,a
        call    nz,key_up
        ld      a,(kd)
        bit     6,a
        call    nz,key_down
        ld      a,(ke)
        bit     2,a
        call    nz,key_mute
        ld      a,(paused)
        or      a
        ret     z
        ld      a,1
        ld      (redraw),a
        ret

m8_space:
        ld      a,(paused)
        xor     1
        ld      (paused),a
        jr      z,sp_res
        ld      a,(cart_on)
        or      a
        jr      z,sp_np
        ld      hl,0
        ld      a,3                     ; PAUSE
        call    c_cmd
sp_np:  ld      hl,(JIFFY)
        ld      (pstart),hl
        ret
sp_res: ld      a,(cart_on)
        or      a
        jr      z,sp_nr
        ld      hl,0
        ld      a,2                     ; PLAY
        call    c_cmd
sp_nr:  ld      hl,(JIFFY)
        ld      de,(pstart)
        or      a
        sbc     hl,de
        ld      de,(t0)
        add     hl,de
        ld      (t0),hl
        ret

m8_left:ld      hl,(cur)
        ld      a,h
        and     l
        inc     a
        ret     z
        ld      a,(m8_sk)
        ld      e,a
        ld      d,0
        or      a
        sbc     hl,de
        jr      nc,kl1
        ld      hl,0
kl1:    jp      m8_seek

m8_right:
        ld      hl,(cur)
        ld      a,h
        and     l
        inc     a
        ret     z
        ld      a,(m8_sk)
        ld      e,a
        ld      d,0
        add     hl,de
        ld      de,(nframes)
        dec     de
        push    hl
        or      a
        sbc     hl,de
        pop     hl
        jr      c,kr1
        ex      de,hl                   ; clamp to the last frame
kr1:    jp      m8_seek


OVB     equ     0C000h                  ; canvases of the bar (the cache of the main program's tiles is free in a module)

m8_hitab:defb   45,22,15,11             ; 3 s in frames for k = 1..4

m8_sktab:defb   75,37,25,19             ; 5 s in frames for k = 1..4
m8_rtab2:defb   150,75,50,38            ; cartridge rate (frames per 10 s) for k = 1..4 (k = 4 is 37.5)
m8_nov: defb    "This MV needs more VRAM (128 KB)",13,10,"$"

m8_k:   defb    3
m8_sk:  defb    25
m8_rate:defb    50
m8_fpos:defw    0
m8_vcur:defb    0
m8_vhid:defb    1
m8_first:defb   1
m8_ci:  defb    0
m8_ft0: defw    0
m8_lt:  defb    0
m8_pos: defw    0
m8_rem: defw    0
; per-format parameters (copied to m8_par at the start): format letter, pieces, R#14 step per page, KB per frame, sound offset in the frame,
; bytes to skip behind the picture (+ palette), R#0, VRAM bit, R#25 (YJK), least VDP level (2 = V9958), 1 = a palette follows the picture
IF MODFMT = '8'
m8_p8:  defb    '8',4,4,53              ; MV8: SCREEN 8
        defw    0C200h,1400h
        defb    0Eh,8,0,1,0
ENDIF
IF MODFMT = '5'
m8_p5:  defb    '5',2,2,29              ; MV5: SCREEN 5, 16 colours
        defw    6200h,13E0h
        defb    06h,1,0,1,1
ENDIF
IF MODFMT = '7'
m8_p7:  defb    '7',4,4,53              ; MV7: SCREEN 7 (512 dots, 16 colours)
        defw    0C200h,13E0h
        defb    0Ah,4,0,1,1
ENDIF
IF MODFMT = '6'
m8_p6:  defb    '6',2,2,29              ; MV6: SCREEN 6 (512 dots, 4 colours)
        defw    6200h,13E0h
        defb    08h,2,0,1,1
ENDIF
IF MODFMT = 'A'
m8_pC:  defb    'C',4,4,53              ; MVC: SCREEN 12 (YJK)
        defw    0C200h,1400h
        defb    0Eh,40h,08h,2,0
m8_pB:  defb    'B',4,4,53              ; MVB: SCREEN 11
        defw    0C200h,1400h
        defb    0Eh,20h,18h,2,0
m8_pA:  defb    'A',4,4,53              ; MVA: SCREEN 10
        defw    0C200h,1400h
        defb    0Eh,10h,18h,2,0
ENDIF
m8_ptab:
IF MODFMT = '8'
        defb    '8'
        defw    m8_p8
ENDIF
IF MODFMT = '5'
        defb    '5'
        defw    m8_p5
ENDIF
IF MODFMT = '7'
        defb    '7'
        defw    m8_p7
ENDIF
IF MODFMT = '6'
        defb    '6'
        defw    m8_p6
ENDIF
IF MODFMT = 'A'
        defb    'C'
        defw    m8_pC
        defb    'B'
        defw    m8_pB
        defb    'A'
        defw    m8_pA
ENDIF
        defb    0
m8_parn equ     13
m8_par:
m8_fmt: defb    '8'
m8_nch: defb    4
m8_pm:  defb    4
m8_kb:  defb    53
m8_sndofs:defw  0C200h
m8_skip:defw    1400h
m8_r0:  defb    0Eh
m8_vbit:defb    8
m8_r25: defb    0               ; R#25 (YJK)
m8_lvl: defb    1               ; least VDP level (2 = V9958)
m8_hp:  defb    0               ; 1 = a palette follows the picture
m8_pal: defs    32
m8_hide:defb    15
        include "m8bar6.inc"
m8_end_of_module:
        defs    5000h+0FFEh-$           ; V1.11.21: the image is 4096 bytes; the last two are the build stamp (checked by X86MV.COM in mod_load)
        defw    BSTAMP
