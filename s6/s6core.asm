; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  s6ui.asm - X86MVUI.OVL (V1.11.25): the SCREEN 6 (512 x 212, 4 colours) file browser, drive popup and settings page of X86MV
;  white page, black text, blue bars (the same family as the play bar), yellow only for the folder icon
;  read to 5000h by X86MV.COM; entry table: +0 full page, +3 selection moved, +6 popup (drives / the values of a setting), +9 settings page
;  build: pasmo --bin s6ui.asm X86MVUI.OVL   (s6syms.inc = symbols of X86MV.COM)
;  design: X86MSX방_전달문서_MV6_파일브라우저_설정_SCREEN6 (all coordinates below are from it)
; ============================================================
        org     5000h
        include "s6syms.inc"
        include "stampm.inc"            ; BSTAMP of the module (build.py: the same value as the main program's)
VC_CAPS equ     718Eh
VK_NAME equ     7618h
FONTC   equ     0B200h
FONTW   equ     0B500h
ROWBUF  equ     8000h                   ; BUF is free while the list is shown (the page is drawn straight into the VRAM)
TBUF    equ     8400h
BR_ENT  equ     6000h
BR_STR  equ     7F90h
BR_DIR  equ     7F50h
BDOS    equ     0005h
        include "s6vars.inc"

C_WHITE equ     0                       ; palette numbers (s6_pal)
C_BLACK equ     1
C_BLUE  equ     2
C_YELL  equ     3
ROWS    equ     11                      ; list rows of 12 pixels from y = 48
LIST_Y  equ     48

IF S6SET
        jp      s6_nop                  ; +0 (the settings module has no list)
        jp      s6_nop                  ; +3
        jp      s6_pop                  ; +6 the popup of the values of a setting
        jp      s6_set                  ; +9 the settings page
        jp      s6_supd                 ; +12 V1.11.27: only the rows set_old and set_sel (and the help line) again
        jp      s6_psave                ; +15 V1.11.27: the picture under the popup of the item set_sel -> page 1
        jp      s6_prest                ; +18 and back
ELSE
        jp      s6_show                 ; +0 full page
        jp      s6_upd                  ; +3 selection moved
        jp      s6_pop                  ; +6 drive popup
        jp      s6_nop                  ; +9
ENDIF
s6_nop: ret

        include "s6eng.inc"

; ======================= shapes =======================
; call s6_btnr / defw x,y,w,h : a white button: black 1 pixel frame, the corners cut in two steps
s6_btnr:pop     hl
        ld      de,b_x
        ld      bc,8
        ldir
        push    hl
s6_btnw:ld      hl,(b_x)                ; white inside
        ld      (s6_rx),hl
        ld      hl,(b_y)
        ld      (s6_ry),hl
        ld      hl,(b_w)
        ld      (s6_rw),hl
        ld      hl,(b_h)
        ld      (s6_rh),hl
        xor     a
        ld      (s6_rc),a
        call    s6_fill
s6_btn: ld      a,C_BLACK
        ld      (s6_rc),a
        ld      hl,(b_x)                ; top and bottom lines (x+2 .. x+w-3)
        inc     hl
        inc     hl
        ld      (s6_rx),hl
        ld      hl,(b_w)
        dec     hl
        dec     hl
        dec     hl
        dec     hl
        ld      (s6_rw),hl
        ld      hl,1
        ld      (s6_rh),hl
        ld      hl,(b_y)
        ld      (s6_ry),hl
        call    s6_fill
        ld      hl,(b_y)
        ld      de,(b_h)
        add     hl,de
        dec     hl
        ld      (s6_ry),hl
        call    s6_fill
        ld      hl,(b_y)                ; left and right lines (y+2 .. y+h-3)
        inc     hl
        inc     hl
        ld      (s6_ry),hl
        ld      hl,(b_h)
        dec     hl
        dec     hl
        dec     hl
        dec     hl
        ld      (s6_rh),hl
        ld      hl,1
        ld      (s6_rw),hl
        ld      hl,(b_x)
        ld      (s6_rx),hl
        call    s6_fill
        ld      hl,(b_x)
        ld      de,(b_w)
        add     hl,de
        dec     hl
        ld      (s6_rx),hl
        call    s6_fill
        ld      hl,1                    ; the four corner dots: (x+1, y+1) (x+w-2, y+1) (x+w-2, y+h-2) (x+1, y+h-2)
        ld      (s6_rh),hl
        ld      hl,(b_y)
        inc     hl
        ld      (s6_ry),hl
        ld      hl,(b_x)
        inc     hl
        ld      (s6_rx),hl
        call    s6_fill
        ld      hl,(b_x)
        ld      de,(b_w)
        add     hl,de
        dec     hl
        dec     hl
        ld      (s6_rx),hl
        call    s6_fill
        ld      hl,(b_y)
        ld      de,(b_h)
        add     hl,de
        dec     hl
        dec     hl
        ld      (s6_ry),hl
        call    s6_fill
        ld      hl,(b_x)
        inc     hl
        ld      (s6_rx),hl
        jp      s6_fill

; DE = x, A = y of the first row: a black 8 x 4 arrow pointing down
s6_arrow:
        ld      (s6_rx),de
        ld      l,a
        ld      h,0
        ld      (s6_ry),hl
        ld      a,C_BLACK
        ld      (s6_rc),a
        ld      hl,8
        ld      (s6_rw),hl
        ld      hl,1
        ld      (s6_rh),hl
        ld      b,4
ar_l:   push    bc
        call    s6_fill
        pop     bc
        ld      hl,(s6_rx)
        inc     hl
        ld      (s6_rx),hl
        ld      hl,(s6_rw)
        dec     hl
        dec     hl
        ld      (s6_rw),hl
        ld      hl,(s6_ry)
        inc     hl
        ld      (s6_ry),hl
        djnz    ar_l
        ret

; the blue title bar with "X86MV" (14 pixels high); the page title follows (text y 2: the glyphs stand 3 pixels from the top)
s6_title:
        call    s6_rect
        defw    0,0,512,14
        defb    C_BLUE
        call    s6_l
        defw    6
        defb    2,C_WHITE,C_BLUE
        defb    "X86MV",0,"X86MV",0
        ret

; the info line area (a blue line at row 183, rows 184..196 white) and the blue help bar (rows 198..211)
s6_ibar:call    s6_rect
        defw    0,183,512,1
        defb    C_BLUE
        call    s6_rect
        defw    0,184,512,13
        defb    C_WHITE
        ret
s6_hbar:call    s6_rect
        defw    0,198,512,14
        defb    C_BLUE
        ret

; call kd / defw x / defb y / defb key E,0,key K,0, word E,0,word K,0 : a help bar entry, the key white, its word black, 6 pixels behind the key
kd:     pop     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      (s6_ty),a
        ld      (s6_tx),de
        ld      a,C_WHITE
        ld      (s6_fg),a
        ld      a,C_BLUE
        ld      (s6_bg),a
        ld      de,500
        ld      (s6_lim),de
        call    lb_draw                 ; the key
        push    hl
        ld      hl,(s6_tx)              ; x of the word = the key's left byte + its width + 6
        ld      a,l
        and     0FCh
        ld      l,a
        ld      de,(s6_cx)
        add     hl,de
        ld      de,6
        add     hl,de
        ld      (s6_tx),hl
        ld      a,C_BLACK
        ld      (s6_fg),a
        pop     hl
        call    lb_draw
        jp      (hl)

IF S6SET
ELSE
; ======================= the file browser =======================
s6_show:call    s6_init
        call    s6_frame
        call    s6_rows
        call    s6_bar
        call    s6_info
        call    s6_hbar
        call    kd
        defw    6
        defb    200
        defb    "ENTER",0,"ENTER",0,"PLAY",0,"재생",0
        call    kd
        defw    110
        defb    200
        defb    "D",0,"D",0,"DRIVES",0,"드라이브",0
        call    kd
        defw    226
        defb    200
        defb    "BS",0,"BS",0,"UP",0,"위로",0
        call    kd
        defw    322
        defb    200
        defb    "S",0,"S",0,"SETUP",0,"설정",0
        call    kd
        defw    408
        defb    200
        defb    "ESC",0,"ESC",0,"QUIT",0,"끝내기",0
        ret

s6_frame:
        call    s6_title
        call    s6_l
        defw    48
        defb    2,C_WHITE,C_BLUE
        defb    "OPEN",0,"영상 열기",0
        ld      de,BR_STR               ; the number of entries at the right end ("19" / "19개")
        ld      hl,(br_cnt)
        call    utoa
        ld      hl,s_gae
        ld      bc,3
        ldir
        xor     a
        ld      (de),a
        ld      hl,506
        ld      (s6_tx),hl
        ld      a,2
        ld      (s6_ty),a
        ld      a,C_WHITE
        ld      (s6_fg),a
        ld      a,C_BLUE
        ld      (s6_bg),a
        ld      a,1
        ld      (s6_al),a
        ld      hl,500
        ld      (s6_lim),hl
        ld      hl,BR_STR
        call    s6_u8
        call    s6_path                 ; BR_STR = the path
        call    s6_btnr                 ; the drive button: the path up to its colon, and the arrow
        defw    6,17,56,14
        ld      hl,BR_STR
fr_d:   ld      a,(hl)
        inc     hl
        cp      ':'
        jr      z,fr_e
        or      a
        jr      nz,fr_d
        dec     hl
fr_e:   ld      a,(hl)
        push    af
        push    hl
        ld      (hl),0
        ld      hl,10
        ld      bc,36
        call    fr_txt
        pop     hl
        pop     af
        ld      (hl),a
        ld      de,50
        ld      a,22
        call    s6_arrow
        call    s6_btnr                 ; the path box
        defw    66,17,440,14
        ld      hl,71
        ld      bc,430
        call    fr_txt
        call    s6_l                    ; column heads
        defw    22
        defb    35,C_BLUE,C_WHITE
        defb    "NAME",0,"이름",0
        call    s6_l
        defw    386
        defb    35,C_BLUE,C_WHITE
        defb    "TIME",0,"길이",0
        call    s6_l
        defw    462
        defb    35,C_BLUE,C_WHITE
        defb    "SIZE",0,"크기",0
        call    s6_rect
        defw    0,46,512,1
        defb    C_BLUE
        ret
s_gae:  defb    0EAh,0B0h,9Ch           ; "개"

; HL = x, BC = width limit: BR_STR in black on white at y 19 (inside a button)
fr_txt: ld      (s6_tx),hl
        ld      (s6_lim),bc
        ld      a,19
        ld      (s6_ty),a
        ld      a,C_BLACK
        ld      (s6_fg),a
        xor     a
        ld      (s6_bg),a
        ld      (s6_al),a
        ld      hl,BR_STR
        jp      s6_u8

; path line: DOS "A:\dir" (or the USB path built by main) -> BR_STR
s6_path:
        ld      a,(br_host)
        cp      2
        jp      z,br_upath
        ld      c,19h                   ; _CURDRV
        call    BDOS
        add     a,'A'
        ld      hl,BR_STR
        ld      (hl),a
        inc     hl
        ld      (hl),':'
        inc     hl
        ld      (hl),'\'
        inc     hl
        push    hl
        ld      b,0
        ld      de,BR_DIR
        ld      c,59h                   ; _GETCD
        call    BDOS
        pop     de
        ld      hl,BR_DIR
        ld      b,60
pa_c:   ld      a,(hl)
        or      a
        jr      z,pa_e
        ld      (de),a
        inc     hl
        inc     de
        djnz    pa_c
pa_e:   xor     a
        ld      (de),a
        ret

; the 11 rows
s6_rows:xor     a
sr_l:   push    af
        call    s6_row
        pop     af
        inc     a
        cp      ROWS
        jr      c,sr_l
        ret

; A = row 0..10: draws the entry br_top + A (or an empty row); u_ty = its top y
s6_row: ld      (u_i),a
        ld      c,a                     ; y = 48 + 12 * row
        add     a,a
        add     a,c
        add     a,a
        add     a,a
        add     a,LIST_Y
        ld      (u_ty),a
        ld      (s6_ry),a
        xor     a
        ld      (s6_ry+1),a
        ld      hl,(br_top)
        ld      a,(u_i)
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (u_idx),hl
        ld      de,(br_cnt)
        or      a
        sbc     hl,de
        jr      c,sw_e
        xor     a                       ; empty row
        ld      (u_bg),a
        jp      s6_barfill
sw_e:   ld      hl,(u_idx)              ; the selected row: white on blue, the others black on white
        ld      de,(br_sel)
        or      a
        sbc     hl,de
        ld      a,C_WHITE
        ld      b,C_BLACK
        jr      nz,sw_ns
        ld      a,C_BLUE
        ld      b,C_WHITE
sw_ns:  ld      (u_bg),a
        ld      a,b
        ld      (u_fg),a
        call    s6_barfill
        ld      hl,(u_idx)
        call    br_entaddr
        ld      (u_ent),hl
        ; icon (12 x 6 at x 5, 3 pixels below the row top): the folder yellow (white when selected), the film black
        ld      a,(hl)
        cp      2
        ld      a,(u_fg)
        ld      hl,ic_film
        jr      z,ic_d
        ld      hl,ic_fold
        ld      b,a
        ld      a,(u_bg)
        or      a
        ld      a,b
        jr      nz,ic_d
        ld      a,C_YELL
ic_d:   ld      (s6_fg),a
        ld      a,(u_bg)
        ld      (s6_bg),a
        ld      de,BMB
        ld      bc,12
        ldir
        ld      a,6
        ld      (s6_bh),a
        ld      (s6_nr),a
        ld      a,2
        ld      (s6_bpr),a
        xor     a
        ld      (s6_ro),a
        ld      hl,5
        ld      (s6_tx),hl
        ld      a,(u_ty)
        add     a,3
        ld      (s6_ty),a
        call    s6_clr
        call    s6_blt
        ld      hl,(s6_cx)
        ld      de,12
        add     hl,de
        ld      (s6_cx),hl
        call    s6_send
        ; name (x 22)
        call    s6_setrow
        ld      hl,22
        ld      (s6_tx),hl
        ld      hl,376
        ld      (s6_lim),hl
        ld      hl,(u_ent)
        call    s6_nm
        ; length and size: files of the DOS drive only
        ld      hl,(u_ent)
        ld      a,(hl)
        cp      2
        ret     nz
        ld      a,(br_host)
        or      a
        ret     nz                      ; the cartridge folders and the USB give no size here
        ld      hl,(u_ent)
        inc     hl
        ld      b,13
sw_d:   ld      a,(hl)
        or      a
        ret     z
        inc     hl
        cp      '.'
        jr      z,sw_x
        djnz    sw_d
        ret
sw_x:   ld      de,BR_STR               ; extension (up to 3 characters) -> BR_STR
        ld      b,3
sw_y:   ld      a,(hl)
        or      a
        jr      z,sw_z
        ld      (de),a
        inc     hl
        inc     de
        djnz    sw_y
sw_z:   xor     a
        ld      (de),a
        ld      hl,(u_ent)
        ld      de,14
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (u_sz),de
        ld      a,d
        or      e
        ret     z
        ld      a,(BR_STR)              ; the length: MV files only (from the size and the format)
        and     0DFh
        cp      'M'
        jp      nz,sw_sz
        ld      a,(BR_STR+1)
        and     0DFh
        cp      'V'
        jp      nz,sw_sz
        ld      a,(BR_STR+2)
        cp      'a'
        jr      c,sw_u
        and     0DFh
sw_u:   ld      hl,s_tm
        ld      b,3
sw_s:   cp      (hl)
        jr      z,sw_s1
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        djnz    sw_s
        ld      hl,s_tm+12              ; the other formats: 5 frames per second, 54272 bytes
sw_s1:  inc     hl
        ld      a,(hl)
        ld      (u_am),a
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (u_dv),de
        ld      hl,(u_sz)
        call    div16
        push    bc
        ld      a,(u_am)
        call    mulA
        pop     bc
        push    hl
        ld      h,b
        ld      l,c
        ld      a,(u_am)
        call    mulA
        ld      de,(u_dv)
        call    div16
        pop     de
        add     hl,de                   ; seconds
        ld      de,60
        call    div16                   ; HL minutes, BC seconds
        push    bc
        ld      de,BR_STR
        call    utoa
        ld      a,':'
        ld      (de),a
        inc     de
        pop     bc
        ld      a,c
        ld      c,'0'
sw_t:   cp      10
        jr      c,sw_t1
        sub     10
        inc     c
        jr      sw_t
sw_t1:  ld      b,a
        ld      a,c
        ld      (de),a
        inc     de
        ld      a,b
        add     a,'0'
        ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        call    s6_setrow
        ld      a,1
        ld      (s6_al),a
        ld      hl,444                  ; the length ends at x 444
        ld      (s6_tx),hl
        ld      hl,BR_STR
        call    s6_u8
sw_sz:  ld      hl,(u_sz)               ; 4 KB units: K below 1000 K, else M with one decimal
        ld      de,BR_STR
        ld      a,h
        or      a
        jr      nz,sz_m
        ld      a,l
        cp      250
        jr      c,sz_k
sz_m:   ld      a,h
        ld      c,l
        ld      l,a
        ld      h,0
        push    bc
        call    utoa
        pop     bc
        ld      a,'.'
        ld      (de),a
        inc     de
        ld      h,0
        ld      l,c
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,hl
        add     hl,bc
        add     hl,hl
        ld      a,h
        add     a,'0'
        ld      (de),a
        inc     de
        ld      a,'M'
        jr      sz_e
sz_k:   add     hl,hl
        add     hl,hl
        call    utoa
        ld      a,'K'
sz_e:   ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        call    s6_setrow
        ld      a,1
        ld      (s6_al),a
        ld      hl,500                  ; the size ends at x 500
        ld      (s6_tx),hl
        ld      hl,BR_STR
        jp      s6_u8

; HL / DE -> HL quotient, BC remainder
div16:  ld      a,16
        ld      (u_cnt),a
        ld      bc,0
dv_l:   add     hl,hl
        rl      c
        rl      b
        ld      a,c
        sub     e
        ld      c,a
        ld      a,b
        sbc     a,d
        ld      b,a
        jr      nc,dv_o
        ld      a,c
        add     a,e
        ld      c,a
        ld      a,b
        adc     a,d
        ld      b,a
        jr      dv_n
dv_o:   inc     l
dv_n:   ld      a,(u_cnt)
        dec     a
        ld      (u_cnt),a
        jr      nz,dv_l
        ret
; HL = HL * A (A >= 1)
mulA:   ld      b,a
        ld      d,h
        ld      e,l
        ld      hl,0
ml_l:   add     hl,de
        djnz    ml_l
        ret
; third letter, multiplier, divisor: seconds = size (4 KB units) * multiplier / divisor (frame size and default speed of the format)
s_tm:   defb    '2',1
        defw    60
        defb    '5',8
        defw    435
        defb    '6',8
        defw    435
        defb    '7',4                   ; default entry
        defw    265

; icons 12 x 6 (two bytes a row)
ic_fold:defb    0F8h,00h, 0FFh,0F0h, 0FFh,0F0h, 0FFh,0F0h, 0FFh,0F0h, 0FFh,0F0h
ic_film:defb    3Fh,0C0h, 2Dh,0C0h, 3Fh,0C0h, 3Fh,0C0h, 2Dh,0C0h, 3Fh,0C0h

; s6_ty, colours for the entry text of the current row (the glyphs stand 2 pixels below the row top)
s6_setrow:
        ld      a,(u_ty)
        inc     a
        ld      (s6_ty),a
        ld      a,(u_fg)
        ld      (s6_fg),a
        ld      a,(u_bg)
        ld      (s6_bg),a
        ld      hl,500
        ld      (s6_lim),hl
        xor     a
        ld      (s6_al),a
        ret

; bar of the row: x 0, w 500, h 12, colour u_bg, y = s6_ry
s6_barfill:
        ld      hl,0
        ld      (s6_rx),hl
        ld      hl,500
        ld      (s6_rw),hl
        ld      hl,12
        ld      (s6_rh),hl
        ld      a,(u_bg)
        ld      (s6_rc),a
        jp      s6_fill

; scroll bar x 504..509, y 48..179: the track is a 2 x 2 grey check, the thumb blue (its height = rows shown / entries, its place = the first row shown / entries)
s6_bar: ld      hl,ROWBUF               ; track: 12 rows of one composed byte: 11001100 (rows 0, 1) / 00110000 (rows 2, 3) ...
        ld      b,12
        ld      c,0
tk_l:   ld      a,c
        and     2
        ld      a,0CCh
        jr      z,tk_a
        ld      a,30h
tk_a:   ld      (hl),a
        ld      de,RB
        add     hl,de
        inc     c
        djnz    tk_l
        ld      hl,504
        ld      (s6_tx),hl
        ld      hl,8
        ld      (s6_cx),hl
        ld      a,12
        ld      (s6_nr),a
        ld      a,C_BLACK
        ld      (s6_fg),a
        xor     a
        ld      (s6_bg),a
        ld      a,LIST_Y
        ld      b,11
tk_s:   ld      (s6_ty),a
        push    af
        push    bc
        call    s6_send
        pop     bc
        pop     af
        add     a,12
        djnz    tk_s
        ld      hl,(br_cnt)
        ld      a,h
        or      l
        ret     z
        ld      (u_tmp),hl
        ld      de,ROWS+1
        or      a
        sbc     hl,de
        ld      hl,132                  ; every entry fits: the thumb fills the bar
        ld      de,0
        jr      c,sb_d
        ld      hl,132*ROWS
        ld      de,(u_tmp)
        call    div16
        ld      a,l
        cp      6
        jr      nc,sb_h1
        ld      a,6
sb_h1:  ld      (sb_h),a
        ld      hl,(br_top)
        ld      a,132
        call    mulA
        ld      de,(u_tmp)
        call    div16
        ld      a,(sb_h)
        ld      c,a
        ld      a,132
        sub     c
        cp      l
        jr      nc,sb_p1
        ld      l,a
sb_p1:  ld      e,l
        ld      d,0
        ld      a,(sb_h)
        ld      l,a
        ld      h,0
sb_d:   ld      a,l
        ld      (sb_h),a
        ld      a,e
        ld      (sb_p),a
        ld      a,(sb_p)
        add     a,LIST_Y
        ld      l,a
        ld      h,0
        ld      (s6_ry),hl
        ld      a,(sb_h)
        ld      l,a
        ld      h,0
        ld      (s6_rh),hl
        ld      a,C_BLUE
        ld      (s6_rc),a
        ld      hl,504
        ld      (s6_rx),hl
        ld      hl,4
        ld      (s6_rw),hl
        call    s6_fill
        ld      hl,508
        ld      (s6_rx),hl
        ld      hl,2
        ld      (s6_rw),hl
        jp      s6_fill

; the info line: the selected name (or the note of a failed play) at x 6, "sel/count" in blue at the right end
s6_info:call    s6_ibar
        ld      a,C_BLACK
        ld      (s6_fg),a
        xor     a
        ld      (s6_bg),a
        ld      (s6_al),a
        ld      a,185
        ld      (s6_ty),a
        ld      hl,6
        ld      (s6_tx),hl
        ld      hl,380
        ld      (s6_lim),hl
        ld      hl,(br_note)
        ld      a,h
        or      l
        jr      z,sf_nm
        ld      de,BR_STR               ; the one-line note of a failed play (shown once)
        ld      b,60
sn_c:   ld      a,(hl)
        cp      13
        jr      z,sn_e
        cp      '$'
        jr      z,sn_e
        or      a
        jr      z,sn_e
        ld      (de),a
        inc     hl
        inc     de
        djnz    sn_c
sn_e:   xor     a
        ld      (de),a
        ld      h,a
        ld      l,a
        ld      (br_note),hl
        ld      hl,BR_STR
        call    s6_u8
        jr      sf_cn
sf_nm:  ld      hl,(br_cnt)
        ld      a,h
        or      l
        ret     z
        ld      hl,(br_sel)
        call    br_entaddr
        ld      (u_ent),hl
        call    s6_nm
sf_cn:  ld      hl,(br_cnt)
        ld      a,h
        or      l
        ret     z
        ld      de,BR_STR
        ld      hl,(br_sel)
        inc     hl
        call    utoa
        ld      a,'/'
        ld      (de),a
        inc     de
        ld      hl,(br_cnt)
        call    utoa
        xor     a
        ld      (de),a
        ld      a,C_BLUE
        ld      (s6_fg),a
        ld      a,1
        ld      (s6_al),a
        ld      a,185
        ld      (s6_ty),a
        ld      hl,506
        ld      (s6_tx),hl
        ld      hl,BR_STR
        jp      s6_u8

; the selection moved: br_osel, br_otop (before) -> redraw the changed rows, the bar and the info line
s6_upd: ld      hl,(br_top)
        ld      de,(br_otop)
        or      a
        sbc     hl,de
        jr      nz,su_all
        ld      hl,(br_osel)            ; cursor only: the old and the new row
        call    su_row
        ld      hl,(br_sel)
        call    su_row
        jp      s6_info
su_all: call    s6_rows
        call    s6_bar
        jp      s6_info

; HL = entry index -> redraw its row when it is on screen
su_row: ld      de,(br_top)
        or      a
        sbc     hl,de
        ret     c
        ld      a,h
        or      a
        ret     nz
        ld      a,l
        cp      ROWS
        ret     nc
        jp      s6_row

; the name of the record HL (type, name): the cartridge's long / Korean name when there is one, else the 8.3 name -> s6_u8
; (s6_tx s6_ty s6_fg s6_bg s6_lim set)
s6_nm:  ld      a,(hl)
        ld      (bl_ty),a
        inc     hl
        push    hl
        ld      a,(VC_CAPS)
        and     4
        jr      z,nm_a
        ld      a,(br_host)
        or      a
        jr      z,nm_v
        cp      2
        jr      nz,nm_a
        ld      de,13                   ; USB: only names with the "long / non-ASCII" mark (bit 7 of the item number)
        add     hl,de
        inc     hl
        bit     7,(hl)
        jr      z,nm_a
nm_v:   pop     hl
        push    hl
        call    VK_NAME
        jr      c,nm_a
        pop     hl
        ld      hl,NMBUF
        jp      s6_u8
nm_a:   pop     hl
        jp      s6_u8
NMBUF   equ     7D80h

ENDIF
; ======================= popups =======================
; (vc.asm: the list of drives dp_n, dp_id, dp_nm, dp_sel, dp_cur is theirs; the settings page fills them with the values of the item: dp_cur = 0FFh)
; the drives: x 6, y 31, w 112.  A setting: x 150, w 200, y = 13 below the top of its button.  Rows of 12 pixels, a black frame
DPS     equ     7000h
dp_n    equ     DPS+0
dp_sel  equ     DPS+1
dp_cur  equ     DPS+2
dp_id   equ     DPS+16                  ; ids: 0..7 DOS drive A:..H:, 80h+n USB drive n (a setting: the value, + 40h on the one set now)
dp_nm   equ     DPS+32                  ; names, 24 bytes each
PRH     equ     12

IF S6SET
ss_y:   defb    36,74,96                ; y of the item rows (18 high); the value button is 2 below
s6_pop: ld      hl,150                  ; a setting: x 150, w 200, y = 13 below the top of its button
        ld      (pg_x),hl
        ld      hl,200
        ld      (pg_w),hl
        ld      a,(set_sel)
        ld      e,a
        ld      d,0
        ld      hl,ss_y
        add     hl,de
        ld      l,(hl)
        ld      h,0
        ld      de,15                   ; button top (item y + 2) + 13
        add     hl,de
        ld      (pg_y),hl
ELSE
s6_pop: ld      hl,6                    ; the drives: x 6, y 31, w 112
        ld      (pg_x),hl
        ld      hl,31
        ld      (pg_y),hl
        ld      hl,112
        ld      (pg_w),hl
ENDIF
pp_g:   ld      a,(dp_n)                ; the height: 12 n + 2
        ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,de
        add     hl,hl
        add     hl,hl
        inc     hl
        inc     hl
        ld      (b_h),hl
        ld      (s6_rh),hl
        ld      hl,(pg_x)
        ld      (b_x),hl
        ld      (s6_rx),hl
        ld      hl,(pg_y)
        ld      (b_y),hl
        ld      (s6_ry),hl
        ld      hl,(pg_w)
        ld      (b_w),hl
        ld      (s6_rw),hl
        xor     a
        ld      (s6_rc),a
        call    s6_fill                 ; white page
        ld      a,C_BLACK
        ld      (b_c),a
        call    pp_box                  ; frame
        xor     a
        ld      (u_i),a
pp_l:   ld      hl,dp_n
        ld      a,(u_i)
        cp      (hl)
        ret     nc
        call    pp_row
        ld      hl,u_i
        inc     (hl)
        jr      pp_l

; one entry: u_i = index
pp_row: ld      a,(u_i)                 ; y = pg_y + 1 + 12 i
        ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,de
        add     hl,hl
        add     hl,hl
        ld      de,(pg_y)
        add     hl,de
        inc     hl
        ld      (s6_ry),hl
        ld      a,l
        ld      (u_ty),a
        ld      a,(dp_sel)
        ld      c,a
        ld      a,(u_i)
        cp      c
        ld      a,C_WHITE
        ld      b,C_BLACK
        jr      nz,pr_a
        ld      a,C_BLUE
        ld      b,C_WHITE
pr_a:   ld      (u_bg),a
        ld      (s6_rc),a
        ld      a,b
        ld      (u_fg),a
        ld      hl,(pg_x)               ; the row bar inside the frame
        inc     hl
        ld      (s6_rx),hl
        ld      hl,(pg_w)
        dec     hl
        dec     hl
        ld      (s6_rw),hl
        ld      hl,PRH
        ld      (s6_rh),hl
        call    s6_fill
        ld      a,(u_i)                 ; HL = the name of the entry (24 * i into dp_nm), E = its id
        ld      e,a
        ld      d,0
        ld      hl,dp_id
        add     hl,de
        ld      a,(hl)
        ld      (u_ext),a
        ld      l,e
        ld      h,0
        add     hl,hl
        add     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,dp_nm
        add     hl,de
IF S6SET
ELSE
        ld      a,(u_ext)               ; a drive: "C:" or "USBn name"
        bit     7,a
        jr      nz,pr_u
        add     a,'A'
        ld      de,BR_STR
        ld      (de),a
        inc     de
        ld      a,':'
        ld      (de),a
        inc     de
        jr      pr_z
pr_u:   and     7Fh
        add     a,'0'
        push    af
        ld      a,(hl)                  ; the cartridge's name starts with "Drive n ": left out
        cp      'D'
        jr      nz,pr_n
        ld      de,8
        add     hl,de
pr_n:   ex      de,hl                   ; DE = the name
        ld      hl,BR_STR
        ld      (hl),'U'
        inc     hl
        ld      (hl),'S'
        inc     hl
        ld      (hl),'B'
        inc     hl
        pop     af
        ld      (hl),a
        inc     hl
        ld      (hl),' '
        inc     hl
        ex      de,hl                   ; HL = the name, DE = behind "USBn "
        ld      b,24
pr_c:   ld      a,(hl)
        or      a
        jr      z,pr_z
        ld      (de),a
        inc     hl
        inc     de
        djnz    pr_c
pr_z:   xor     a
        ld      (de),a
        ld      hl,BR_STR
ENDIF
pr_set: push    hl                      ; HL = the text of the row
        call    pr_tv
        ld      hl,(pg_w)               ; the drive popup is narrow: the name may use 100 pixels, a setting's value 150
        ld      de,-12
        add     hl,de
        ld      (s6_lim),hl
        ld      hl,(pg_x)
        ld      de,5
        add     hl,de
        ld      (s6_tx),hl
        pop     hl
        call    s6_u8
IF S6SET
        ld      a,(u_ext)
        bit     6,a
        ret     z
        call    pr_tv
        ld      a,(u_bg)
        cp      C_BLUE
        ld      a,C_BLUE
        jr      nz,pr_f
        ld      a,C_WHITE
pr_f:   ld      (s6_fg),a
        ld      a,1
        ld      (s6_al),a
        ld      hl,(pg_x)
        ld      de,(pg_w)
        add     hl,de
        ld      de,-5
        add     hl,de
        ld      (s6_tx),hl
        ld      hl,pr_now
        jp      lb_draw
pr_now: defb    "NOW",0,"현재",0
ENDIF
        ret
; the text colours of the current row
pr_tv:  ld      a,(u_ty)
        inc     a
        ld      (s6_ty),a
        ld      a,(u_fg)
        ld      (s6_fg),a
        ld      a,(u_bg)
        ld      (s6_bg),a
        xor     a
        ld      (s6_al),a
        ld      hl,100
        ld      (s6_lim),hl
        ret

IF S6SET
; ======================= the settings page =======================
; set_sel = the item (0 MP4 SCREEN, 1 AT END, 2 SHOW FPS; V1.11.27: ASPECT is gone), vsc / rep / show_fps = the values (browser.inc owns the keys)
s6_set: call    s6_init
        call    s6_probe
        call    s6_title
        call    s6_l
        defw    48
        defb    2,C_WHITE,C_BLUE
        defb    "SETUP",0,"설정",0
        call    s6_lr
        defw    506
        defb    2,C_WHITE,C_BLUE
        defb    "ESC BACK",0,"ESC 돌아가기",0
        call    s6_l                    ; the two groups
        defw    12
        defb    22,C_BLUE,C_WHITE
        defb    "VIDEO",0,"영상",0
        call    s6_rect
        defw    12,33,488,1
        defb    C_BLUE
        call    s6_l
        defw    12
        defb    60,C_BLUE,C_WHITE
        defb    "PLAY",0,"재생",0
        call    s6_rect
        defw    12,71,488,1
        defb    C_BLUE
        xor     a
        ld      (u_i),a
ss_l:   call    ss_item
        ld      hl,u_i
        inc     (hl)
        ld      a,(hl)
        cp      3
        jr      c,ss_l
        call    s6_mach                 ; the box about this machine
        call    ss_help
        call    s6_hbar
        call    kd
        defw    6
        defb    200
        defb    "UP/DN",0,"↑↓",0,"MOVE",0,"이동",0
        call    kd
        defw    80
        defb    200
        defb    "ENTER",0,"ENTER",0,"SET",0,"고르기",0
        call    kd
        defw    186
        defb    200
        defb    "ESC",0,"ESC",0,"BACK",0,"돌아가기",0
        ret

; the line of help of the item set_sel (row 185)
ss_help:call    s6_ibar
        ld      a,C_BLACK
        ld      (s6_fg),a
        xor     a
        ld      (s6_bg),a
        ld      a,185
        ld      (s6_ty),a
        ld      hl,6
        ld      (s6_tx),hl
        ld      hl,500
        ld      (s6_lim),hl
        ld      a,(set_sel)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,ss_hlp
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        jp      lb_draw

; V1.11.27: the rows set_old and set_sel again (a selection moved or a value changed) and the help line: 50 ms a row instead of 420 ms for the page
s6_supd:ld      a,(set_old)
        ld      (u_i),a
        call    ss_item
        ld      a,(set_sel)
        ld      hl,set_old
        cp      (hl)
        ret     z                       ; the same item: its value changed, the help line stays
        ld      (u_i),a
        call    ss_item
        jp      ss_help
; the rectangle under the popup of the item set_sel: x 148, w 204, y = the row + 15, h = 12 n + 2 -> pc_y, pc_h
pc_rect:ld      a,(set_sel)
        ld      e,a
        ld      d,0
        ld      hl,ss_y
        add     hl,de
        ld      a,(hl)
        add     a,15
        ld      (pc_y),a
        ld      a,(dp_n)
        ld      e,a
        add     a,a
        add     a,e
        add     a,a
        add     a,a
        add     a,2
        ld      (pc_h),a
        ret
s6_psave:                               ; page 0 -> page 1 (the same place, 256 lines lower)
        call    pc_rect
        ld      a,(pc_y)
        ld      l,a
        ld      e,a
        ld      h,0
        ld      d,1
        jr      pc_go
s6_prest:                               ; and back (the popup is gone)
        call    pc_rect
        ld      a,(pc_y)
        ld      l,a
        ld      e,a
        ld      h,1
        ld      d,0
pc_go:  ld      (pcb+2),hl              ; SY
        ld      (pcb+6),de              ; DY
        ld      hl,148
        ld      (pcb),hl                ; SX
        ld      (pcb+4),hl              ; DX
        ld      hl,204
        ld      (pcb+8),hl              ; NX
        ld      a,(pc_h)
        ld      (pcb+10),a              ; NY
        xor     a
        ld      (pcb+11),a
        ld      (pcb+12),a              ; colour (unused by HMMM)
        ld      (pcb+13),a              ; direction bits: VRAM to VRAM, left to right, top down
        ld      a,0D0h
        ld      (pcb+14),a              ; HMMM
        call    s6_vwait
        di
        ld      a,32
        out     (99h),a
        ld      a,91h
        out     (99h),a                 ; R#17 = 32, auto increment: the 15 bytes go to R#32..46
        ld      hl,pcb
        ld      bc,0F9Bh
        otir
        ei
        jp      s6_vwait

; item u_i: the row (blue when selected), its name, the value button with the value and the arrow
ss_item:ld      a,(u_i)
        ld      e,a
        ld      d,0
        ld      hl,ss_y
        add     hl,de
        ld      a,(hl)
        ld      (u_ty),a                ; y of the row
        ld      l,a
        ld      h,0
        ld      (s6_ry),hl
        ld      a,(set_sel)
        ld      hl,u_i
        cp      (hl)
        ld      a,C_WHITE
        ld      b,C_BLACK
        jr      nz,si_n
        ld      a,C_BLUE
        ld      b,C_WHITE
si_n:   ld      (u_bg),a
        ld      (s6_rc),a
        ld      a,b
        ld      (u_fg),a
        ld      hl,0
        ld      (s6_rx),hl
        ld      hl,512
        ld      (s6_rw),hl
        ld      hl,18
        ld      (s6_rh),hl
        call    s6_fill                 ; the row
        ld      a,(u_ty)                ; its name (x 12)
        add     a,4
        ld      (s6_ty),a
        ld      a,(u_fg)
        ld      (s6_fg),a
        ld      a,(u_bg)
        ld      (s6_bg),a
        ld      hl,12
        ld      (s6_tx),hl
        ld      hl,130
        ld      (s6_lim),hl
        xor     a
        ld      (s6_al),a
        ld      a,(u_i)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,ss_lab
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        call    lb_draw
        ld      hl,150                  ; the button (x 150, 2 below the row, 200 x 14)
        ld      (b_x),hl
        ld      a,(u_ty)
        add     a,2
        ld      l,a
        ld      h,0
        ld      (b_y),hl
        ld      hl,200
        ld      (b_w),hl
        ld      hl,14
        ld      (b_h),hl
        call    s6_btnw
        ld      de,337
        ld      a,(u_ty)
        add     a,7
        call    s6_arrow
        ld      a,(u_i)                 ; the value: the name of the current choice
        or      a
        jr      nz,sv_1
        ld      a,(vsc)                 ; names of 10 bytes
        ld      c,a
        add     a,a
        add     a,a
        add     a,c
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,s_vsc
        add     hl,bc
        jr      sv_v
sv_1:   cp      1
        jr      nz,sv_3
        ld      a,(rep)
        add     a,a
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,s_rep
        add     hl,bc
        jr      sv_v
sv_3:   ld      a,(show_fps)
        or      a
        ld      hl,s_off
        jr      z,sv_v
        ld      hl,s_on
sv_v:   push    hl
        ld      a,(u_ty)
        add     a,4
        ld      (s6_ty),a
        ld      a,C_BLACK
        ld      (s6_fg),a
        xor     a
        ld      (s6_bg),a
        ld      hl,155
        ld      (s6_tx),hl
        ld      hl,170
        ld      (s6_lim),hl
        pop     hl
        jp      s6_u8

; does the VRAM have 128 KB?  (write 55h at 10000h, 00h at 0: it reads 55h back only when address bit 16 exists) -> mc_v
s6_probe:
        call    s6_vwait
        di
        ld      a,4
        out     (99h),a
        ld      a,8Eh
        out     (99h),a                 ; R#14 = 4: A16
        xor     a
        out     (99h),a
        ld      a,40h
        out     (99h),a
        ld      a,55h
        out     (98h),a
        xor     a
        out     (99h),a
        ld      a,8Eh
        out     (99h),a                 ; R#14 = 0
        xor     a
        out     (99h),a
        ld      a,40h
        out     (99h),a
        xor     a
        out     (98h),a
        ld      a,4
        out     (99h),a
        ld      a,8Eh
        out     (99h),a
        xor     a
        out     (99h),a
        out     (99h),a                 ; read address 0 of bank 1
        in      a,(98h)
        ld      b,a
        xor     a
        out     (99h),a
        ld      a,8Eh
        out     (99h),a                 ; R#14 = 0
        ei
        ld      a,b
        sub     55h
        sub     1
        sbc     a,a
        and     1
        ld      (mc_v),a                ; 1 = 128 KB
        ret

; the box about this machine (x 12, y 150, 488 x 28): "THIS MACHINE V9958 (MSX2+), VRAM 128KB" / "Gfx9000 found ..."
s6_mach:call    s6_rect
        defw    12,150,488,28
        defb    C_WHITE
        ld      hl,12
        ld      (b_x),hl
        ld      hl,150
        ld      (b_y),hl
        ld      hl,488
        ld      (b_w),hl
        ld      hl,28
        ld      (b_h),hl
        ld      a,C_BLACK
        ld      (b_c),a
        call    pp_box
        ld      de,BR_STR
        ld      hl,mc_t1
        call    cp_lang
        ld      a,(vdplv)
        ld      hl,mc_9938
        cp      2
        jr      c,mc_a
        ld      hl,mc_9958
mc_a:   call    cp_str
        ld      a,(gen)                 ; 1 MSX2, 2 MSX2+, 3 turbo R: 12 bytes each
        dec     a
        and     3
        ld      c,a
        add     a,a
        add     a,c
        add     a,a
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,mc_gen
        add     hl,bc
        call    cp_str
        ld      hl,mc_t2
        call    cp_lang
        ld      hl,mc_t3
        call    cp_str
        ld      hl,mc_128
        ld      a,(mc_v)
        or      a
        jr      nz,mc_b
        ld      hl,mc_64
mc_b:   call    cp_str
        xor     a
        ld      (de),a
        ld      a,C_BLACK
        ld      (s6_fg),a
        xor     a
        ld      (s6_bg),a
        ld      (s6_al),a
        ld      hl,18
        ld      (s6_tx),hl
        ld      hl,476
        ld      (s6_lim),hl
        ld      a,151
        ld      (s6_ty),a
        ld      hl,BR_STR
        call    s6_u8
        ld      hl,mc_g1                ; line 2: with a Gfx9000 (IDENT bit 6 of the cartridge) V9 FAST and V9 SHARP can be used
        ld      a,(VC_CAPS)
        and     40h
        jr      nz,mc_c
        ld      hl,mc_g0
mc_c:   ld      a,C_BLACK
        ld      (s6_fg),a
        xor     a
        ld      (s6_bg),a
        ld      (s6_al),a
        ld      de,18
        ld      (s6_tx),de
        ld      de,476
        ld      (s6_lim),de
        ld      a,163
        ld      (s6_ty),a
        jp      lb_draw
; DE = the language form of the pair at HL -> (DE) (no 0 behind); HL = behind the pair
cp_lang:call    sk_str                  ; V1.11.26: always the Korean form (the cartridge or the built-in dot font draws it)
cp_str: ld      a,(hl)
        inc     hl
        or      a
        ret     z
        ld      (de),a
        inc     de
        jr      cp_str
sk_str: ld      a,(hl)
        inc     hl
        or      a
        jr      nz,sk_str
        ret
mc_t1:  defb    "THIS MACHINE ",0,"이 기종 ",0
mc_9938:defb    "V9938",0
mc_9958:defb    "V9958",0
mc_gen: defb    " (MSX2)",0,0,0,0,0
        defb    " (MSX2+)",0,0,0,0
        defb    " (turbo R)",0,0
mc_t2:  defb    ", ",0,", ",0
mc_t3:  defb    " VRAM ",0
mc_128: defb    "128KB",0
mc_64:  defb    "64KB",0
mc_g1:  defb    "Gfx9000 found, V9 FAST and V9 SHARP can be used",0,"Gfx9000 있음, V9 FAST, V9 SHARP",0
mc_g0:  defb    "No Gfx9000",0,"Gfx9000 없음",0

; the labels of the items and the help line of each
ss_lab: defw    ss_l0,ss_l2,ss_l3
ss_l0:  defb    "MP4 SCREEN",0,"MP4 화면",0
ss_l2:  defb    "AT END",0,"끝나면",0
ss_l3:  defb    "SHOW FPS",0,"FPS 표시",0
ss_hlp: defw    ss_h0,ss_h2,ss_h3
ss_h0:  defb    "The SCREEN an MP4 is shown on (only what this machine can do).",0,"MP4 영상 화면 고르기",0
ss_h2:  defb    "What happens when a movie ends.",0,"영상이 끝나면",0
ss_h3:  defb    "Show the frames per second while playing.",0,"FPS 표시 고르기",0

ENDIF

IF S6SET
        include "hf_st.inc"
ELSE
        include "hf_ui.inc"
ENDIF
        defs    5000h+0FFEh-$ ;SIZECHK
        defw    BSTAMP
