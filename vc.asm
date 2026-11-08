; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  vc.asm - X86 Video cartridge client for X86MV (MV2 and mp4 played by the cartridge from the host's video folder)
;  Assembled to run at BMBASE (the unused tail of the frame buffer, B560h-BFFFh); x86mv.asm carries the image behind the font
;  (4360h.., the audio ring area is free until the sound starts) and copies it there at start.  Entry points: fixed jump table.
;  Main program labels come from mainsyms.inc (generated from the main program's symbol file by mkrom.py).
;  Protocol: X86MV_영상카트리지_요청서 (ports 24h-27h, X86 Multimedia cartridge).
; ============================================================
BMBASE  equ     0B560h
BMLEN   equ     0AA0h
VC_C    equ     24h             ; command / status
VC_D    equ     25h             ; data in (overlay) / result bytes out
VC_L    equ     26h             ; parameters in / position low out
VC_H    equ     27h             ; position high out
OVB     equ     0C000h
VK_ERR  equ     7603h
VK_FN   equ     7609h
VK_INFO equ     761Bh           ; vk.asm: HL = length of the file in 1/15 s (0 = none)
VK_MV   equ     7615h           ; vk.asm: A = 3rd letter of .MV? (0 = other), C = SCREEN -> C = P4
VK_FALL equ     7612h           ; vk.asm: A = OPEN error code -> CY = the SCREEN was lowered, open again           ; vk.asm: HL = item of the folder about to be entered           ; vk.asm: A = OPEN error code -> DE = message
BR_MAX  equ     250             ; (same value as browser.inc)
BUF     equ     8000h
BR_STR  equ     7F90h           ; (same as browser.inc)
VPC     equ     0AAh            ; PPI port C / A (keyboard matrix)
VPA     equ     0A9h
; (main's br_upath reads vu_dep = DPS+180h, vu_cur = DPS+183h and the memory records at DPS+300h: keep these addresses)
DPS     equ     7000h           ; scratch of the drive popup and the per-drive memory: free in the browser (the list holds 250 entries = 6000h-6F9Fh)
dp_n    equ     DPS+0           ; entries in the popup
dp_sel  equ     DPS+1
dp_cur  equ     DPS+2           ; id of the drive the list shows
dp_br   equ     DPS+3           ; BUF row being drawn
dp_i    equ     DPS+4
dp_cnt  equ     DPS+5
dp_tid  equ     DPS+6           ; id chosen
dp_k    equ     DPS+7
dp_tgt  equ     DPS+8
dp_rec  equ     DPS+9           ; 2 bytes
dp_rp   equ     DPS+11          ; 2 bytes: record of the folder being entered
dp_nmp  equ     DPS+13          ; 2 bytes
nc_p    equ     dp_nmp          ; name cache: where vu_namec copies the name bytes it reads (the cache slot of the item, or NMBUF as a sink)
NCA      equ     4000h           ; name cache in the audio ring (free while browsing): signature word, then 80 slots of 48 bytes (length, name)
NMBUF   equ     7D80h
NCSIG   equ     0A55Ah
dp_id   equ     DPS+16          ; 12 ids: 0..7 DOS drive (A:..H:), 80h+n USB drive n
dp_nm   equ     DPS+32          ; 12 names x 24 bytes
dp_col   equ     DPS+14
dp_d    equ     DPS+15
dp_tx   equ     DPS+0x140       ; "A:" scratch
vu_dep  equ     DPS+180h
vu_gen  equ     DPS+181h
vu_n    equ     DPS+182h
vu_cur  equ     DPS+183h
vu_i    equ     DPS+184h
vu_num  equ     DPS+185h
vu_k    equ     DPS+186h
vu_cnt  equ     DPS+187h
vu_st   equ     DPS+188h
vu_idx  equ     DPS+18Ah
vu_tot  equ     DPS+18Ch
vc_caps equ     DPS+18Eh
kprev3  equ     DPS+18Fh
vc_fold equ     DPS+190h
vc_item equ     DPS+192h
vc_t    equ     DPS+194h
vc_on   equ     DPS+196h
vn_flag equ     DPS+198h
vc_par  equ     DPS+0x1A0
vc_osg  equ     DPS+0x1A2
dm_ok   equ     DPS+0x200       ; DOS drives: visited?, depth, name of the selected entry (13 bytes each)
dm_dep  equ     DPS+0x208
dm_sel  equ     DPS+0x210
um_rec  equ     DPS+0x300       ; USB drives 1..8, 80 bytes each: [0] ok [1] depth [2..14] drive name [15..66] 4 folder names [67..79] selected name
BDOS    equ     0005h

        org     BMBASE
        include "mainsyms.inc"

        jp      vc_detect               ; +0   CY = no cartridge
        jp      vc_list                 ; +3   fill the browser list from the host folder vc_fold
        jp      vc_playh                ; +6   play the selected host entry
        jp      vc_frame                ; +9   overlay refresh (BC = position)
        jp      vc_redraw               ; +12
        jp      vc_seek                 ; +15  HL = target (1/15 s)
        jp      vc_pause                ; +18
        jp      vc_resume               ; +21
        jp      vc_stop                 ; +24
        jp      vc_vol                  ; +27  C = level 0..5
        jp      vc_up                   ; +30  browser: BS / ".." inside the host library
        jp      vc_ret                  ; +33  browser: RET on a host entry (HL = record)
        jp      vc_enter                ; +36  browser: RET on the "X86 VIDEO" folder of the root list
        jp      vc_run                  ; +39  one loop iteration of the clock: HL = position -> gotidx
        jp      vc_addhost              ; +42  root list: add the "X86 VIDEO" folder
        jp      vc_pop                  ; +45  drive popup
        jp      vc_keyd                 ; +48  A = new press of the D key
        jp      vc_playd                ; +51  an MP4 of the MSX disk (browser, DOS list): the cartridge reads the file

; ---- port access (the test harness replaces these by its fake cartridge) ----
vx_cmd: out     (VC_C),a
        ret
vx_st:  in      a,(VC_C)
        ret
vx_par: out     (VC_L),a
        ret
vx_rd:  in      a,(VC_D)
        ret
vx_pos: in      a,(VC_L)
        ld      l,a
        in      a,(VC_H)
        ld      h,a
        ret
vx_ovl: ld      hl,OVB                  ; 4096 bytes of overlay data
        ld      c,VC_D
        ld      b,0
        ld      d,16
vo_l:   otir
        dec     d
        jr      nz,vo_l
        ret

; HL = value -> two parameter bytes
vc_p16: ld      a,l
        call    vx_par
        ld      a,h
        jp      vx_par

; ---- detect: CY = none.  An empty bus reads FFh ----
vc_detect:
        ld      hl,DPS+180h             ; forget every drive's last place, clear the variables
        ld      de,DPS+181h
        ld      bc,3FFh
        ld      (hl),0
        ldir
        in      a,(VC_C)
        cp      0FFh
        jr      z,vd_no
        ld      a,01h
        call    vx_cmd                  ; IDENT
        ld      hl,vc_sig
        ld      b,4
vd_l:   call    vx_rd
        cp      (hl)
        jr      nz,vd_no
        inc     hl
        djnz    vd_l
        call    vx_rd                   ; 5th byte: capabilities (bit0 USB access, bit1 USB video open); old emulators give 0
        cp      0FFh
        jr      nz,vd_c
        xor     a
vd_c:   ld      (vc_caps),a
        or      a
        ret
vd_no:  scf
        ret
vc_sig: defb    "XVD",1

; ---- root list: one extra folder "X86 VIDEO" (marker FFFFh in the spare bytes) ----
vc_addhost:
        ld      a,(vcpres)
        or      a
        ret     z
        ld      hl,vc_hname
        ld      a,0FFh                  ; marker FFFFh = the X86 VIDEO library
        call    vh_one
        ret
vh_one: push    af
        ld      de,BR_TMP
        ld      a,1                     ; folder
        ld      (de),a
        inc     de
        ld      bc,13
        ldir
        pop     af
        ld      (de),a
        inc     de
        ld      a,0FFh
        ld      (de),a
        jp      br_ins
vc_hname:defb   "X86 VIDEO",0,0,0,0

; ---- browser: enter the library (from the root list) ----
vc_enter:
        ld      a,1
        ld      (br_host),a
        ld      hl,0
        ld      (vc_fold),hl
        call    vc_list
        jp      br_again

; ---- list of host folder vc_fold into BR_ENT (same records as br_scan) ----
vc_list:
        ld      a,(br_host)
        cp      2
        jp      z,vu_relist
        ld      hl,0
        ld      (br_cnt),hl
        ld      (br_sel),hl
        ld      (br_top),hl
        ld      hl,0FFFFh               ; "..": parent folder number (FFFFh = leave the library)
        call    vl_get
        ret     c
        ld      hl,(BR_TMP+14)          ; (vl_get stored the reply here)
        ld      (vc_par),hl
        xor     a
        ld      (BR_TMP),a              ; type 0 = parent entry
        ld      hl,BR_ENT
        ld      de,BR_TMP
        ex      de,hl
        ld      bc,16
        ldir
        ld      hl,1
        ld      (br_cnt),hl
        ld      hl,0
vl_n:   push    hl
        call    vl_get
        jr      c,vl_x
        call    br_ins
        pop     hl
        inc     hl
        push    hl
        ld      hl,(br_cnt)
        ld      de,BR_MAX               ; the list holds BR_MAX entries
        or      a
        sbc     hl,de
        pop     hl
        jr      c,vl_n
        ret
vl_x:   pop     hl
        ret

; HL = item number -> LIST reply into BR_TMP (record).  CY = none left
vl_get: push    hl
        ld      a,10h
        call    vx_cmd                  ; LIST: the command first, then folder and item
        ld      hl,(vc_fold)
        call    vc_p16
        pop     hl
        push    hl
        call    vc_p16
        call    vx_rd                   ; type: 0 file, 1 folder, 2 parent, FFh = end
        cp      0FFh
        jr      z,vg_e
        ld      c,a
        ld      hl,BR_TMP+1
        ld      b,12
vg_n:   call    vx_rd
        ld      (hl),a
        inc     hl
        djnz    vg_n
        xor     a
        ld      (hl),a                  ; name terminator (13th byte)
        inc     hl
        call    vx_rd
        ld      (hl),a                  ; folder number / spare
        inc     hl
        call    vx_rd
        ld      (hl),a
        ld      a,c
        or      a
        jr      nz,vg_f
        ld      a,2                     ; file: record type 2, spare = item number
        ld      (BR_TMP),a
        pop     hl
        ld      (BR_TMP+14),hl
        or      a
        ret
vg_f:   cp      1
        ld      a,1
        jr      z,vg_s
        xor     a                       ; parent
vg_s:   ld      (BR_TMP),a
        pop     hl
        or      a
        ret
vg_e:   pop     hl
        scf
        ret

; ---- browser: RET on an entry of the host list (HL = record) ----
vc_ret: ld      a,(br_host)
        cp      2
        jp      z,vu_ret
        ld      a,(hl)
        or      a
        jp      z,vc_up
        cp      2
        jr      z,vr_f
        ld      de,14                   ; folder: its number is in the spare bytes
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (vc_fold),de
        call    vc_list
        jp      br_again
vr_f:   inc     hl
        ld      (fname),hl
        jp      playfile

; ---- browser: BS or ".." inside the library: parent folder, or back to the DOS list ----
vc_up:  ld      a,(br_host)
        cp      2
        jp      z,vu_up
        ld      hl,(vc_par)
        ld      a,h
        and     l
        inc     a
        jr      z,vu_x
        ld      (vc_fold),hl
        call    vc_list
        jp      br_again
vu_x:   ld      hl,vc_hname             ; select the "X86 VIDEO" folder again
        xor     a
        ld      (br_host),a
        ld      de,br_prev
        ld      bc,13
        ldir
        call    br_scan
        call    br_findprev
        jp      br_again

; ---- play the selected host entry ----
vc_playh:
        call    play_reset
        ld      hl,(br_sel)
        call    br_entaddr
        push    hl
        ld      de,14
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        res     7,d
        ld      (vc_item),de
        pop     hl
        inc     hl
        ld      (fname),hl              ; the overlay title
        ld      a,(br_host)
        cp      2
        jr      nz,vp_nu
        ld      a,20h                   ; USB: has a drive been plugged or pulled since the list was made?
        call    vx_cmd                  ; CHANGE
        call    vx_rd
        ld      b,a
        call    vx_rd
        ld      a,(vu_gen)
        cp      b
        jr      z,vp_nu
        ld      de,vc_mchg
        jp      err
vp_nu:  ld      a,(vsc)                 ; SCREEN for mp4, SCREEN 2 for MV2
        ld      c,a
        ld      b,0
        ld      hl,vc_scrtab
        add     hl,bc
        ld      c,(hl)
        ld      hl,(fname)
        call    vp_ext                  ; A = 3rd letter of .MV?, 0 = not an MV name
        call    VK_MV                   ; C = P4: 2 for MV2, 5..8 / 10..12 for MV5..MVC (USB, caps bit 4)
vp_s:   ld      a,(br_host)
        cp      2
        jr      nz,vp_t
        ld      a,(vc_caps)
        and     18h
        jr      nz,vp_t                 ; the cartridge opens MP4 / MV5..MVC from USB too (caps bit 3 / 4)
        ld      c,2                     ; USB: only MV2 (SCREEN 2)
vp_t:   push    bc
        ld      a,c
        ld      (dp_col),a              ; P4 sent (for the note of an error)
        ld      a,11h
        call    vx_cmd                  ; OPEN: the command first, then the 12 parameters (the cartridge starts it when the 12th arrives)
        ld      hl,(vc_fold)
        ld      a,(br_host)
        or      a
        jr      nz,vp_h
        ld      hl,0FFFDh               ; folder FFFDh = the MSX disk file given with SETPATH
        jr      vp_f
vp_h:   cp      2
        jr      nz,vp_f
        ld      hl,0FFFFh               ; folder FFFFh = the USB folder chosen with SEL/CD
vp_f:   call    vc_p16
        ld      hl,(vc_item)
        call    vc_p16
        pop     bc
        ld      a,c
        call    vx_par                  ; P4 SCREEN
        ld      a,192
        call    vx_par                  ; P5 lines
        ld      a,24
        call    vx_par                  ; P6 top overlay lines
        ld      a,40
        call    vx_par                  ; P7 bottom overlay lines
        ld      a,(fitm)
        call    vx_par                  ; P8 fit: 0 fill (crop), 1 keep the ratio, 2 stretch (settings: MP4 FIT)
        ld      a,75
        call    vx_par                  ; P9 dither
        xor     a
        call    vx_par                  ; P10 fps limit
        ld      a,(pal)
        call    vx_par                  ; P11 PAL
        ld      hl,(JIFFY)
        ld      (vc_t),hl
vp_w:   call    vx_st
        bit     3,a
        jr      nz,vp_er
        bit     0,a
        jr      z,vp_ok
        ld      hl,(JIFFY)
        ld      de,(vc_t)
        or      a
        sbc     hl,de
        ld      de,900                  ; 15 s
        or      a
        sbc     hl,de
        jr      c,vp_w
        jp      e_open
vp_er:  call    vx_rd                   ; the error code of the cartridge (25h): the note says why (vk.asm)
        ld      (dp_d),a
        call    VK_FALL                 ; code 6 on SCREEN 10..12: use SCREEN 8 instead and open again
        jp      c,vp_nu
        cp      8
        jr      c,vp_e1
        ld      de,vc_m8                ; 8: the MSX disk file is missing or unreadable
        jr      z,vp_e2
        cp      9
        ld      de,vc_m9                ; 9: a drive that cannot be read
        jr      z,vp_e2
        cp      11
        ld      de,vc_mav               ; 11: an AVI file (not played yet)
        jr      z,vp_e2
        cp      12
        ld      de,vc_mlg               ; 12: the video is too long (V1.11.8, X86MSX 8.0.122)
        jr      z,vp_e2
        cp      13
        ld      de,mn_big               ; 13: the picture is bigger than 1920x1088 (V1.11.20, X86MSX 8.0.141)
        jr      z,vp_e2
        cp      14
        ld      de,mn_dec               ; 14: the decoder could not make the first picture (V1.11.20)
        jr      z,vp_e2
vp_e1:  call    VK_ERR
vp_e2:
        jp      err
vp_ok:  call    VK_INFO                 ; INFO: HL = length in 1/15 s (asked again while it is 0)
        ld      (nframes),hl
        ld      a,h
        or      l
        jr      nz,vp_i                 ; still 0: the cartridge did not open the file (playing on hung the computer in V1.9.6)
        ld      a,05h
        call    vx_cmd                  ; STOP (a video left open keeps drawing)
        ld      a,1
        call    VK_ERR
        jp      err
vp_i:
        ld      a,1
        ld      (vmode),a
        xor     a
        ld      (vc_on),a
        dec     a
        ld      (vc_osg),a              ; nothing sent yet
        ld      hl,0
        ld      (cur),hl
        ld      a,(vol_lv)
        ld      c,a
        call    vc_vol
        call    vc_ui
        ld      a,03h
        call    vx_cmd                  ; PLAY
        ld      hl,0FFFFh
        ld      (cur),hl
        jp      mloop

; Z = the name at HL ends in .MV2 (any case); HL kept
vp_ext: push    hl
vx_l:   ld      a,(hl)
        or      a
        jr      z,vx_n
        inc     hl
        cp      '.'
        jr      nz,vx_l
        ld      a,(hl)
        and     0DFh
        cp      'M'
        jr      nz,vx_n
        inc     hl
        ld      a,(hl)
        and     0DFh
        cp      'V'
        jr      nz,vx_n
        inc     hl
        ld      a,(hl)                  ; the 3rd letter
        pop     hl
        ret
vx_n:   pop     hl
        xor     a                       ; 0 = not .MV?
        ret

; ---- the clock: position -> main's gotidx (BC = index).  End and error come from the status ----
vc_run: call    vx_st
        bit     3,a
        jp      nz,e_open
        ld      c,a
        ld      a,09h
        call    vx_cmd                  ; POS
        call    vx_pos
        bit     2,c
        jp      z,gotidx
        ld      hl,(nframes)            ; the cartridge says it is over
        jp      gotidx

; ---- overlay: the position changed ----
vc_frame:
        call    vc_ui
        jp      mloop
vc_redraw:
        jp      vc_ui
vc_ui:  ld      a,(ov_ok)
        or      a
        ret     z
        call    ui_draw                 ; (draws into BUF, copies the finished overlay to OVB, sets ov_on)
        ld      hl,ov_sg
        ld      de,vc_osg
        ld      b,8
vu_c:   ld      a,(de)
        cp      (hl)
        jr      nz,vu_s
        inc     hl
        inc     de
        djnz    vu_c
        jr      vu_o
vu_s:   ld      hl,ov_sg
        ld      de,vc_osg
        ld      bc,8
        ldir
        ld      a,0Dh
        call    vx_cmd                  ; OVL + 4096 bytes
        call    vx_ovl
vu_o:   ld      a,(ov_on)
        ld      hl,vc_on
        cp      (hl)
        ret     z
        ld      (hl),a
        ld      b,a
        ld      a,0Eh
        call    vx_cmd                  ; OVLON: the command first
        ld      a,b
        jp      vx_par                  ; P0

vc_seek:ld      a,06h
        call    vx_cmd                  ; SEEK: the command first
        call    vc_p16
        ld      a,(paused)
        or      a
        ret     nz
        ld      a,03h
        jp      vx_cmd

vc_pause:
        ld      a,04h
        jp      vx_cmd
vc_resume:
        ld      a,03h
        jp      vx_cmd
vc_vol: ld      hl,vc_pct
        ld      b,0
        add     hl,bc
        ld      a,07h
        call    vx_cmd                  ; VOL: the command first
        ld      a,(hl)
        jp      vx_par
vc_pct: defb    100,71,50,35,25,0

vc_stop:ld      a,(vmode)
        or      a
        ret     z
        ld      a,05h
        call    vx_cmd                  ; STOP
        xor     a
        ld      (vmode),a
        jp      vdp_init                ; back to the tile screen of the list

; ============================================================
;  USB drives (X86 Multimedia USB access, commands 20h-29h): [USB] folder of the root list
;  level vu_dep: 0 = list of drives, 1 = top folder of a drive, 2.. = deeper.  Entries: type 1 folder / 2 file, spare = drive number / item number.
; ============================================================
vu_relist:
        jp      vu_dir

; list the cartridge's current folder: ".." + folders and MV2 files (filter 2), 8 per LIST call
vu_dir: call    vu_reset
        ld      hl,0
        ld      (vu_st),hl
vd2_l:  ld      hl,(vu_st)
        ld      (vu_idx),hl
        ld      a,24h
        call    vx_cmd                  ; LIST (USB commands: the command first, then its parameters)
        ld      hl,(vu_st)
        call    vc_p16
        ld      a,8
        call    vx_par
        call    br_filt                 ; filter (main): mv2 = 2; caps bit 3 -> 8 = video (mv2 mp4 m4v mov), caps bit 4 -> 16 = MV5..MVC (24 = both); folders always; A key = all files
vd2_fl: call    vx_par
        call    vx_rd
        ld      l,a
        call    vx_rd
        ld      h,a
        ld      (vu_tot),hl
        call    vx_rd
        ld      (vu_cnt),a
        call    vx_rd                   ; flags
        ld      a,(vu_cnt)
        or      a
        ret     z
vd2_i:  call    vx_rd                   ; kind: 0 file, 1 folder
        ld      (vu_k),a
        ld      b,4
vd2_s:  call    vx_rd                   ; size (not used)
        djnz    vd2_s
        call    vx_rd
        ld      b,a
        call    vc_ncs                  ; the cache slot of this item
        ld      hl,BR_TMP+1
        xor     a
        ld      (vn_flag),a
        call    vu_name
        call    vc_nce
        ld      a,(vu_k)
        or      a
        ld      a,2
        jr      z,vd2_t
        dec     a
vd2_t:  ld      (BR_TMP),a
        ld      hl,(vu_idx)
        ld      a,(vn_flag)
        or      a
        jr      z,vd2_f
        set     7,h                     ; bit 7 of the item number: this name has non-ASCII characters
vd2_f:  ld      (BR_TMP+14),hl
        ld      hl,(br_cnt)
        ld      de,BR_MAX
        or      a
        sbc     hl,de
        jr      nc,vd2_n                ; list full: the rest is not shown
        call    br_ins
vd2_n:  ld      hl,(vu_idx)
        inc     hl
        ld      (vu_idx),hl
        ld      hl,vu_cnt
        dec     (hl)
        jr      nz,vd2_i
        ld      hl,(vu_idx)             ; next batch
        ld      (vu_st),hl
        ld      de,(vu_tot)
        or      a
        sbc     hl,de
        ret     nc                      ; all shown
        ld      hl,(br_cnt)
        ld      de,BR_MAX
        or      a
        sbc     hl,de
        jp      c,vd2_l
        ret

; the list starts with ".." (type 0)
vu_reset:
        ld      hl,NCSIG
        ld      (NCA),hl                 ; the name cache is valid (playback overwrites the start of the ring: then it is not)
        ld      hl,0
        ld      (br_sel),hl
        ld      (br_top),hl
        ld      hl,BR_ENT
        ld      de,BR_ENT+1
        ld      bc,15
        ld      (hl),0
        ldir
        ld      a,'.'
        ld      (BR_ENT+1),a
        ld      (BR_ENT+2),a
        ld      hl,1
        ld      (br_cnt),hl
        ret

; B bytes of a UTF-8 name from the cartridge -> HL (13-byte field): the first 12 as ASCII (other bytes '?'), the rest dropped
vu_name:ld      c,12
vu_namec:
vn_l:   ld      a,b
        or      a
        jr      z,vn_e
        call    vx_rd
        dec     b
        ld      d,a
        push    hl
        ld      hl,(nc_p)
        ld      (hl),d                  ; tee: every byte of the name also goes to the cache slot
        inc     hl
        ld      (nc_p),hl
        pop     hl
        ld      a,c
        or      a
        jr      nz,vn_k
        inc     a                       ; more than 12 characters: the full name is drawn by the cartridge (vk.asm)
        ld      (vn_flag),a
        jr      vn_l
vn_k:   ld      a,d
        cp      20h
        jr      c,vn_q
        cp      7Fh
        jr      c,vn_s
vn_q:   ld      a,1                     ; a byte the list font cannot show: the name is drawn by the cartridge (vk.asm)
        ld      (vn_flag),a
        ld      a,'?'
vn_s:   ld      (hl),a
        inc     hl
        dec     c
        jr      vn_l
vn_e:   inc     c                       ; zero pad: remaining characters + the terminator
        xor     a
vn_z:   ld      (hl),a
        inc     hl
        dec     c
        jr      nz,vn_z
        ret

; the browser's DOS list, RET on a *.MP4 (main checked the cartridge: caps bit 5): the cartridge reads the file from the virtual hard disk.
; fname = its 8.3 name.  SETPATH (2Ah): drive 0..7, then "\folder\NAME.MP4" and a zero; OPEN then goes with folder FFFDh (vp_t)
vc_playd:
        ld      hl,0
        ld      (vc_item),hl
        ld      de,NMBUF+1
        ld      b,0
        ld      c,59h                   ; _GETCD: the current folder of the current drive (no leading backslash)
        call    BDOS
        ld      a,5Ch
        ld      (NMBUF),a
        ld      hl,NMBUF+1
        ld      a,(hl)
        or      a
        jr      z,pd_s                  ; the root: "\NAME"
pd_e:   inc     hl
        ld      a,(hl)
        or      a
        jr      nz,pd_e
        ld      (hl),5Ch
        inc     hl
pd_s:   ex      de,hl
        ld      hl,(fname)
pd_c:   ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        or      a
        jr      nz,pd_c
        ld      a,2Ah
        call    vx_cmd                  ; SETPATH: the command first, then the parameters
        ld      c,19h                   ; _CURDRV: 0 = A:
        call    BDOS
        call    vx_par
        ld      hl,NMBUF
pd_t:   ld      a,(hl)
        inc     hl
        push    hl
        push    af
        call    vx_par
        pop     af
        pop     hl
        or      a
        jr      nz,pd_t
        jp      vp_nu
vc_m8:  defb    "MSX disk file not readable",0
vc_m9:  defb    "Drive not readable",0
vc_mav: defb    "AVI is not supported yet",0
vc_mlg: defb    "Video is too long",0
; ---- name cache (V1.10.0): the names the LIST answers carry are kept, so drawing a row needs no call to the cartridge ----
; A = item number (< 80) -> HL = its slot
nc_slot:ld      l,a
        ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; * 48
        ld      de,NCA+2
        add     hl,de
        ret
; B = name length of item (vu_idx): the bytes vu_namec reads go to its slot (length first); items >= 80 and names over 47 bytes are not kept
vc_ncs: push    bc
        ld      de,NMBUF                ; sink
        ld      hl,(vu_idx)
        ld      a,h
        or      a
        jr      nz,ns_s
        ld      a,l
        cp      80
        jr      nc,ns_s
        call    nc_slot
        ld      a,b
        cp      48
        jr      c,ns_l
        xor     a
ns_l:   ld      (hl),a
        inc     hl
        ex      de,hl
ns_s:   ld      (nc_p),de
        pop     bc
        ret
vc_nce: push    hl
        ld      hl,NMBUF                ; no slot: the bytes go to the sink
        ld      (nc_p),hl
        pop     hl
        ret
; DE = item number -> A = name length with the name copied to NMBUF (vk.asm uses it); A = 0: not kept.  DE is kept
vc_nc:  ld      a,(br_host)
        cp      2
        jr      nz,nc_m
        ld      a,d
        or      a
        jr      nz,nc_m
        ld      a,e
        cp      80
        jr      nc,nc_m
        ld      hl,(NCA)
        ld      bc,NCSIG
        or      a
        sbc     hl,bc
        jr      nz,nc_m
        push    de
        ld      a,e
        call    nc_slot
        ld      a,(hl)
        or      a
        jr      z,nc_z
        ld      c,a
        ld      b,0
        inc     hl
        ld      de,NMBUF
        ldir
nc_z:   pop     de
        ret
nc_m:   xor     a
        ret

; CY = the last command failed
vu_chk: call    vx_st
        bit     3,a
        jr      nz,vk_e
        or      a
        ret
vk_e:   scf
        ret

; RET on an entry (HL = record)
vu_ret: ld      (dp_rp),hl
        ld      a,(hl)
        or      a
        jr      z,vu_up
        cp      2
        jp      z,vr_f
        ld      de,14                   ; folder: item number
        add     hl,de
vu_cd:  ld      e,(hl)
        inc     hl
        ld      d,(hl)
        res     7,d
        ex      de,hl
        push    hl
        call    VK_FN                   ; remember the (Korean) name of the folder for the path line
        pop     hl
        ld      a,23h
        call    vx_cmd                  ; CD
        call    vc_p16
        call    vu_chk
        jr      c,vu_err
        ld      hl,vu_dep
        inc     (hl)
        call    um_recpath
        call    vu_dir
        jp      br_again

; BS or ".."
vu_up:  ld      a,(vu_dep)
        or      a
        jp      z,vc_pop                ; the drive list: the drive popup
        cp      1
        jr      z,vu_s0
        ld      a,23h
        call    vx_cmd                  ; CD ..
        ld      hl,0FFFFh
        call    vc_p16
        call    vu_chk
        jr      c,vu_err
        ld      hl,vu_dep
        dec     (hl)
        call    vu_dir
        jp      br_again
vu_s0:  jp      vc_pop

; the cartridge refused (drive pulled): back to the drive list with a note
vu_err: ld      hl,vc_mdrv
        ld      (br_note),hl
        jp      vc_pop

vc_mchg:defb    "USB changed",0

; ============================================================
;  Drive popup: D key, BS at the top of a drive, RET on the "USB" folder.  DOS drives (login vector) + USB drives (VOLS).
;  Each drive remembers its last folder and selected name: DOS keeps the folder itself (per drive), USB keeps the folder names.
; ============================================================
vc_keyd:di                              ; A = new press of the D key (keyboard row 3, bit 1)
        in      a,(VPC)
        and     0F0h
        or      03h
        out     (VPC),a
        in      a,(VPA)
        ei
        cpl
        and     02h
        ld      b,a
        ld      a,(kprev3)
        cpl
        and     b
        ld      c,a
        ld      a,b
        ld      (kprev3),a
        ld      a,c
        ret

vc_pop: call    dp_build
        call    dp_curid
        ld      (dp_cur),a
        ld      c,a
        xor     a
        ld      (dp_sel),a              ; select the current drive
        ld      b,0
dp_fc:  ld      a,(dp_n)
        cp      b
        jr      z,dp_redraw
        ld      a,b
        call    dp_idof
        cp      c
        jr      z,dp_fh
        inc     b
        jr      dp_fc
dp_fh:  ld      a,b
        ld      (dp_sel),a
dp_redraw:
        call    dp_hook                 ; main: the SCREEN 6 look (X86MVUI.OVL) draws the popup, else dp_draw (+51)
dp_lp:  halt
        call    vc_keyd
        or      a
        jr      nz,dp_close
        call    br_poll                 ; D = new presses of row 8, E = row 7
        ld      a,d
        or      e
        jr      z,dp_lp
        bit     7,e
        jp      nz,dp_go                ; RET
        bit     2,e
        jr      nz,dp_close             ; ESC
        bit     5,e
        jr      nz,dp_close             ; BS
        bit     5,d
        jr      nz,dp_up
        bit     6,d
        jr      nz,dp_dn
        jr      dp_lp
dp_close:
        jp      br_again
dp_up:  ld      a,(dp_sel)
        or      a
        jr      z,dp_lp
        dec     a
        ld      (dp_sel),a
        jr      dp_redraw
dp_dn:  ld      a,(dp_sel)
        inc     a
        ld      hl,dp_n
        cp      (hl)
        jr      nc,dp_lp
        ld      (dp_sel),a
        jr      dp_redraw

; A = index -> A = drive id
dp_idof:ld      e,a
        ld      d,0
        ld      hl,dp_id
        add     hl,de
        ld      a,(hl)
        ret

; A = id of the drive the list shows
dp_curid:
        ld      a,(br_host)
        cp      2
        jr      nz,dc_d
        ld      a,(vu_cur)
        or      80h
        ret
dc_d:   ld      c,19h                   ; _CURDRV
        call    BDOS
        ret

; the entries: DOS drives from the login vector, then the USB drives
dp_build:
        call    vc_nce
        xor     a
        ld      (dp_n),a
        ld      c,18h                   ; _LOGIN
        call    BDOS
        ld      e,l                     ; E = A:..H: (bit 0 = A:)
        ld      b,0
dbl:    srl     e
        jr      nc,dbn
        push    de
        push    bc
        ld      a,(dp_n)
        ld      e,a
        ld      d,0
        ld      hl,dp_id
        add     hl,de
        ld      (hl),b
        inc     a
        ld      (dp_n),a
        pop     bc
        pop     de
dbn:    inc     b
        ld      a,b
        cp      8
        jr      nz,dbl
        ld      a,(vcpres)
        or      a
        ret     z
        ld      a,(vc_caps)
        and     3
        cp      3
        ret     nz
        ld      a,20h
        call    vx_cmd                  ; CHANGE
        call    vx_rd
        call    vx_rd
        ld      (dp_cnt),a
        xor     a
        ld      (dp_i),a
dbu_l:  ld      a,(dp_i)
        ld      hl,dp_cnt
        cp      (hl)
        ret     nc
        ld      a,(dp_n)
        cp      10                      ; the popup shows 10 entries
        ret     nc
        ld      a,21h
        call    vx_cmd                  ; VOLS
        ld      a,(dp_i)
        call    vx_par
        call    vx_rd
        cp      0FFh
        ret     z
        call    vx_rd
        ld      (vu_num),a
        cp      2
        jr      c,dbs                   ; USB 0 and 1 are not shown in the popup
        call    vx_rd                   ; flags
        call    vx_rd
        ld      b,a                     ; name length
        ld      a,(dp_n)
        call    dp_nmadr
        ld      c,19
        call    vu_namec
        ld      a,(dp_n)
        ld      e,a
        ld      d,0
        ld      hl,dp_id
        add     hl,de
        ld      a,(vu_num)
        or      80h
        ld      (hl),a
        ld      hl,dp_n
        inc     (hl)
dbs:    ld      hl,dp_i
        inc     (hl)
        jr      dbu_l

; A = index -> HL = name of USB entry A (24 bytes each)
dp_nmadr:
        ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,dp_nm
        add     hl,de
        ret

; A = 0..7 -> HL = A * 13
mul13:  ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,de
        ret

; A = USB drive number 1..8 -> HL = its memory record (CY = no memory for that number)
um_adr: or      a
        jr      z,ua_x
        cp      9
        jr      nc,ua_x
        dec     a
        ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,hl
        add     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,um_rec
        add     hl,de
        or      a
        ret
ua_x:   scf
        ret

; RET on an entry
dp_go:  ld      a,(dp_sel)
        call    dp_idof
        ld      (dp_tid),a
        ld      hl,dp_cur
        cp      (hl)
        jp      z,dp_close              ; already there
        call    dp_save
        ld      a,(dp_tid)
        bit     7,a
        jp      nz,dp_usb

; ---- to a DOS drive ----
        ld      e,a
        ld      c,0Eh                   ; _SELDSK
        call    BDOS                    ; (L=A = the number of drives, not an error code: V1.11.9 asks _CURDRV instead)
        ld      c,19h                   ; _CURDRV
        call    BDOS
        ld      hl,dp_tid
        cp      (hl)
        jp      nz,dp_fail              ; the drive did not become the current one
        xor     a
        ld      (br_host),a
        ld      a,(dp_tid)
        ld      c,a
        ld      b,0
        ld      hl,dm_ok
        add     hl,bc
        ld      a,(hl)
        or      a
        jr      z,dd_root               ; never visited: its top folder
        ld      hl,dm_dep
        add     hl,bc
        ld      a,(hl)
        ld      (br_depth),a
        ld      b,0                     ; is the folder DOS remembers still there?
        ld      de,BR_DIR
        ld      c,59h                   ; _GETCD
        call    BDOS
        or      a
        jr      nz,dd_root
        ld      a,(dp_tid)
        call    mul13
        ld      de,dm_sel
        add     hl,de
        ld      de,br_prev
        ld      bc,13
        ldir
        jr      dd_go
dd_root:ld      de,vc_bs                ; (disk changed, drive not visited before...) the top folder
        ld      c,5Ah                   ; _CHDIR
        call    BDOS
        xor     a
        ld      (br_depth),a
        ld      (br_prev),a
dd_go:  call    br_scan
        call    br_findprev
        jp      br_again
BR_DIR  equ     7F50h
vc_bs:  defb    5Ch,0

; ---- to a USB drive ----
dp_usb: and     7Fh
        push    af
        ld      a,22h
        call    vx_cmd                  ; SEL
        pop     af
        call    vx_par
        call    vu_chk
        jp      c,dp_fail
        ld      a,(dp_tid)
        and     7Fh
        ld      (vu_cur),a
        ld      a,2
        ld      (br_host),a
        ld      a,1
        ld      (vu_dep),a
        ld      a,20h
        call    vx_cmd
        call    vx_rd
        ld      (vu_gen),a              ; the drives as they are now
        ld      a,(vu_cur)
        call    um_adr
        jr      c,du_top
        ld      (dp_rec),hl
        ld      a,(dp_sel)
        call    dp_nmadr
        ld      de,(dp_rec)
        inc     de
        inc     de
        ld      b,12
du_c:   ld      a,(de)
        cp      (hl)
        jr      nz,du_new
        inc     hl
        inc     de
        djnz    du_c
        ld      hl,(dp_rec)
        ld      a,(hl)
        or      a
        jr      nz,du_rs
du_new: ld      a,(dp_sel)              ; another memory stick (or none yet): start at its top folder
        call    dp_nmadr
        push    hl
        ld      hl,(dp_rec)
        ld      (hl),1
        inc     hl
        ld      (hl),1
        inc     hl
        ex      de,hl
        pop     hl
        ld      bc,12
        ldir
        xor     a
        ld      (de),a
        ld      hl,(dp_rec)
        ld      de,67
        add     hl,de
        ld      (hl),a
du_top: call    vu_dir
        jp      br_again
du_rs:  inc     hl                      ; remembered: walk down the saved folder names
        ld      a,(hl)
        cp      6
        jr      c,du_r1
        ld      a,5
du_r1:  ld      (dp_tgt),a
        ld      a,2
        ld      (dp_k),a
du_rl:  ld      a,(dp_tgt)
        ld      hl,dp_k
        cp      (hl)
        jr      c,du_end
        call    vu_dir
        ld      a,(dp_k)
        sub     2
        call    mul13
        ld      de,(dp_rec)
        add     hl,de
        ld      de,15
        add     hl,de
        ld      de,br_prev              ; the folder named so: br_findprev selects it (the ".." entry at 0 never matches)
        ld      bc,13
        ldir
        ld      hl,0
        ld      (br_sel),hl
        call    br_findprev
        ld      hl,(br_sel)
        ld      a,h
        or      l
        jr      z,du_fail
        call    br_entaddr
        ld      de,14
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        res     7,d
        ex      de,hl
        ld      a,23h
        call    vx_cmd                  ; CD
        call    vc_p16
        call    vu_chk
        jr      c,du_fail
        ld      hl,vu_dep
        inc     (hl)
        ld      hl,dp_k
        inc     (hl)
        jr      du_rl
du_fail:ld      a,22h                   ; a folder is gone: back to the top folder of the drive
        call    vx_cmd
        ld      a,(vu_cur)
        call    vx_par
        ld      a,1
        ld      (vu_dep),a
        jp      du_top
du_end: call    vu_dir
        ld      hl,(dp_rec)
        ld      de,67
        add     hl,de
        ld      de,br_prev
        ld      bc,13
        ldir
        call    br_findprev
        jp      br_again

dp_fail:ld      hl,vc_mdrv
        ld      (br_note),hl
        jp      br_again

; save where the drive we leave is: DOS = depth + selected name (the folder stays in DOS), USB = depth + selected name (folder names are kept while entering)
dp_save:ld      a,(br_host)
        cp      2
        jr      z,ds_u
        ld      a,(dp_cur)
        and     7
        ld      c,a
        ld      b,0
        ld      hl,dm_ok
        add     hl,bc
        ld      (hl),1
        ld      hl,dm_dep
        add     hl,bc
        ld      a,(br_depth)
        ld      (hl),a
        ld      a,c
        call    mul13
        ld      de,dm_sel
        add     hl,de
        ex      de,hl
        jr      sel_name
ds_u:   ld      a,(vu_cur)
        call    um_adr
        ret     c
        ld      (hl),1
        inc     hl
        ld      a,(vu_dep)
        ld      (hl),a
        ld      de,66
        add     hl,de
        ex      de,hl
sel_name:                               ; DE = 13 bytes: the name of the selected entry
        ld      a,(br_host)
        cp      1
        ld      hl,vc_hname
        jr      z,sn_c                  ; library: the "X86 VIDEO" folder
        ld      hl,(br_cnt)
        ld      a,h
        or      l
        jr      z,sn_z
        push    de
        ld      hl,(br_sel)
        call    br_entaddr
        inc     hl
        pop     de
sn_c:   ld      bc,13
        ldir
        ret
sn_z:   xor     a
        ld      (de),a
        ret

; folder entered on a USB drive: remember its name (first 4 levels)
um_recpath:
        ld      a,(vu_dep)
        sub     2
        cp      4
        ret     nc
        ld      c,a
        ld      a,(vu_cur)
        call    um_adr
        ret     c
        push    hl
        ld      a,c
        call    mul13
        pop     de
        add     hl,de
        ld      de,15
        add     hl,de
        ex      de,hl
        ld      hl,(dp_rp)
        inc     hl
        ld      bc,13
        ldir
        ret


vc_mdrv:defb    "No drive",0

vc_scrtab:defb  5,6,7,8,10,11,12,13,14   ; 13 / 14 = V9990 fast / sharp (Gfx9000, caps bit 6)
vc_end:
        defs    BMBASE+BMLEN-vc_end     ; (fails if the module outgrew BMLEN)
