; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  File browser (X86MV without a file name), settings panel, repeat, FPS counter
;  Text = Galmuri7 6x8 (same typeface as X86VIEW), drawn by gtext into BUF and sent with showframe.
;  List entries (16 bytes) at BR_ENT:  [0] type (0 = parent "..", 1 = folder, 2 = MV file), [1..13] name (ASCIIZ)
; ============================================================
BR_ENT  equ     6000h
VC_P4   equ     700Eh           ; vc.asm dp_col: the SCREEN (P4) of the last OPEN
VC_CAPS equ     718Eh           ; the vc.asm module's IDENT capabilities byte (DPS + 18Eh)
BR_MAX  equ     250
BR_FIB  equ     7F00h           ; 64 byte FIB of _FFIRST / _FNEXT
BR_TMP  equ     7F40h           ; record being inserted
BR_DIR  equ     7F50h           ; _GETCD result (64 bytes)
BR_STR  equ     7F90h           ; text scratch (48 bytes)
BR_ROWS equ     11              ; V1.11.25: entries per screen (12 pixel rows from y = 48, see X86MVUI.OVL)

; ---- directory scan -------------------------------------------------
br_scan:
        ld      a,(br_host)
        or      a
        jp      nz,VC_LIST      ; inside the X86 Video library: the cartridge lists the host folder
        ld      hl,0
        ld      (br_cnt),hl
        ld      (br_sel),hl
        ld      (br_top),hl
        ld      a,(br_depth)
        or      a
        jr      z,bs_f
        ld      hl,rec_up               ; below the root: first entry is ".."
        ld      de,BR_ENT
        ld      bc,16
        ldir
        ld      hl,1
        ld      (br_cnt),hl
bs_f:   ld      a,(br_depth)
        or      a
        call    z,VC_ADDHOST    ; root: the "X86 VIDEO" folder (only with the cartridge)
        ld      de,s_star
        ld      b,10h                   ; files and folders
        ld      ix,BR_FIB
        ld      c,40h                   ; _FFIRST
        call    BDOS
        or      a
        ret     nz
bs_l:   call    br_add
        ld      ix,BR_FIB
        ld      c,41h                   ; _FNEXT
        call    BDOS
        or      a
        jr      z,bs_l
        ret

; FIB -> list entry (folders, and files whose extension starts with "MV")
br_add: ld      hl,(br_cnt)
        ld      de,BR_MAX
        or      a
        sbc     hl,de
        ret     nc
        ld      a,(BR_FIB+1)
        cp      '.'
        ret     z                       ; "." and ".." (the parent entry is made by br_scan)
        ld      a,(BR_FIB+14)
        and     08h
        ret     nz                      ; volume label
        ld      a,(BR_FIB+14)
        and     10h
        jr      z,ba_f
        ld      a,1
        jr      ba_k
ba_f:   call    br_ismv
        ret     c
        ld      a,2
ba_k:   ld      hl,BR_TMP
        ld      (hl),a
        inc     hl
        ex      de,hl
        ld      hl,BR_FIB+1
        ld      bc,13
        ldir
        ld      a,(BR_FIB+22)           ; [14..15] = size in 4 KB units (65535 = 256 MB or more)
        rrca
        rrca
        rrca
        rrca
        and     0Fh
        ld      c,a
        ld      hl,(BR_FIB+23)
        ld      a,h
        cp      10h
        jr      c,ba_s
        ld      hl,0FFFFh
        jr      ba_w
ba_s:   add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      a,l
        or      c
        ld      l,a
ba_w:   ex      de,hl
        ld      (hl),e
        inc     hl
        ld      (hl),d
        jp      br_ins

; carry = the FIB name is not a file this player lists: .MV? (played here), .MP4 .M4V .MOV .AVI (played by the X86 Multimedia cartridge)
br_ismv:ld      a,(br_all)
        or      a
        ret     nz                      ; A key: every file is listed
        ld      hl,BR_FIB+1
        call    ext_cls
        or      a
        jr      z,bm_no
        or      a
        ret
bm_no:  scf
        ret
; HL = a file name -> A = 0 other, 1 = .MV? (the movie formats of this player), 2 = .MP4 .M4V .MOV .AVI (a video container: the cartridge plays it)
ext_cls:ld      a,(hl)
        or      a
        jr      z,ec_n
        inc     hl
        cp      '.'
        jr      nz,ext_cls
        ld      a,(hl)
        or      20h
        ld      b,a                     ; 1st letter (lower case)
        inc     hl
        ld      a,(hl)
        or      20h
        ld      c,a                     ; 2nd
        jr      z,ec_n
        inc     hl
        ld      a,(hl)
        or      20h
        ld      d,a                     ; 3rd (digits are unchanged by the OR)
        ld      a,b
        cp      'm'
        jr      nz,ec_a
        ld      a,c
        cp      'v'
        jr      z,ec_1                  ; .MV?
        cp      'p'
        jr      nz,ec_m
        ld      a,d
        cp      '4'
        jr      z,ec_2                  ; .MP4
        jr      ec_n
ec_m:   ld      a,d
        cp      'v'
        jr      nz,ec_n
        ld      a,c
        cp      '4'
        jr      z,ec_2                  ; .M4V
        cp      'o'
        jr      z,ec_2                  ; .MOV
        jr      ec_n
ec_a:   cp      'a'
        jr      nz,ec_n
        ld      a,c
        cp      'v'
        jr      nz,ec_n
        ld      a,d
        cp      'i'
        jr      z,ec_2                  ; .AVI
ec_n:   xor     a
        ret
ec_1:   ld      a,1
        ret
ec_2:   ld      a,2
        ret

; HL = index -> HL = record address
br_entaddr:
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,BR_ENT
        add     hl,de
        ret

; HL = record A, DE = record B -> carry if A < B (type, then name)
br_cmp: ld      a,(de)
        ld      b,a
        ld      a,(hl)
        cp      b
        ret     nz
        inc     hl
        inc     de
        ld      c,13
bc1:    ld      a,(de)
        ld      b,a
        ld      a,(hl)
        cp      b
        ret     nz
        or      a
        ret     z
        inc     hl
        inc     de
        dec     c
        jr      nz,bc1
        or      a
        ret

; insert BR_TMP into the list in sorted order
br_ins: ld      hl,(br_cnt)             ; HL = candidate position
bi_l:   ld      a,h
        or      l
        jr      z,bi_at
        dec     hl
        push    hl
        call    br_entaddr
        ex      de,hl
        ld      hl,BR_TMP
        call    br_cmp
        pop     hl
        jr      c,bi_l                  ; new < entry[HL]: go further up
        inc     hl
bi_at:  push    hl                      ; position
        ld      de,(br_cnt)
        ex      de,hl
        or      a
        sbc     hl,de                   ; HL = entries to move up
        jr      z,bi_cp
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      b,h
        ld      c,l
        ld      hl,(br_cnt)
        call    br_entaddr
        dec     hl                      ; last byte of the last entry
        push    hl
        ld      de,16
        add     hl,de
        ex      de,hl
        pop     hl
        lddr
bi_cp:  pop     hl
        call    br_entaddr
        ex      de,hl
        ld      hl,BR_TMP
        ld      bc,16
        ldir
        ld      hl,(br_cnt)
        inc     hl
        ld      (br_cnt),hl
        ret

; ---- text helpers ---------------------------------------------------
; rtext: HL = string, D = y : right aligned at x = 250
rtext:  push    hl
        call    strw
        ld      c,a
        ld      a,250
        sub     c
        ld      e,a
        pop     hl
        jp      gtext

; utoa: HL = value (< 1000), DE = destination -> digits written without leading zeros, DE after the last
utoa:   xor     a
        ld      (ua_f),a
        ld      bc,100
        call    ua_d
        ld      bc,10
        call    ua_d
        ld      a,l
        add     a,'0'
        ld      (de),a
        inc     de
        ret
ua_d:   xor     a
ua_l:   or      a
        sbc     hl,bc
        jr      c,ua_e
        inc     a
        jr      ua_l
ua_e:   add     hl,bc
        ld      b,a
        ld      a,(ua_f)
        or      b
        ret     z
        ld      a,1
        ld      (ua_f),a
        ld      a,b
        add     a,'0'
        ld      (de),a
        inc     de
        ret

; fillk: D = cell row, E = first cell column, B = number of cells, A = color byte
fillk:  ld      c,a
        push    bc
        call    cellptr
        pop     bc
        ld      de,1800h
        add     hl,de
fk_l:   ld      (hl),c                  ; one cell = 8 bytes, unrolled
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),c
        inc     hl
        djnz    fk_l
        ret

; fw256: HL = start (page aligned), DE = fill word -> 256 bytes filled with PUSH (about 4 times faster than LDIR)
fw256:  di
        ld      (fw_sp),sp
        inc     h
        ld      sp,hl
        ld      b,16
fw_l:   push    de
        push    de
        push    de
        push    de
        push    de
        push    de
        push    de
        push    de
        djnz    fw_l
        ld      sp,(fw_sp)
        ei
        ret

; ---- colors (palette entries 1..15, R<<4|B, G): the design's navy / pink / yellow / grey on a black page ----
;  1 white  2 navy  3 mid navy  4 light grey  5 pink  6 yellow  7 blue  8 grey ; a cell color byte = fg<<4 | bg
bpal:   defb    077h,07h, 012h,01h, 023h,02h, 056h,05h, 073h,02h, 072h,06h, 027h,05h, 034h,03h
        defb    012h,06h, 077h,07h, 077h,07h, 077h,07h, 077h,07h, 077h,07h, 077h,07h

; clear BUF (black page), set the palette
br_clear:
        ld      hl,BUF
        ld      de,0
        ld      c,24
bc_p:   push    hl
        push    bc
        call    fw256
        pop     bc
        pop     hl
        inc     h
        dec     c
        jr      nz,bc_p
        ld      hl,BUF+1800h
        ld      de,1010h
        ld      c,24
bc_c:   push    hl
        push    bc
        call    fw256
        pop     bc
        pop     hl
        inc     h
        dec     c
        jr      nz,bc_c
        ld      hl,bpal
        ld      de,BUF+PALOFS
        ld      bc,30
        ldir
        ret

; footer bar (rows 22-23 navy) with the key hints: A = hint set (0 browser, 1 settings)
br_hints:
        push    af
        ld      de,1600h
        ld      b,64
        ld      a,42h                   ; light grey on navy
        call    fillk
        ld      hl,s_k_ret
        ld      de,0B804h               ; y 184, x 4
        call    gtext
        ld      hl,s_k_esc
        ld      de,0B848h               ; x 72
        call    gtext
        ld      de,1700h                ; "RET" cells (row 23, cols 0-2)
        ld      b,3
        ld      a,62h                   ; yellow on navy
        call    fillk
        ld      de,1709h                ; "ESC" cells (cols 9-11)
        ld      b,3
        ld      a,62h
        call    fillk
        pop     af
        or      a
        jr      nz,bh_s
        ld      hl,s_k_play
        ld      de,0B818h               ; ":PLAY" x 24
        call    gtext
        ld      hl,s_k_quit
        ld      de,0B860h               ; ":QUIT" x 96
        call    gtext
        ld      hl,s_k_bs
        ld      de,0B890h               ; "BS:UP" x 144
        call    gtext
        ld      de,1712h                ; "BS" cells (cols 18-19)
        ld      b,2
        ld      a,62h
        jp      fillk
bh_s:   ld      hl,s_k_chg
        ld      de,0B818h
        call    gtext
        ld      hl,s_k_back
        ld      de,0B860h
        jp      gtext

; the list is drawn by the SCREEN 6 module X86MVUI.OVL at 5000h (loaded by ui_prep)
br_show:jp      5000h                   ; draw the page and send it
br_upd: jp      5003h                   ; the selection moved: redraw what changed

; keep the selection inside the window
br_fit: ld      hl,(br_sel)
        ld      de,(br_top)
        or      a
        sbc     hl,de
        jr      nc,bf_1
        ld      hl,(br_sel)
        ld      (br_top),hl
        ret
bf_1:   ld      de,BR_ROWS
        or      a
        sbc     hl,de
        ret     c
        ld      hl,(br_sel)
        ld      de,BR_ROWS-1
        or      a
        sbc     hl,de
        ld      (br_top),hl
        ret

; USB mode: path line "USBn:\folder" into BR_STR (the folder names of the first 4 levels are in the drive's memory record, see vc.asm)
br_upath:
        ld      de,BR_STR
        ld      hl,s_usb
        ld      bc,3
        ldir
        ld      a,(VU_CUR)
        add     a,'0'
        ld      (de),a
        inc     de
        ld      a,':'
        ld      (de),a
        inc     de
        ld      a,(VU_CUR)
        dec     a
        cp      8
        jr      nc,bu_e                 ; no record for that drive number
        ld      hl,UM_REC+15            ; folder names of drive 1
        ld      bc,80
        or      a
bu_m:   jr      z,bu_n
        add     hl,bc
        dec     a
        jr      bu_m
bu_n:   ld      a,(VU_DEP)
        sub     2
        jr      c,bu_e
        cp      4
        jr      nc,bu_e
        ld      bc,13
bu_k:   or      a
        jr      z,bu_c
        add     hl,bc
        dec     a
        jr      bu_k
bu_c:   ld      a,5Ch
        ld      (de),a
        inc     de
        ldir
bu_e:   xor     a
        ld      (de),a
        ret
s_usb:  defb    "USB"

; ---- browser main loop ----------------------------------------------
br_start:
        call    vdp_init
        xor     a
        ld      (br_depth),a
        ld      (kprev8),a
        ld      (kprev4),a
        call    br_scan
br_again:
        ld      sp,(sp0)
        ei
        call    ui_prep                 ; the SCREEN 6 module at 5000h (after an MV8 play it is read again), 
        call    br_show
        call    wait_rel
br_loop:halt
        call    se_s                    ; S: the settings page (MP4 SCREEN, SHOW FPS, REPEAT)
        or      a
        jp      nz,br_settings
        call    VC_KEYD                 ; D: the drive popup
        or      a
        jp      nz,VC_POP
        call    br_poll                 ; D = new presses row 8 (+ repeat), E = new presses row 7
        ld      a,d
        or      e
        jp      z,br_loop
        bit     2,e
        jp      nz,quit                 ; ESC
        bit     7,e
        jp      nz,br_ret               ; RET
        bit     5,e
        jp      nz,br_up                ; BS
        bit     4,d
        jp      nz,br_up                ; LEFT
        bit     1,d
        jp      nz,br_home
        bit     5,d
        jp      nz,br_k_up
        bit     6,d
        jp      nz,br_k_dn
        jp      br_loop
; the list filter of the cartridge (USB): mv2 = 2, caps bit 3 = video 8, caps bit 4 = MV5..MVC 16; the A key adds the other kinds (1 sound, 4 the rest)
br_filt:ld      a,(VC_CAPS)             ; the MV2 files always come (2, or inside the video filter 8); MV5..MVC (16) only with caps bit 4
        and     18h
        bit     3,a
        jr      nz,bf_a
        or      2
bf_a:   ld      b,a
        ld      a,(br_all)
        or      a
        ld      a,b
        ret     z
        or      7
        ret
br_settings:
        xor     a
        ld      (ui_ok),a               ; 5000h is overwritten: the list look is read again when the list comes back
        ld      hl,s_st
        call    mod_load                ; V1.11.25: the settings page and its popups are the module X86MVST.OVL (Z = loaded)
        jr      z,bst_ok
        call    m8_msg                  ; "<folder>X86MVST.OVL not found" / "is from another version" on the list's info line
        ld      (br_note),de
        jp      br_again
bst_ok: ld      a,1
        ld      (set_ui),a              ; the SCREEN 6 look draws the page (+9)
        ld      (set_was),a             ; no movie to resume
        ld      hl,0FFFFh
        ld      (cur),hl                ; no frame to redraw when the page closes
        xor     a
        ld      (set_sel),a
        call    set_page
        call    wait_rel
        call    se_lp
        xor     a
        ld      (set_ui),a
        ld      (ui_ok),a               ; the list module comes back (br_again reads it)
        jp      br_again
br_k_up:ld      hl,(br_sel)
        ld      a,h
        or      l
        jp      z,br_loop
        dec     hl
        jp      br_mv
br_k_dn:ld      hl,(br_sel)
        inc     hl
        ld      de,(br_cnt)
        push    hl
        or      a
        sbc     hl,de
        pop     hl
        jp      nc,br_loop
        jp      br_mv
br_home:ld      hl,0
br_mv:  ex      de,hl                   ; DE = new selection: remember the old state, then redraw only what changed
        ld      hl,(br_sel)
        ld      (br_osel),hl
        ld      hl,(br_top)
        ld      (br_otop),hl
        ld      (br_sel),de
        call    br_fit
        call    br_upd
        jp      br_loop
br_ret: ld      hl,(br_cnt)
        ld      a,h
        or      l
        jp      z,br_loop
        ld      hl,(br_sel)
        call    br_entaddr
        ld      a,(br_host)
        or      a
        jp      nz,VC_RET       ; library entry (HL = record)
        ld      a,(hl)
        or      a
        jp      z,br_up                 ; ".."
        inc     hl
        cp      2
        jp      z,br_play
        push    hl                      ; the "X86 VIDEO" folder carries FFFFh, the "USB" folder FFFEh in its spare bytes
        ld      de,13
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      d,(hl)
        inc     d
        pop     hl
        jp      z,VC_ENTER              ; A = the low byte of the marker
        ex      de,hl                   ; folder: go in
        ld      c,5Ah                   ; _CHDIR
        call    BDOS
        or      a
        jp      nz,br_loop
        ld      hl,br_depth
        inc     (hl)
        call    br_scan
        jp      br_again
br_up:  ld      a,(br_host)
        or      a
        jp      nz,VC_UP
        ld      a,(br_depth)
        or      a
        jp      z,VC_POP                ; BS at the top of a drive: the drive popup
        dec     a
        ld      (br_depth),a
        call    br_getprev              ; remember the name of the folder we are leaving
        ld      de,s_dotdot
        ld      c,5Ah
        call    BDOS
        call    br_scan
        call    br_findprev             ; ... and select it in the list of the parent
        jp      br_again

; br_prev = last component of the current directory (the folder we are about to leave)
br_getprev:
        ld      b,0
        ld      de,BR_DIR
        ld      c,59h                   ; _GETCD
        call    BDOS
        ld      hl,BR_DIR
        ld      d,h
        ld      e,l                     ; DE = start of the last component
gp_l:   ld      a,(hl)
        or      a
        jr      z,gp_c
        inc     hl
        cp      '\'
        jr      nz,gp_l
        ld      d,h
        ld      e,l
        jr      gp_l
gp_c:   ld      h,d
        ld      l,e
        ld      de,br_prev
        ld      b,12
gp_k:   ld      a,(hl)
        ld      (de),a
        or      a
        ret     z
        inc     hl
        inc     de
        djnz    gp_k
        xor     a
        ld      (de),a
        ret

; select the folder named br_prev in the list (window: it stays in the middle when the list is longer than a screen)
br_findprev:
        ld      hl,(br_cnt)
        ld      a,h
        or      l
        ret     z
        ld      bc,0                    ; BC = entry index
fp_l:   push    bc
        ld      h,b
        ld      l,c
        call    br_entaddr
        ld      a,(hl)
        or      a
        jr      z,fp_n                  ; not the ".." entry (folders and files)
        inc     hl
        ld      de,br_prev
fp_c:   ld      a,(de)
        and     0DFh                    ; names compare without case
        ld      b,a
        ld      a,(hl)
        and     0DFh
        cp      b
        jr      nz,fp_n
        ld      a,(de)
        or      a
        jr      z,fp_hit
        inc     hl
        inc     de
        jr      fp_c
fp_n:   pop     bc
        inc     bc
        ld      hl,(br_cnt)
        or      a
        sbc     hl,bc
        jr      nz,fp_l
        ret
fp_hit: pop     bc
        ld      (br_sel),bc
        ld      hl,(br_cnt)
        ld      de,BR_ROWS
        or      a
        sbc     hl,de                   ; HL = count - rows = last top
        jr      c,fp_t0                 ; fits on one screen
        push    hl
        ld      h,b
        ld      l,c
        ld      de,BR_ROWS/2
        or      a
        sbc     hl,de                   ; top = selection - half a screen
        jr      nc,fp_p
        ld      hl,0
fp_p:   pop     de
        push    hl
        or      a
        sbc     hl,de
        pop     hl
        jr      c,fp_s                  ; top < last top
        ex      de,hl                   ; top = last top
fp_s:   ld      (br_top),hl
        ret
fp_t0:  ld      hl,0
        ld      (br_top),hl
        ret
br_play:ld      (fname),hl
        jp      playfile

; keyboard for the browser: D = row 8 presses (UP/DOWN repeat), E = row 7 presses
br_poll:di
        in      a,(PPI_C)
        and     0F0h
        or      07h
        out     (PPI_C),a
        in      a,(PPI_A)
        cpl
        ld      e,a
        in      a,(PPI_C)
        and     0F0h
        or      08h
        out     (PPI_C),a
        in      a,(PPI_A)
        cpl
        ld      d,a
        ei
        ld      a,(kprev8)
        cpl
        and     d
        ld      c,a                     ; C = new row 8
        ld      a,d
        ld      (kprev8),a
        ld      a,(kprev4)
        cpl
        and     e
        ld      b,a                     ; B = new row 7
        ld      a,e
        ld      (kprev4),a
        ld      a,d
        and     60h
        jr      z,bp_0
        ld      a,(khold)
        inc     a
        ld      (khold),a
        cp      14
        jr      c,bp_x
        ld      a,13                    ; repeat at every poll (the next redraw starts as soon as the last one is done)
        ld      (khold),a
        ld      a,d
        and     60h
        or      c
        ld      c,a
        jr      bp_x
bp_0:   xor     a
        ld      (khold),a
bp_x:   ld      d,c
        ld      e,b
        ret

; wait until ESC, RET, SPACE and the cursor keys are released
wait_rel:
        di
        in      a,(PPI_C)
        and     0F0h
        or      07h
        out     (PPI_C),a
        in      a,(PPI_A)
        and     84h
        cp      84h
        jr      nz,wr_n
        in      a,(PPI_C)
        and     0F0h
        or      08h
        out     (PPI_C),a
        in      a,(PPI_A)
        and     0F1h
        cp      0F1h
        jr      nz,wr_n
        in      a,(PPI_C)
        and     0F0h
        or      05h
        out     (PPI_C),a
        in      a,(PPI_A)
        and     01h
        cp      01h
        jr      nz,wr_n
        ei
        xor     a
        ld      (kprev8),a
        ld      (kprev4),a
        ld      (kprev5),a
        ld      (khold),a
        ret
wr_n:   ei
        halt
        jr      wait_rel

; ---- end of a play (browser mode) -----------------------------------
; leave the player: stop sound, close the file
stop_play:
        call    cart_stop
        call    audio_stop
        ld      a,(handle)
        or      a
        ret     z
        ld      b,a
        xor     a
        ld      (handle),a
        ld      c,45h                   ; _CLOSE
        jp      BDOS

; the end of the movie was reached: repeat setting
ended:  ld      a,(rep)
        or      a
        jp      z,done
        cp      2
        jr      nz,en_one
        ld      a,(br_on)
        or      a
        jr      z,en_one
        call    br_nextfile
        jr      c,en_one
        ld      sp,(sp0)
        call    stop_play
        jp      playfile
en_one: ld      hl,0
        call    seek_to
        jp      mloop

; next MV file after the selected one (wraps).  carry = no other file
br_nextfile:
        ld      hl,(br_sel)
        ld      (bn_i),hl
bn_l:   inc     hl
        ld      de,(br_cnt)
        push    hl
        or      a
        sbc     hl,de
        pop     hl
        jr      c,bn_ok
        ld      hl,0
bn_ok:  ld      de,(bn_i)
        push    hl
        or      a
        sbc     hl,de
        pop     hl
        jr      z,bn_none
        push    hl
        call    br_entaddr
        ld      a,(hl)
        cp      2
        jr      z,bn_f
        pop     hl
        jr      bn_l
bn_f:   inc     hl
        ld      (fname),hl
        pop     hl
        ld      (br_sel),hl
        or      a
        ret
bn_none:scf
        ret

; ---- FPS counter ------------------------------------------------------
fps_draw:
        ld      a,(fps_v)
        ld      c,0
fd1:    cp      10
        jr      c,fd2
        sub     10
        inc     c
        jr      fd1
fd2:    add     a,'0'
        ld      (fps_s+1),a
        ld      a,c
        or      a
        ld      a,' '
        jr      z,fd3
        ld      a,c
        add     a,'0'
fd3:    ld      (fps_s),a
        ld      hl,fps_s
        ld      de,0888h                ; y 8, x 136
        jp      gtext

; count shown frames; once a second remember the number
fps_tick:
        ld      a,(fps_n)
        inc     a
        ld      (fps_n),a
        ld      hl,(JIFFY)
        ld      de,(fps_t)
        or      a
        sbc     hl,de
        ld      de,60
        or      a
        sbc     hl,de
        ret     c
        ld      a,(fps_n)
        ld      (fps_v),a
        xor     a
        ld      (fps_n),a
        ld      hl,(JIFFY)
        ld      (fps_t),hl
        ret

; ---- settings panel (key S while playing) -----------------------------
keys_s: ld      a,(vmode)
        or      a
        ret     nz              ; no settings page while the cartridge shows the picture
        call    se_s
        or      a
        ret     z
settings:
        ld      a,(paused)
        ld      (set_was),a
        or      a
        call    z,key_space             ; pause while the panel is open
        xor     a
        ld      (set_sel),a
        call    set_page
        call    wait_rel
se_lp:  halt
        call    br_poll                 ; D = row 8 presses, E = row 7 presses (same keys as the browser)
        call    se_s
        ld      c,a                     ; C = S pressed
        ld      a,d
        or      e
        or      c
        jr      z,se_lp
        bit     2,e
        jp      nz,se_x                 ; ESC
        bit     0,c
        jp      nz,se_x                 ; S
        bit     5,d
        jr      nz,se_up
        bit     6,d
        jr      nz,se_dn
        bit     4,d
        jr      nz,se_lf
        ld      b,1                     ; RET, SPACE or RIGHT: the list of values (V1.11.25: every item of the SCREEN 6 page is a pull-down; the page of a playing movie steps through the values)
        bit     7,e
        jr      nz,se_k
        bit     0,d
        jr      nz,se_k
        bit     7,d
        jr      nz,se_k
        jr      se_lp
se_k:   ld      a,(set_ui)
        or      a
        jr      z,se_ch
        jp      se_pop
se_lf:  ld      a,(set_ui)
        or      a
        jr      nz,se_lp                ; no stepping on the pull-down page
        ld      b,0FFh
        jr      se_ch
se_up:  ld      a,(set_sel)
        or      a
        jr      z,se_lp
        dec     a
        jr      se_sv
se_dn:  ld      a,(set_sel)
        cp      2                       ; V1.11.27: 3 items (ASPECT is gone): 0 MP4 SCREEN, 1 AT END, 2 SHOW FPS
        jr      nc,se_lp
        inc     a
se_sv:  ld      b,a
        ld      a,(set_sel)
        ld      (set_old),a             ; the item that was selected: only it and the new one are drawn again
        ld      a,b
        ld      (set_sel),a
        call    set_part
        jr      se_lp
se_ch:  ld      a,(set_sel)
        or      a
        jr      nz,se_c1
        ld      a,(vsc)                 ; MP4 SCREEN: only the SCREENs this machine can use (vmask), next / previous one
sc_n:   add     a,b
        cp      0FFh
        jr      nz,sc_a
        ld      a,8
sc_a:   cp      9
        jr      c,sc_b
        xor     a
sc_b:   ld      c,a
        cp      7
        jr      c,sc_m
        ld      a,(VC_CAPS)             ; V1.11.18: 7 = V9990 fast (13), 8 = V9990 sharp (14): only with a Gfx9000 (IDENT bit 6)
        and     40h
        ld      a,c
        jr      z,sc_n
        jr      sc_u
sc_m:   ld      e,a
        inc     e
        ld      a,(vmask)
sc_t:   rrca
        dec     e
        jr      nz,sc_t
        ld      a,c
        jr      nc,sc_n                 ; not usable here: go on
sc_u:   ld      (vsc),a
        jr      se_rd
se_c1:  cp      2
        jr      nz,se_c2
        ld      a,(show_fps)            ; SHOW FPS toggles
        xor     1
        ld      (show_fps),a
        jr      se_rd
se_c2:  cp      1
        jp      nz,se_lp
        ld      a,(rep)                 ; REPEAT OFF -> ONE -> ALL
        add     a,b
        cp      0FFh
        jr      nz,se_c3
        ld      a,2
se_c3:  cp      3
        jr      c,se_c4
        xor     a
se_c4:  ld      (rep),a
se_rd:  ld      a,(set_sel)             ; the value of this item changed: only its row is drawn again
        ld      (set_old),a
        call    set_part
        jp      se_lp
se_x:   call    redraw_frame            ; the movie frame (and its palette) back
        call    wait_rel
        ld      a,(set_was)
        or      a
        call    z,key_space             ; it was playing: resume
        ret
; S key edge for the panel: A bit 0 = new press
se_s:   di
        in      a,(PPI_C)
        and     0F0h
        or      05h
        out     (PPI_C),a
        in      a,(PPI_A)
        ei
        cpl
        and     01h
        ld      b,a
        ld      a,(kprev5)
        cpl
        and     b
        ld      c,a
        ld      a,b
        ld      (kprev5),a
        ld      a,c
        ret

; ---- V1.11.18: the SCREEN popup of the settings page: the SCREEN 6 module draws it with the drive popup's code (dp_cur = 0FFh = a SCREEN list) ----
DP_N    equ     7000h
DP_SEL  equ     7001h
DP_CUR  equ     7002h
DP_ID   equ     7010h                   ; 12 ids: the SCREEN index, + 40h on the one set now
DP_NM   equ     7020h                   ; 12 names x 24 bytes
se_pop: call    wait_rel
        call    sp_fill
        ld      a,0FFh
        ld      (DP_CUR),a
        call    5000h+0Fh               ; V1.11.27: keep the picture under the popup (copied to page 1) to give it back when the popup closes
sp_dr:  call    dp_hook
sp_lp:  halt
        call    br_poll                 ; D = row 8 presses, E = row 7
        ld      a,d
        or      e
        jr      z,sp_lp
        bit     7,e
        jr      nz,sp_ok                ; RET
        bit     0,d
        jr      nz,sp_ok                ; SPACE
        bit     2,e
        jr      nz,sp_x                 ; ESC
        bit     5,e
        jr      nz,sp_x                 ; BS
        bit     4,d
        jr      nz,sp_x                 ; LEFT
        bit     5,d
        jr      nz,sp_up
        bit     6,d
        jr      nz,sp_dn
        jr      sp_lp
sp_up:  ld      a,(DP_SEL)
        or      a
        jr      z,sp_lp
        dec     a
        ld      (DP_SEL),a
        jr      sp_dr
sp_dn:  ld      a,(DP_SEL)
        inc     a
        ld      hl,DP_N
        cp      (hl)
        jr      nc,sp_lp
        ld      (DP_SEL),a
        jr      sp_dr
sp_ok:  ld      a,(DP_SEL)
        ld      e,a
        ld      d,0
        ld      hl,DP_ID
        add     hl,de
        ld      a,(hl)
        and     3Fh                     ; the value (the SCREEN index, ...)
        ld      c,a
        call    se_ent
        ld      e,(hl)                  ; DE = the variable of the item
        inc     hl
        ld      d,(hl)
        ld      a,c
        ld      (de),a
        call    5000h+12h               ; the picture back, then the row of the item with its new value
        ld      a,(set_sel)
        ld      (set_old),a
        call    set_part
        call    wait_rel
        jp      se_lp
sp_x:   call    5000h+12h               ; the popup is gone: the picture under it is back, nothing else changed
        call    wait_rel
        jp      se_lp
; V1.11.27: the settings page of the SCREEN 6 module: redraw only the rows set_old and set_sel (and the help line); the old tile page is drawn whole
set_part:
        ld      a,(set_ui)
        or      a
        jp      z,set_page
        jp      5000h+0Ch               ; +12: s6_supd
; V1.11.25: the values of the item set_sel -> DP_N, DP_ID (the value, + 40h on the one set now), DP_NM (24 bytes each), DP_SEL = the one set now
; item table: stride of the names, number of values (0 = the SCREEN list below), the variable, the names
se_tab: defb    10,0
        defw    vsc,s_vsc
        defb    4,3
        defw    rep,s_rep
        defb    4,2
        defw    show_fps,s_off
; HL = the variable of the item set_sel (its row of se_tab + 2); E = the row's offset
se_ent: ld      a,(set_sel)
        ld      e,a
        add     a,a
        add     a,e
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,se_tab+2
        add     hl,de
        ret
sp_fill:xor     a
        ld      (DP_SEL),a
        ld      a,(set_sel)
        or      a
        jr      z,sp_scr
        call    se_ent                  ; the values of AT END, SHOW FPS: IX = the row of se_tab
        dec     hl
        dec     hl
        push    hl
        pop     ix
        ld      a,(ix+1)
        ld      (DP_N),a
        ld      l,(ix+2)
        ld      h,(ix+3)
        ld      a,(hl)                  ; the value set now
        ld      (DP_SEL),a
        ld      (se_cv),a
        ld      l,(ix+4)
        ld      h,(ix+5)                ; HL = the names
        xor     a
        ld      (se_i),a
sg_l:   ld      a,(se_i)
        ld      e,a
        ld      a,(se_cv)
        cp      e
        ld      a,e
        jr      nz,sg_i
        or      40h
sg_i:   ld      d,0
        push    hl
        ld      hl,DP_ID
        add     hl,de
        ld      (hl),a
        ld      a,e                     ; DP_NM + 24 * index
        add     a,a
        add     a,e
        add     a,a
        add     a,a
        add     a,a
        ld      e,a
        ld      hl,DP_NM
        add     hl,de
        ex      de,hl
        pop     hl
        ld      c,(ix+0)
        ld      b,0
        ldir
        ld      a,(se_i)
        inc     a
        ld      (se_i),a
        cp      (ix+1)
        jr      c,sg_l
        ret
sp_scr: ld      c,0                     ; C = entries so far
        ld      b,a                     ; B = SCREEN index
sf_l:   ld      a,b
        cp      7
        jr      c,sf_m
        ld      a,(VC_CAPS)
        and     40h
        jr      z,sf_n
        jr      sf_u
sf_m:   ld      e,a
        inc     e
        ld      a,(vmask)
sf_t:   rrca
        dec     e
        jr      nz,sf_t
        jr      nc,sf_n
sf_u:   ld      hl,DP_ID
        ld      e,c
        ld      d,0
        add     hl,de
        ld      a,(vsc)
        cp      b
        ld      a,b
        jr      nz,sf_i
        or      40h
        ld      d,a
        ld      a,c
        ld      (DP_SEL),a
        ld      a,d
sf_i:   ld      (hl),a
        push    bc
        ld      a,b
        add     a,a
        ld      e,a
        add     a,a
        add     a,a
        add     a,e                     ; 10 * index
        ld      e,a
        ld      d,0
        ld      hl,s_vsc
        add     hl,de
        push    hl
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        ld      e,a
        add     a,a
        add     a,e                     ; 24 * entry
        ld      e,a
        ld      d,0
        ld      hl,DP_NM
        add     hl,de
        ex      de,hl
        pop     hl
        ld      bc,10
        ldir
        pop     bc
        inc     c
sf_n:   inc     b
        ld      a,b
        cp      9
        jr      c,sf_l
        ld      a,c
        ld      (DP_N),a
        ret
; the settings page: a full screen with its own palette (the movie is hidden while it is open and comes back on exit)
set_page:
        ld      a,(set_ui)
        or      a
        jp      nz,5009h
        xor     a
        ld      (ov_on),a
        call    br_clear
        ld      de,0000h                ; header: navy, pink logo, title
        ld      b,64
        ld      a,12h
        call    fillk
        ld      hl,ic_play
        ld      de,0001h
        ld      c,15h
        call    ui_icon
        ld      hl,s_setting
        ld      de,041Ch
        call    gtext
        ld      hl,BUF+2*256            ; pink line under the header (2 pixel lines of row 2)
        ld      b,32
sp_u:   ld      (hl),0FFh
        inc     hl
        ld      (hl),0FFh
        ld      de,7
        add     hl,de
        djnz    sp_u
        ld      de,0200h
        ld      b,32
        ld      a,50h
        call    fillk
        xor     a
        ld      (md_i),a
sp_l:   ld      a,(md_i)                ; item i: label row 4+4i, value band rows 5+4i and 6+4i
        add     a,a
        add     a,a
        add     a,4
        ld      (md_r),a
        ld      a,(md_i)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,set_lab
        add     hl,bc
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,(md_r)
        add     a,a
        add     a,a
        add     a,a
        ld      d,a
        ld      e,12
        call    gtext                   ; label
        ld      a,(md_r)
        ld      d,a
        ld      e,1
        ld      b,30
        ld      a,40h                   ; label: light grey on black
        call    fillk
        ld      a,12h                   ; value band: white on navy
        ld      b,a
sp_c1:  ld      a,(set_sel)
        ld      hl,md_i
        cp      (hl)
        jr      nz,sp_c2
        ld      b,15h                   ; selected: white on pink
sp_c2:  ld      a,b
        ld      (md_c),a
        ld      a,(md_r)
        inc     a
        ld      d,a
        ld      e,1
        ld      b,30
        ld      a,(md_c)
        call    fillk
        ld      a,(md_r)
        add     a,2
        ld      d,a
        ld      e,1
        ld      b,30
        ld      a,(md_c)
        call    fillk
        ld      a,(md_i)                ; value text
        or      a
        jr      nz,sp_v1
        ld      a,(vsc)                 ; MP4 SCREEN (10 bytes per name)
        ld      c,a
        add     a,a
        add     a,a
        add     a,c
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,s_vsc
        add     hl,bc
        jr      sp_v9
sp_v1:  cp      1
        jr      nz,sp_v3
        ld      a,(rep)
        add     a,a
        add     a,a                     ; 4 bytes per name
        ld      c,a
        ld      b,0
        ld      hl,s_rep
        add     hl,bc
        jr      sp_v9
sp_v3:  ld      a,(show_fps)
        or      a
        ld      hl,s_off
        jr      z,sp_v9
        ld      hl,s_on
sp_v9:  ld      a,(md_r)
        inc     a
        add     a,a
        add     a,a
        add     a,a
        add     a,4                     ; centred in the 16 pixel band
        ld      d,a
        ld      e,16
        call    gtext
        ld      a,(md_i)
        inc     a
        ld      (md_i),a
        cp      3
        jp      nz,sp_l
        ld      a,1
        call    br_hints
        jp      showframe

; ---- data ----
rec_up: defb    0,'.','.',0,0,0,0,0,0,0,0,0,0,0,0,0
s_star: defb    "*.*",0
s_dotdot:defb   "..",0
s_st:   defb    "X86MVST.OVL",0
s_title:defb    "X86MV V1.11.28",0
s_items:defb    " ITEMS",0
s_sort: defb    "SORT NAME",0
s_none: defb    "NO MV FILES",0
s_k_ret:defb    "RET",0
s_k_esc:defb    "ESC",0
s_k_play:defb   ":PLAY",0
s_k_quit:defb   ":QUIT",0
s_k_bs: defb    "BS:UP",0
s_k_set:defb    "S:SET",0
s_k_drv:defb    "D:DRIVE",0
s_k_chg:defb    ":CHANGE",0
s_k_back:defb   ":BACK",0
s_setting:defb  "SETTING",0
s_vsc:  defb    "SCREEN 5",0,0,"SCREEN 6",0,0,"SCREEN 7",0,0,"SCREEN 8",0,0,"SCREEN 10",0,"SCREEN 11",0,"SCREEN 12",0
        defb    "V9 FAST",0,0,0,"V9 SHARP",0,0
s_off:  defb    "OFF",0
s_on:   defb    "ON",0,0                ; 4 bytes like s_off: the value names of SHOW FPS are one table
s_rep:  defb    "OFF",0,"ONE",0,"ALL",0
set_lab:defw    sl0,sl2,sl1
sl0:    defb    "MP4 SCREEN",0
sl1:    defb    "SHOW FPS",0
sl2:    defb    "REPEAT",0
s_fit:  defb    "FILL (CROP)",0,0,0,0,0
        defb    "KEEP RATIO",0,0,0,0,0,0
        defb    "STRETCH",0,0,0,0,0,0,0,0,0
fps_s:  defb    "00 FPS",0

; ---- variables ----
ui_ok:  defb    0                       ; 1 = X86MVUI.OVL is at 5000h
set_ui: defb    0                       ; 1 while the list's settings page is open (drawn by X86MVUI.OVL)
br_on:  defb    0
br_note:defw    0               ; message of the last failed play (0 = none)
br_host:defb    0               ; 1 = the list shows the X86 Video library (host folder)
br_cnt: defw    0
br_sel: defw    0
br_top: defw    0
br_depth:defb   0
br_prev:defs    13              ; name of the folder we just left
rep:    defb    0
fitm:   defb    1                       ; MP4 fit (OPEN P8): 0 = fill (crop), 1 = keep the ratio (black bars), 2 = stretch
set_sel:defb    0
set_old:defb    0                       ; V1.11.27: the item that was selected before (partial redraw of the SCREEN 6 settings page)
se_cv:  defb    0
se_i:   defb    0
set_was:defb    0
menu_open:defb  0
kprev5: defb    0
br_all: defb    0               ; always 0 since V1.11.25 (the A key and "all files" are gone; br_ismv / br_filt still read it)
fps_n:  defb    0
fps_v:  defb    0
fps_t:  defw    0
ua_f:   defb    0
bl_i:   defb    0
fw_sp:  defw    0
br_osel:defw    0
br_otop:defw    0
bs_r:   defb    0
bs_a:   defb    0
bs_n:   defb    0
bs_tm:  defb    0
bl_col: defb    0
tp_pat: defb    0
bs_v:   defb    0
bs_d:   defb    0
tp_y:   defb    0
tp_col: defb    0
br_dm:  defs    24
bl_c:   defb    0
bl_y:   defb    0
bl_ty:  defb    0
md_r:   defb    0
md_i:   defb    0
md_y:   defb    0
md_c:   defb    0
bn_i:   defw    0
