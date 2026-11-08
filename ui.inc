; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  UI  (monochrome overlay, drawn into the frame buffer BUF before it is sent to VRAM)
;  Colors: 0 (black, transparent -> backdrop) and 1 (white) are the fixed anchors of every
;  MV2 palette, so the overlay never depends on the changing video palette.
;  Grey = 1-pixel checker of white/black inside the 8x1 cell limit of SCREEN 2.
;  Layout = the 3x mock-up divided by 3:  top bar rows 0-2, bottom bar rows 19-23.
; ============================================================
SEEKFR  equ     75              ; +-5 s at 15 fps
UIHIDE  equ     45              ; frames without a key until the overlay hides (3 s)

; ---- BIOS font -> RAM (glyphs 20h..7Fh) ----
rdb:    ld      a,(EXPTBL)
        call    RDSLT
        ei
        ret

font_init:
        ld      hl,0004h        ; CGTBL: address of the character font in the main ROM
        call    rdb
        ld      e,a
        ld      hl,0005h
        call    rdb
        ld      d,a
        ld      hl,0100h        ; glyph of ' ' = CGTBL + 20h*8
        add     hl,de
        ld      (fsrc),hl
        ld      hl,fontc
        ld      (fdst),hl
        ld      hl,768
        ld      (fcnt),hl
fi1:    ld      hl,(fsrc)
        call    rdb
        ld      hl,(fdst)
        ld      (hl),a
        inc     hl
        ld      (fdst),hl
        ld      hl,(fsrc)
        inc     hl
        ld      (fsrc),hl
        ld      hl,(fcnt)
        dec     hl
        ld      (fcnt),hl
        ld      a,h
        or      l
        jr      nz,fi1
        ret

; ---- 16 bit divide: HL / DE -> HL quotient, DE remainder (clobbers A, BC) ----
div16:  ld      b,h
        ld      c,l
        ld      hl,0
        ld      a,16
d16l:   sla     c
        rl      b
        adc     hl,hl
        or      a
        sbc     hl,de
        jr      nc,d16s
        add     hl,de
        jr      d16n
d16s:   inc     c
d16n:   dec     a
        jr      nz,d16l
        ld      d,h
        ld      e,l
        ld      h,b
        ld      l,c
        ret

; ---- cell primitives (cell = 8 pattern bytes in BUF, 8 color bytes at +1800h) ----
; cellptr: D = row, E = col -> HL = pattern address
cellptr:ld      a,d
        add     a,BUF/256
        ld      h,a
        ld      a,e
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ret

; put8: IX = 8 source bytes, HL = pattern address, C = color byte (IX advances by 8)
put8:   push    hl
        ld      b,8
p8l:    ld      a,(ix+0)
        ld      (hl),a
        inc     hl
        inc     ix
        djnz    p8l
        pop     hl
        ld      de,1800h
        add     hl,de
        ld      b,8
p8c:    ld      (hl),c
        inc     hl
        djnz    p8c
        ret

; ui_icon: HL = icon (TL,TR,BL,BR cells), D = row, E = col, C = color byte
ui_icon:push    hl
        pop     ix
        push    de
        call    cellptr
        call    put8
        pop     de
        push    de
        inc     e
        call    cellptr
        call    put8
        pop     de
        push    de
        inc     d
        call    cellptr
        call    put8
        pop     de
        inc     d
        inc     e
        call    cellptr
        jp      put8

; gtext: HL = zero terminated string, E = x pixel, D = y pixel.  Galmuri7 glyphs, 6x8 cell, pitch 6 pixels,
; XORed into the pattern bytes of BUF (so the same call draws white on black, or black on a white bar).
; The cell colors are not touched (callers use color byte 10h = white on black).
gtext:  ld      a,e
        ld      (gt_x),a
        ld      a,d
        ld      (gt_y),a
gt_l:   ld      a,(hl)
        or      a
        ret     z
        inc     hl
        push    hl
        sub     20h
        jr      nc,gt2
        xor     a
gt2:    cp      96
        jr      c,gt3
        xor     a
gt3:    ld      (gt_c),a
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,fontc
        add     hl,bc
        push    hl
        pop     ix
        ld      a,(gt_y)
        ld      d,a
        ld      a,(gt_x)
        ld      e,a
        call    gt_off                  ; fixed pitch: a narrow glyph is centred in its 6 pixel cell
        ld      b,8
gt_r:   push    bc
        ld      a,d
        rrca
        rrca
        rrca
        and     1Fh
        add     a,BUF/256
        ld      h,a
        ld      a,e
        and     0F8h
        ld      l,a
        ld      a,d
        and     7
        or      l
        ld      l,a                     ; HL = pattern byte of the cell at x, line y
        ld      c,0
        ld      a,e
        and     7
        ld      b,a
        ld      a,(ix+0)
        inc     ix
        inc     b
        dec     b
        jr      z,gt_s0
gt_sl:  srl     a
        rr      c
        djnz    gt_sl
gt_s0:  xor     (hl)
        ld      (hl),a
        ld      a,l
        add     a,8
        jr      c,gt_nx                 ; right edge of the screen: drop the rest
        ld      l,a
        ld      a,c
        xor     (hl)
        ld      (hl),a
gt_nx:  inc     d
        pop     bc
        djnz    gt_r
        ld      a,(gt_c)
        ld      e,a
        ld      d,0
        ld      a,(gt_fix)
        or      a
        ld      a,6                     ; names (gtextf): fixed pitch 6 = half a Korean letter (12), so Latin : Korean = 1 : 2
        jr      nz,gt_ad
        ld      hl,fontw
        add     hl,de
        ld      a,(hl)                  ; advance = width of the glyph (proportional)
gt_ad:  ld      hl,gt_x
        add     a,(hl)
        ld      (hl),a
        pop     hl
        jr      gt_l

; E = x of the glyph in gt_c: with the fixed pitch (gt_fix) + (6 - width) / 2
gt_off: ld      a,(gt_fix)
        or      a
        ret     z
        ld      a,(gt_c)
        ld      c,a
        ld      b,0
        ld      hl,fontw
        add     hl,bc
        ld      a,6
        sub     (hl)
        srl     a
        add     a,e
        ld      e,a
        ret

; gtextf: gtext with the fixed pitch (file names, the title of the play screen, the path line)
gtextf: ld      a,1
        ld      (gt_fix),a
        call    gtext
        xor     a
        ld      (gt_fix),a
        ret

; strw: HL = string -> A = width in pixels
strw:   xor     a
        ld      (gt_c),a
sw_l:   ld      a,(hl)
        or      a
        jr      z,sw_e
        inc     hl
        sub     20h
        jr      nc,sw2
        xor     a
sw2:    cp      96
        jr      c,sw3
        xor     a
sw3:    ld      c,a
        ld      b,0
        push    hl
        ld      hl,fontw
        add     hl,bc
        ld      a,(gt_c)
        add     a,(hl)
        ld      (gt_c),a
        pop     hl
        jr      sw_l
sw_e:   ld      a,(gt_c)
        ret

; fillc: D = cell row, E = first cell column, B = number of cells, A = pattern byte for all 8 lines
fillc:  ld      c,a
        push    bc
        call    cellptr
        pop     bc
fc_l:   ld      a,c
        ld      d,8
fc_k:   ld      (hl),a
        inc     hl
        dec     d
        jr      nz,fc_k
        djnz    fc_l
        ret

; ---- keep the overlay alive / wake it ----
ui_touch:
        ld      a,1
        ld      (ui_vis),a
        ld      hl,(cur)
        ld      (ui_last),hl
        ret

; ---- the overlay (rows 0-2 and 19-23 replace the video there) ----
; Drawing it costs up to 22 ms (Z80), so it is rendered into BUF only when something it shows changed (second, progress cell, volume,
; pause, FPS), copied to the cache OVB and from then on showframe sends the overlay rows from OVB (ov_on) without drawing again.
; Without enough RAM for OVB (ov_ok = 0) it is drawn every frame as before.
ui_draw:ld      a,(paused)
        ld      b,a
        ld      a,(ui_vis)
        or      b
        jr      nz,ud_v
        xor     a
        ld      (ov_on),a               ; hidden: the plain video rows
        ret
ud_v:   ld      a,(ov_ok)
        or      a
        jr      nz,ud_c
        call    ui_top
        jp      ui_bottom
ud_c:   call    ud_sig
        ld      hl,ov_sn
        ld      de,ov_sg
        ld      b,8
ud_cmp: ld      a,(de)
        cp      (hl)
        jr      nz,ud_miss
        inc     hl
        inc     de
        djnz    ud_cmp
        ld      a,1
        ld      (ov_on),a
        ret
ud_miss:call    ui_top
        call    ui_bottom
        call    ov_copy
        ld      hl,ov_sn
        ld      de,ov_sg
        ld      bc,8
        ldir
        ld      a,1
        ld      (ov_on),a
        ret

; signature of the overlay now -> ov_sn: paused, progress cell, seconds (word), volume level, FPS shown, FPS value
ud_sig: ld      a,(paused)
        ld      (ov_sn),a
        ld      hl,(nframes)
        ld      de,30
        call    div16
        ld      a,h
        or      l
        jr      nz,us1
        ld      hl,1
us1:    ex      de,hl
        ld      hl,(cur)
        call    div16
        ld      a,l
        cp      30
        jr      c,us2
        ld      a,29
us2:    ld      (ov_sn+1),a
        ld      hl,(cur)
        ld      de,15
        call    div16
        ld      (ov_sn+2),hl
        ld      a,(vol_lv)
        ld      (ov_sn+4),a
        ld      a,(show_fps)
        ld      (ov_sn+5),a
        or      a
        ld      a,0
        jr      z,us3
        ld      a,(fps_v)
us3:    ld      (ov_sn+6),a
        ret

; copy the 8 overlay rows out of BUF into the cache (pattern rows 0-2, 19-23, then the color rows)
ov_copy:ld      hl,BUF
        ld      de,OVB
        ld      bc,768
        ldir
        ld      hl,BUF+1300h
        ld      de,OVB+300h
        ld      bc,1280
        ldir
        ld      hl,BUF+1800h
        ld      de,OVB+800h
        ld      bc,768
        ldir
        ld      hl,BUF+1800h+1300h
        ld      de,OVB+800h+300h
        ld      bc,1280
        ldir
        ret

ui_top: ld      hl,BUF                  ; rows 0..2: black
        ld      de,BUF+1
        ld      bc,767
        ld      (hl),0
        ldir
        ld      hl,BUF+1800h
        ld      de,BUF+1801h
        ld      bc,767
        ld      (hl),10h
        ldir
        ld      hl,ic_back
        ld      de,0001h                ; row 0, col 1
        ld      c,10h
        call    ui_icon
        ld      hl,(fname)              ; title = file name without the path
        ld      d,h
        ld      e,l
ut_s:   ld      a,(de)
        or      a
        jr      z,ut_e
        inc     de
        cp      '\'
        jr      z,ut_p
        cp      ':'
        jr      z,ut_p
        cp      '/'
        jr      nz,ut_s
ut_p:   ld      h,d
        ld      l,e
        jr      ut_s
ut_e:   push    hl
        call    VK_TITLE                ; the entry's own long / Korean name, drawn by vk.asm (CY = not drawn)
        pop     hl
        jr      nc,ut_k
        ld      de,0820h                ; y 8, x 32
        call    gtextf
ut_k:   ld      a,(show_fps)
        or      a
        call    nz,fps_draw
        ld      a,(vmode)               ; V1.11.3: the badge names the SCREEN of the picture: the X86 Multimedia cartridge plays MP4 in the SCREEN it was asked for (P4)
        or      a
        ld      a,2
        jr      z,ub_s
        ld      a,(VC_P4)
ub_s:   push    af
        ld      de,0119h                ; badge: white box (row 1, cols 25..30) with black "SCR2"
        ld      b,6
        cp      13
        jr      c,ub_f
        ld      de,0118h                ; V1.11.18: V9990 (13 / 14): the box is wider (cols 24..31) for "V9 FAST" / "V9 SHARP"
        ld      b,8
ub_f:   ld      a,0FFh
        call    fillc
        pop     af
        cp      13
        jr      nc,ub_v
        ld      hl,s_badge+3
        cp      10
        jr      c,ub_1
        ld      (hl),'1'                ; SCREEN 10, 11, 12
        inc     hl
        sub     10
ub_1:   add     a,'0'
        ld      (hl),a
        inc     hl
        ld      (hl),0
        ld      hl,s_badge
        ld      de,08D4h                ; y 8, x 212
        jp      gtext
ub_v:   ld      hl,s_v9f                ; 13 = V9 FAST, 14 = V9 SHARP: copied into s_badge (9 bytes) and drawn from the left of the wider box
        cp      14
        jr      c,ub_w
        ld      hl,s_v9s
ub_w:   ld      de,s_badge
        ld      bc,9
        ldir
        ld      hl,s_badge
        ld      de,08C4h                ; y 8, x 196
        jp      gtext

ui_bottom:
        ld      hl,BUF+1300h            ; rows 19..23: black
        ld      de,BUF+1301h
        ld      bc,1279
        ld      (hl),0
        ldir
        ld      hl,BUF+1800h+1300h
        ld      de,BUF+1800h+1301h
        ld      bc,1279
        ld      (hl),10h
        ldir
        ; progress cells: unit = nframes / 30, pcell = cur / unit
        ld      hl,(nframes)
        ld      de,30
        call    div16
        ld      a,h
        or      l
        jr      nz,ub1
        ld      hl,1
ub1:    ex      de,hl
        ld      hl,(cur)
        call    div16
        ld      a,l
        ld      b,h
        cp      30
        jr      c,ub2
        ld      a,29
ub2:    ld      (pcell),a
        xor     a
        ld      (uc),a
ub_l:   ld      a,(pcell)
        ld      b,a
        ld      a,(uc)
        ld      ix,cell_played
        cp      b
        jr      c,ub3
        ld      ix,cell_knob
        jr      z,ub3
        ld      ix,cell_track
ub3:    ld      a,(uc)
        inc     a
        ld      e,a
        ld      d,19
        call    cellptr
        ld      c,10h
        call    put8
        ld      a,(uc)
        inc     a
        ld      (uc),a
        cp      30
        jr      nz,ub_l
        ; buttons (row 21/22): prev, play/pause (inverse = focus), next
        ld      hl,ic_prev
        ld      de,1501h                ; row 21, col 1
        ld      c,10h
        call    ui_icon
        ld      hl,ic_pause
        ld      a,(paused)
        or      a
        jr      z,ub4
        ld      hl,ic_play
ub4:    ld      de,1503h                ; col 3
        ld      c,01h                   ; black on white
        call    ui_icon
        ld      hl,ic_next
        ld      de,1505h                ; col 5
        ld      c,10h
        call    ui_icon
        ld      hl,ic_vol
        ld      a,(vol_lv)
        cp      5
        jr      c,ub5
        ld      hl,ic_mute
ub5:    ld      de,1508h                ; col 8
        ld      c,10h
        call    ui_icon
        ; volume bars: 6 columns (cols 11..16), height 4+2k, filled = volbars[vol_lv]
        ld      a,(vol_lv)
        ld      c,a
        ld      b,0
        ld      hl,volbars
        add     hl,bc
        ld      a,(hl)
        ld      (vfill),a
        xor     a
        ld      (uc),a
vb_k:   ld      a,(uc)
        add     a,a
        add     a,4
        ld      c,a                     ; height
        ld      a,15
        sub     c
        ld      c,a                     ; top line
        ld      a,(vfill)
        ld      b,a
        ld      a,(uc)
        cp      b
        ld      a,0FFh                  ; filled bar
        jr      c,vb_p
        xor     a                       ; unfilled -> checker
vb_p:   ld      (vpat),a
        ld      b,0
        ld      hl,tmp16
vb_y:   ld      a,b
        cp      c
        jr      c,vb_z
        cp      15
        jr      nc,vb_z
        ld      a,(vpat)
        or      a
        jr      nz,vb_w
        ld      a,b
        and     1
        ld      a,0AAh
        jr      z,vb_w
        ld      a,55h
vb_w:   ld      (hl),a
        jr      vb_n
vb_z:   ld      (hl),0
vb_n:   inc     hl
        inc     b
        ld      a,b
        cp      16
        jr      nz,vb_y
        ld      ix,tmp16
        ld      a,(uc)
        add     a,11
        ld      e,a
        ld      d,21
        push    de
        call    cellptr
        ld      c,10h
        call    put8
        pop     de
        inc     d
        call    cellptr
        ld      c,10h
        call    put8
        ld      a,(uc)
        inc     a
        ld      (uc),a
        cp      6
        jr      nz,vb_k
        ; time text "m:ss/m:ss"
        ld      hl,(cur)
        ld      de,15
        call    div16
        ld      de,tbuf
        call    fmt_time
        ld      a,'/'
        call    fput
        ld      hl,(nframes)
        ld      de,15
        call    div16
        ld      de,(fd)                 ; continue after the '/'
        call    fmt_time
        xor     a
        call    fput
        ld      hl,tbuf
        ld      de,0AC90h               ; y 172, x 144
        jp      gtext

; HL = seconds, DE = destination -> "m:ss"
fmt_time:
        ld      (fd),de
        ld      de,60
        call    div16
        ld      (f_sec),de
        ld      de,10
        call    div16
        ld      (f_min1),de
        ld      a,l
        or      a
        jr      z,fm1
        add     a,'0'
        call    fput
fm1:    ld      a,(f_min1)
        add     a,'0'
        call    fput
        ld      a,':'
        call    fput
        ld      hl,(f_sec)
        ld      de,10
        call    div16
        ld      a,l
        add     a,'0'
        call    fput
        ld      a,e
        add     a,'0'
        jp      fput
fput:   ld      hl,(fd)
        ld      (hl),a
        inc     hl
        ld      (fd),hl
        ret

; ---- redraw the current frame (used while paused) ----
redraw_frame:
        xor     a
        ld      (redraw),a
        ld      hl,(cur)
        ld      a,h
        and     l
        inc     a
        ret     z                       ; nothing shown yet
        ld      a,(vmode)
        or      a
        jp      nz,VC_REDRAW    ; X86 Video: only the overlay changes
        ld      b,h
        ld      c,l
        call    fseek
        ret     c
        call    fread
        ret     c
        ld      hl,(fpos)
        inc     hl
        ld      (fpos),hl
        call    ui_draw
        jp      showframe

; ---- seek: HL = target frame ----
seek_to:ld      (tgt),hl
        ld      a,(vmode)
        or      a
        jr      z,st_novm
        call    VC_SEEK         ; X86 Video: the cartridge jumps (HL = target)
        jr      st_c
st_novm:  ld      a,(cart_on)
        or      a
        jr      z,st_n0
        call    cart_seek
        jr      st_c
st_n0:  ld      a,(aud_on)
        or      a
        jr      z,st_j
        call    audio_seek
        jr      st_c
st_j:   ld      hl,(tgt)                ; JIFFY clock: t0 = reference - ticks(target)
        ld      a,(pal)
        or      a
        jr      nz,st_p
        add     hl,hl
        add     hl,hl
        jr      st_t
st_p:   ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; x5
        add     hl,hl                   ; x10
        ld      de,3
        call    div16
st_t:   ex      de,hl
        ld      hl,(JIFFY)
        ld      a,(paused)
        or      a
        jr      z,st_s
        ld      hl,(pstart)
st_s:   or      a
        sbc     hl,de
        ld      (t0),hl
st_c:   ld      a,(paused)
        or      a
        jr      z,st_run
        ld      hl,(tgt)
        ld      (cur),hl
        ld      a,1
        ld      (redraw),a
        ret
st_run: ld      hl,0FFFFh
        ld      (cur),hl
        ret

; audio: move the MVA file pointer and restart the ring buffer at the new position
audio_seek:
        call    audio_pause
        ld      hl,0                    ; C:HL = tgt * spf + 16
        ld      c,0
        ld      de,(aud_spf)
        ld      ix,(tgt)
as_m:   ld      a,ixh
        or      ixl
        jr      z,as_d
        add     hl,de
        jr      nc,as_n
        inc     c
as_n:   dec     ix
        jr      as_m
as_d:   ld      de,16
        add     hl,de
        jr      nc,as_e
        inc     c
as_e:   ld      d,0
        ld      e,c
        ld      a,(h2)
        ld      b,a
        xor     a                       ; from the beginning
        ld      c,4Ah                   ; _SEEK
        call    BDOS
        di
        ld      hl,RING
        ld      (rp),hl
        ld      (wr_ptr),hl
        xor     a
        ld      (aud_eof),a
        ld      hl,(tgt)
        ld      (aidx),hl
        ld      hl,0
        ld      (rem),hl
        ld      hl,(cnt)
        ld      (lastcnt),hl
        ei
        call    refill
        ld      a,(paused)
        or      a
        ret     nz
        jp      audio_resume

; ---- volume ----
key_up: ld      a,(vol_lv)
        or      a
        ret     z
        dec     a
        jr      vol_set
key_down:
        ld      a,(vol_lv)
        cp      4
        ret     nc
        inc     a
vol_set:ld      (vol_lv),a
        xor     a
        ld      (muted),a
        jr      vol_apply
key_mute:
        ld      a,(muted)
        xor     1
        ld      (muted),a
vol_apply:
        ld      a,(muted)
        or      a
        ld      a,(vol_lv)
        jr      z,va1
        ld      a,5                     ; mute set
va1:    ld      c,a
        add     a,a
        add     a,c
        add     a,VTAB/256              ; PSG set page = VTAB + 3*level
        ld      (vtab_h),a
        ld      a,c
        add     a,VTAB/256+12h          ; PCM set page = VTAB + 12h + level
        ld      (ptab_h),a
        jp      cart_vol

key_left:
        ld      hl,(cur)
        ld      a,h
        and     l
        inc     a
        ret     z
        ld      de,SEEKFR
        or      a
        sbc     hl,de
        jr      nc,kl1
        ld      hl,0
kl1:    jp      seek_to

key_right:
        ld      hl,(cur)
        ld      a,h
        and     l
        inc     a
        ret     z
        ld      de,SEEKFR
        add     hl,de
        ld      de,(nframes)
        dec     de
        push    hl
        or      a
        sbc     hl,de
        pop     hl
        jr      c,kr1
        ex      de,hl                   ; clamp to the last frame
kr1:    jp      seek_to

key_space:
        ld      a,(paused)
        xor     1
        ld      (paused),a
        jr      z,ks_res
        call    audio_pause
        call    cart_pause
        ld      hl,(JIFFY)
        ld      (pstart),hl
        ret
ks_res: call    audio_resume
        call    cart_resume
        ld      hl,(JIFFY)
        ld      de,(pstart)
        or      a
        sbc     hl,de
        ld      de,(t0)
        add     hl,de
        ld      (t0),hl
        ret

s_badge:defb    "SCR2",0,0,0,0          ; (the number is written at every draw; 9 bytes: "V9 SHARP",0)
s_v9f:  defb    "V9 FAST",0
s_v9s:  defb    "V9 SHARP",0

; ---- keys: ESC quit, SPACE pause, LEFT/RIGHT seek, UP/DOWN volume, M mute ----
keys:   di
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
        jp      z,done
        ld      a,e
        cpl
        ld      b,a                     ; B = pressed (row 8)
        ld      a,c
        cpl
        and     04h
        ld      c,a                     ; C = M pressed
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
        ld      a,b                     ; auto repeat for UP/DOWN (volume) only; LEFT/RIGHT move 5 s per press
        and     60h
        jr      z,kh0
        ld      a,(khold)
        inc     a
        ld      (khold),a
        ld      c,3                     ; playing: repeat after 3 polls (one poll = one frame)
        ld      a,(paused)
        or      a
        jr      z,kh1
        ld      c,12                    ; paused: polls are 32 ms apart -> start after ~0.4 s
kh1:    ld      a,(khold)
        cp      c
        jr      c,kh3                   ; not yet
        ld      a,c
        ld      c,a
        ld      a,(paused)
        or      a
        ld      a,c
        jr      z,kh4
        sub     6                       ; paused: next repeat after 6 polls (~0.2 s)
        jr      kh5
kh4:    dec     a                       ; playing: repeat on every poll
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
        ld      a,d
        ld      (kd),a
        ld      a,e
        ld      (ke),a
        call    ui_touch
        ld      a,(kd)
        bit     0,a
        call    nz,key_space
        ld      a,(kd)
        bit     4,a
        call    nz,key_left
        ld      a,(kd)
        bit     7,a
        call    nz,key_right
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
        ld      (redraw),a              ; paused: show the change on the held frame
        ret
