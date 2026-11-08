; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  vk.asm - names with non-ASCII characters (Korean, ...) in the file list: the X86 Multimedia cartridge draws them (command 30h TEXT)
;  Assembled to run at VKBASE (7600h, free in the browser); x86mv.asm carries the image behind vc.bin and copies it there at start.
;  Entry: vk_draw (HL = record + 1).  mainsyms.inc / vcsyms.inc come from the symbol files (mkrom.py, build.py).
;  The list entry is 2 tile rows (16 lines) high; the 10 line glyphs are copied to lines 3..12 of it, ORed into the cleared pattern bytes.
; ============================================================
VKBASE  equ     7600h
VKLEN   equ     0780h
NMBUF   equ     7D80h           ; the UTF-8 name (at most 100 bytes)
BMBUF   equ     7DE4h           ; the bitmap from the cartridge (at most 27 bytes x 10 lines = 270: BR_FIB starts at 7F00h)
BUF     equ     8000h
VDP_D   equ     98h
VDP_C   equ     99h
DPS     equ     7000h
FNC     equ     7240h           ; the UTF-8 names of the USB folders we are in (4 levels x 44 bytes): 13 ASCII bytes (as in the list), length, up to 30 bytes
vu_dep  equ     DPS+180h
vu_cur  equ     DPS+183h
UM_REC  equ     DPS+300h
vc_item equ     DPS+192h        ; vc.asm: the item number of the entry being opened
VC_CAPS equ     DPS+18Eh        ; vc.asm: capabilities byte of IDENT (bit 2 = text drawing)

        org     VKBASE
        include "mainsyms.inc"
        include "vcsyms.inc"
        jp      vk_draw                 ; +0
        jp      vk_err                  ; +3
        jp      vk_title                ; +6
        jp      vk_fn                   ; +9
        jp      vk_path                 ; +12
        jp      vk_mach                 ; +15
        jp      vk_fall                 ; +18
        jp      vk_mv                   ; +21
        jp      vk_name                 ; +24
        jp      vk_info                 ; +27

vk_draw:ld      a,(VC_CAPS)             ; CY = nothing drawn (the ASCII path draws the name with "?")
        and     4
        jp      z,vk_no
        ld      a,(br_host)
        or      a
        jp      z,vk_dos                ; DOS drive: the long name comes from the sound port block (LFN)
        ld      de,13
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      a,(hl)
        and     7Fh
        ld      d,a                     ; DE = item number of the entry
        call    vk_gn
        jp      c,vk_no
        jp      vk_t0
; DE = item number -> NMBUF / vk_len = its UTF-8 name from the cartridge (LIST of this one entry); CY = failed
vk_gn:  call    vc_nc                   ; kept by the list (vc.asm)
        or      a
        jr      z,vk_g1
        ld      (vk_len),a
        ret
vk_g1:  ld      a,24h
        call    vx_cmd                  ; LIST: this one entry (USB commands: the command first, then the parameters)
        ld      a,e
        call    vx_par
        ld      a,d
        call    vx_par
        ld      a,1
        call    vx_par
        call    br_filt                 ; the same filter as vc.asm used for the list (the item numbers count the filtered list)
vk_f:   call    vx_par
        call    vx_st
        bit     3,a
        jp      nz,vk_ge
        call    vx_rd                   ; total (2 bytes)
        call    vx_rd
        call    vx_rd                   ; entries in this answer
        or      a
        jp      z,vk_ge
        call    vx_rd                   ; flags
        call    vx_rd                   ; kind
        ld      b,4
vk_s:   call    vx_rd                   ; size
        djnz    vk_s
        call    vx_rd                   ; name length
        cp      101
        jp      nc,vk_ge
        or      a
        jp      z,vk_ge
        ld      (vk_len),a
        ld      b,a
        ld      hl,NMBUF
vk_n:   call    vx_rd
        ld      (hl),a
        inc     hl
        djnz    vk_n
        or      a
        ret
vk_ge:  scf
        ret
; ---- the name is in NMBUF (vk_len bytes, UTF-8).  English letters etc. (bytes below 80h) are drawn with the list's own 6x8 font (gtext),
;      only runs of non-ASCII bytes (Korean, ...) go to the cartridge (TEXT 30h) and its bitmaps are copied behind them.
;      The x position runs from 14 (folders: after the "[") to at most 240; folders get a "]" at the end.
vk_t0:  ld      a,(vk_nm)               ; vk_name (SCREEN 6 look): only the name is wanted
        or      a
        jr      z,vt_go
        ld      hl,NMBUF
        ld      a,(vk_len)
        ld      c,a
        ld      b,0
        add     hl,bc
        ld      (hl),b
        or      a
        ret
vt_go:  ld      hl,NMBUF
        ld      a,(vk_len)
        ld      c,a
        ld      b,0
        add     hl,bc
        ld      (hl),b                  ; terminator behind the name
        ld      hl,NMBUF
        ld      (vk_p),hl
        ld      a,c
        ld      (vk_r),a
        xor     a
        ld      (vk_stop),a
        ld      a,(vk_tm)
        or      a
        jr      z,vt_li
        cp      2
        jr      z,vt_lp                 ; the path line: x after "USBn:\" (vk_xp, vk_lim set by vk_path)
        ld      a,32                    ; title in the top bar of the play screen: x 32, no brackets (vk_lim from vk_title)
        ld      (vk_xp),a
        jr      vt_lp
vt_li:  ld      a,240                   ; list entry: x 14 (folders: after the "["), up to x 240
        ld      (vk_lim),a
        ld      a,14
        ld      (vk_xp),a
        ld      a,(bl_ty)               ; folders: "[" first
        cp      2
        jr      z,vt_lp
        call    vk_y8
        ld      e,14
        ld      hl,vk_lb
        call    gtextf
        ld      a,(gt_x)
        ld      (vk_xp),a
vt_lp:  ld      a,(vk_r)
        or      a
        jp      z,vt_end
        ld      a,(vk_xp)
        ld      hl,vk_lim
        cp      (hl)
        jp      nc,vt_end
        ld      hl,(vk_p)
        ld      a,(hl)
        cp      80h
        jp      nc,vt_k
        ld      c,0                     ; ---- a run of ASCII bytes: C = its length
        ld      a,(vk_r)
        ld      b,a
vt_a:   ld      a,(hl)
        cp      80h
        jr      nc,vt_a1
        inc     hl
        inc     c
        djnz    vt_a
vt_a1:  ld      a,(vk_xp)
        ld      d,a
        ld      a,(vk_lim)
        sub     d                       ; room in pixels
        ld      e,0
vt_c:   sub     6
        jr      c,vt_c1
        inc     e
        jr      vt_c
vt_c1:  ld      a,e                     ; E = characters that surely fit (6 pixels each at most)
        cp      c
        jr      nc,vt_c2
        ld      c,a
        ld      a,1
        ld      (vk_stop),a             ; cut: nothing more after this run
vt_c2:  ld      a,c
        or      a
        jp      z,vt_end
        ld      hl,(vk_p)
        ld      b,0
        add     hl,bc                   ; HL = end of the run
        ld      a,(hl)
        ld      (vk_sv),a
        ld      (hl),b                  ; temporary terminator
        push    hl
        push    bc
        call    vk_y8
        ld      a,(vk_xp)
        ld      e,a
        ld      hl,(vk_p)
        call    gtextf
        pop     bc
        pop     hl
        ld      a,(vk_sv)
        ld      (hl),a
        ld      a,(gt_x)
        ld      (vk_xp),a
        ld      (vk_p),hl
        ld      a,(vk_r)
        sub     c
        ld      (vk_r),a
        ld      a,(vk_stop)
        or      a
        jp      nz,vt_end
        jp      vt_lp
vt_k:   ld      c,0                     ; ---- a run of bytes from 80h up (UTF-8 multi-byte characters): C = its length
        ld      a,(vk_r)
        ld      b,a
vt_k1:  ld      a,(hl)
        cp      80h
        jr      c,vt_k2
        inc     hl
        inc     c
        djnz    vt_k1
vt_k2:  ld      a,c
        ld      (vk_nn),a
        ld      a,30h
        call    vx_cmd                  ; TEXT: code 0 = UTF-8, height 9, width limit, length, the bytes
        xor     a
        call    vx_par
        ld      a,9
        call    vx_par
        ld      a,(vk_xp)
        ld      d,a
        ld      a,(vk_lim)
        sub     d
        call    vx_par                  ; width limit = the room left
        xor     a
        call    vx_par
        ld      a,(vk_nn)
        call    vx_par
        ld      a,(vk_nn)
        ld      b,a
        ld      hl,(vk_p)
vt_t:   ld      a,(hl)
        inc     hl
        call    vx_par
        djnz    vt_t
        call    vx_st
        bit     3,a
        jp      nz,vt_end
        call    vx_rd                   ; bytes used
        ld      (vk_u),a
        call    vx_rd                   ; characters drawn
        call    vx_rd
        ld      (vk_w),a                ; width (below 256: the limit is)
        call    vx_rd
        call    vx_rd
        ld      (vk_h),a
        ld      a,(vk_w)
        or      a
        jp      z,vt_end
        add     a,7
        rrca
        rrca
        rrca
        and     1Fh
        ld      (vk_bpr),a              ; bytes per line
        ld      a,(vk_h)
        cp      11
        jp      nc,vt_end
        or      a
        jp      z,vt_end
        ld      d,a
        ld      hl,BMBUF
vk_r1:  ld      a,(vk_bpr)
        ld      b,a
vk_b:   call    vx_rd
        ld      (hl),a
        inc     hl
        djnz    vk_b
        dec     d
        jr      nz,vk_r1
        ld      a,(vk_xp)
        ld      (vk_x0),a
        call    vk_blit
        ld      a,(vk_xp)
        ld      hl,vk_w
        add     a,(hl)
        ld      (vk_xp),a
        ld      a,(vk_u)                ; the bytes the cartridge used
        or      a
        jp      z,vt_end
        ld      c,a
        ld      hl,(vk_p)
        ld      b,0
        add     hl,bc
        ld      (vk_p),hl
        ld      a,(vk_r)
        sub     c
        ld      (vk_r),a
        ld      a,(vk_nn)               ; fewer bytes used than sent: out of room
        cp      c
        jp      nz,vt_end
        jp      vt_lp
vt_end: ld      a,(vk_tm)
        or      a
        jr      nz,vk_ok
        ld      a,(bl_ty)               ; folders: "]" after the name
        cp      2
        jr      z,vk_ok
        ld      a,(vk_xp)
        cp      245
        jr      nc,vk_ok
        call    vk_y8
        ld      a,(vk_xp)
        ld      e,a
        ld      hl,vk_rb
        call    gtextf
vk_ok:  or      a
        ret
vk_no:  scf
        ret
; copy the bitmap in BMBUF (vk_h lines of vk_bpr bytes) ORed to the list entry at x = vk_x0, from the line 3 of the entry
vk_blit:call    vk_y8
        ld      a,d
        dec     a                       ; the bitmap starts one line above the 8 pixel glyphs
        ld      (vk_y),a
        ld      a,(vk_h)
        ld      (vk_cn),a
        ld      hl,BMBUF
vk_ln:  ld      a,(vk_y)
        ld      c,a
        rrca
        rrca
        rrca
        and     1Fh
        add     a,BUF/256
        ld      d,a                     ; D = page of the tile row
        ld      a,c
        and     7
        ld      c,a                     ; C = line in the cell
        ld      a,(vk_x0)
        ld      b,a
        and     0F8h
        add     a,c
        ld      e,a                     ; E = pattern byte of the first cell, this line
        ld      a,b
        and     7
        ld      c,a                     ; C = bit shift
        ld      a,(vk_bpr)
        ld      b,a
vk_by:  push    bc
        ld      a,(hl)
        inc     hl
        push    hl
        ld      h,a
        ld      l,0
        ld      a,c
        or      a
        jr      z,vk_s0
vk_sh:  srl     h
        rr      l
        dec     a
        jr      nz,vk_sh
vk_s0:  ld      a,(de)
        or      h
        ld      (de),a
        ld      a,e
        add     a,8
        ld      e,a
        ld      a,(de)
        or      l
        ld      (de),a
        pop     hl
        pop     bc
        djnz    vk_by
        ld      (vk_rp),hl              ; next line of the bitmap
        ld      a,(vk_y)
        inc     a
        ld      (vk_y),a
        ld      hl,vk_cn
        dec     (hl)
        ld      hl,(vk_rp)
        jr      nz,vk_ln
        ret
vk_y8:  ld      a,(vk_tm)               ; title: D = 8, path line: D = 20
        or      a
        jr      z,vy_l
        cp      2
        ld      d,8
        ret     nz
        ld      d,20
        ret
vy_l:
        ld      a,(bl_y)                ; D = y of an 8 pixel glyph in the middle of the entry
        add     a,a
        add     a,a
        add     a,a
        add     a,4
        ld      d,a
        ret
; ---- DOS drive entry: HL = record + 1 (the 8.3 name).  The sound cartridge (ports 2Ch-2Fh) gives the long name as UTF-8:
;      07h LFN_PATH (the path "\folder\NAME.EXT" ends with 00h), 0Dh LFN_READ_UTF8 -> length, bytes.  IDENT 5th byte bit 3 says it exists.
;      A long name that differs from the 8.3 name is drawn like a USB name (vk_t0); otherwise CY (the 8.3 name is drawn by the list).
vk_dos: ld      a,(bl_ty)
        or      a
        jp      z,vk_no                 ; ".."
        ld      a,(vk_lf)
        or      a
        jr      nz,vkd_c
        push    hl
        call    vk_lfdet
        ld      (vk_lf),a
        pop     hl
vkd_c:  cp      1
        jp      nz,vk_no
        push    hl
        ld      c,59h                   ; _GETCD: the current folder of the current drive
        ld      b,0
        ld      de,BMBUF
        call    5
        ld      hl,BMBUF                ; the path must fit into the 79 characters of LFN_PATH: "\" + folder (at most 61) + "\" + 8.3 name
        ld      b,0
vkd_l:  ld      a,(hl)
        or      a
        jr      z,vkd_k
        inc     hl
        inc     b
        jr      vkd_l
vkd_k:  ld      a,b
        cp      62
        jr      nc,vkd_x
        ld      a,7
        call    vl_cmd                  ; LFN_PATH
        ld      a,5Ch
        call    vl_wr
        ld      hl,BMBUF
        ld      a,(hl)
        or      a
        jr      z,vkd_n
vkd_p:  ld      a,(hl)
        call    vl_wr
        inc     hl
        ld      a,(hl)
        or      a
        jr      nz,vkd_p
        ld      a,5Ch
        call    vl_wr
vkd_n:  pop     hl
        push    hl
vkd_s:  ld      a,(hl)
        or      a
        jr      z,vkd_e
        call    vl_wr
        inc     hl
        jr      vkd_s
vkd_e:  xor     a
        call    vl_wr
        ld      a,0Dh
        call    vl_cmd                  ; LFN_READ_UTF8
        call    vl_rd                   ; length (0 = no long name)
        or      a
        jr      z,vkd_x
        cp      101
        jr      nc,vkd_x
        ld      (vk_len),a
        ld      b,a
        ld      hl,NMBUF
vkd_r:  call    vl_rd
        ld      (hl),a
        inc     hl
        djnz    vkd_r
        pop     de                      ; DE = the 8.3 name: the same name?  then nothing to draw (a lower case 8.3 name does differ: the cartridge gives it as a long name)
        ld      hl,NMBUF
        ld      a,(vk_len)
        ld      b,a
vkd_q:  ld      a,(de)
        or      a
        jr      z,vkd_d
        cp      (hl)
        jr      nz,vkd_d
        inc     de
        inc     hl
        djnz    vkd_q
        ld      a,(de)
        or      a
        jp      z,vk_no
vkd_d:  jp      vk_t0
vkd_x:  pop     hl
        jp      vk_no
; A = 1: the sound cartridge has LFN_READ_UTF8, 2: not
vk_lfdet:
        xor     a
        call    vl_cmd                  ; IDENT
        ld      hl,vk_sg
        ld      b,4
vld_l:  call    vl_rd
        cp      (hl)
        jr      nz,vld_n
        inc     hl
        djnz    vld_l
        call    vl_rd                   ; 5th byte: bit 3 = LFN_READ_UTF8
        and     8
        jr      z,vld_n
        ld      a,1
        ret
vld_n:  ld      a,2
        ret
vk_sg:  defb    "MVS",1
vk_lf:  defb    0                       ; 0 unknown, 1 LFN_READ_UTF8 there, 2 not
vl_cmd: out     (2Ch),a
        ret
vl_wr:  out     (2Dh),a
        ret
vl_rd:  in      a,(2Dh)
        ret
; A = error code of the cartridge's OPEN (video 25h) -> DE = message for the list's note line (unknown code: the general "cannot open" message)
vk_err: ld      de,m_open
        or      a
        ret     z
        cp      8
        ret     nc
        ld      b,a
        ld      a,(vk_mvf)              ; an MV5..MVC file: its own notes for 4 and 6
        or      a
        jr      z,vke_n
        ld      a,b
        ld      de,vk_m4
        cp      4
        ret     z
        ld      de,vk_m6
        cp      6
        ret     z
vke_n:  ld      de,vk_e1
        dec     b
        ret     z
vke_l:  ld      a,(de)
        inc     de
        or      a
        jr      nz,vke_l
        djnz    vke_l
        ret
vk_e1:  defb    "Cannot read the file",0
        defb    "No video track",0
        defb    "Codec not supported",0
        defb    "Profile or size not supported",0
        defb    "MP4 decoder not ready",0
        defb    "SCREEN cannot play MP4",0
        defb    "Fragmented MP4 not supported",0
vk_m4:  defb    "File type and extension differ",0
vk_m6:  defb    "Needs better VDP or more VRAM",0
; ---- the title in the top bar of the play screen (called by ui_top): the entry's own name when it is not plain 8.3 ASCII
;      CY = nothing drawn: ui_top draws the 12 character ASCII title as before.  Only in the browser (fname = the record name).
vk_title:
        ld      a,(br_on)
        or      a
        jp      z,vk_no
        ld      a,(VC_CAPS)
        and     4
        jp      z,vk_no
        ld      a,(show_fps)            ; the FPS number is at x 136
        or      a
        ld      a,205
        jr      z,vtt_l
        ld      a,130
vtt_l:  ld      (vk_lim),a
        ld      a,1
        ld      (vk_tm),a
        ld      hl,(fname)
        ld      a,(br_host)
        or      a
        jr      z,vtt_d
        cp      2
        jr      nz,vtt_x
        ld      de,14                   ; USB: only names with the "long / non-ASCII" mark
        add     hl,de
        bit     7,(hl)
        ld      hl,(fname)
        jr      z,vtt_x
        call    vk_draw
        jr      vtt_e
vtt_d:  ld      a,2                     ; DOS: the long name from the sound port block
        ld      (bl_ty),a
        call    vk_draw
        jr      vtt_e
vtt_x:  scf
vtt_e:  ld      a,0                     ; (keeps the carry)
        ld      (vk_tm),a
        ret
; ---- the path line of the list ("USBn:\folder"): the name of the folder we are in, with Korean letters
; vk_fn (called by vc.asm before CD, HL = the item number): remember the UTF-8 name of the folder we are going to enter (slot = depth - 1)
vk_fn:  ld      a,(VC_CAPS)
        and     4
        ret     z
        ld      a,(vu_dep)
        dec     a
        cp      4
        ret     nc
        ld      (vk_si),a
        ex      de,hl
        call    vk_gn
        push    af                      ; carry = the name could not be read
        ld      a,(vk_si)
        ld      hl,FNC
        ld      de,44
vf_m:   or      a
        jr      z,vf_d
        add     hl,de
        dec     a
        jr      vf_m
vf_d:   push    hl
        ld      de,13
        add     hl,de
        ld      (hl),0                  ; length 0: nothing for the path line
        pop     hl
        pop     af
        ret     c
        ld      a,(vk_len)              ; a plain short ASCII name needs nothing
        cp      13
        jr      nc,vf_s
        ld      b,a
        ld      de,NMBUF
vf_c:   ld      a,(de)
        cp      80h
        jr      nc,vf_s
        cp      20h
        jr      c,vf_s
        inc     de
        djnz    vf_c
        ret
vf_s:   ex      de,hl                   ; DE = slot
        ld      hl,NMBUF
        ld      a,(vk_len)
        ld      c,a
        ld      b,12
vf_a:   ld      a,c
        or      a
        jr      z,vf_p
        dec     c
        ld      a,(hl)
        inc     hl
        cp      20h
        jr      c,vf_q
        cp      7Fh
        jr      c,vf_w
vf_q:   ld      a,'?'
vf_w:   ld      (de),a
        inc     de
        djnz    vf_a
        jr      vf_z
vf_p:   xor     a
vf_p2:  ld      (de),a
        inc     de
        djnz    vf_p2
vf_z:   xor     a
        ld      (de),a                  ; the 13th byte
        inc     de
        push    de                      ; the length byte
        inc     de                      ; DE = the UTF-8 bytes
        ld      a,(vk_len)
        cp      31
        jr      c,vf_k
        ld      a,30
vf_k:   ld      c,a
        ld      a,(vk_len)
        cp      c
        jr      z,vf_cp                 ; the whole name fits
vf_b:   ld      a,c
        or      a
        jr      z,vf_cp
        ld      hl,NMBUF
        ld      b,0
        add     hl,bc
        ld      a,(hl)
        and     0C0h
        cp      80h
        jr      nz,vf_cp                ; do not cut inside a character
        dec     c
        jr      vf_b
vf_cp:  pop     hl
        ld      (hl),c
        ld      a,c
        or      a
        ret     z
        ld      b,0
        ld      hl,NMBUF
        ldir
        ret
; vk_path (called by the list header for a USB drive after br_upath): CY = not drawn (the header draws the ASCII path)
vk_path:ld      a,(VC_CAPS)
        and     4
        jp      z,vk_no
        ld      a,(vu_dep)
        sub     2
        jp      c,vk_no
        cp      4
        jp      nc,vk_no
        ld      (vk_si),a
        ld      hl,FNC
        ld      de,44
vp_m:   or      a
        jr      z,vp_d
        add     hl,de
        dec     a
        jr      vp_m
vp_d:   push    hl                      ; the slot
        ld      de,13
        add     hl,de
        ld      a,(hl)
        or      a
        jr      z,vp_x                  ; no Korean name remembered
        ld      a,(vu_cur)              ; the ASCII name of that level in the drive's memory record (as br_upath reads it)
        dec     a
        cp      8
        jr      nc,vp_x
        ld      hl,UM_REC+15
        ld      de,80
vp_r:   or      a
        jr      z,vp_r2
        add     hl,de
        dec     a
        jr      vp_r
vp_r2:  ld      a,(vk_si)
        ld      de,13
vp_l:   or      a
        jr      z,vp_c
        add     hl,de
        dec     a
        jr      vp_l
vp_c:   pop     de                      ; DE = slot, HL = the ASCII name
        push    de
        ld      b,13
vp_q:   ld      a,(de)
        cp      (hl)
        jr      nz,vp_x                 ; another folder than the one remembered
        inc     de
        inc     hl
        djnz    vp_q
        pop     hl                      ; slot
        ld      de,13
        add     hl,de
        ld      c,(hl)                  ; length
        ld      a,c
        ld      (vk_len),a
        inc     hl
        ld      de,NMBUF
        ld      b,0
        ldir
        ld      a,(vu_cur)
        add     a,'0'
        ld      (vk_pf+3),a
        ld      a,2
        ld      (vk_tm),a
        ld      a,170                   ; "SORT NAME" starts at x 176
        ld      (vk_lim),a
        ld      d,20
        ld      e,6
        ld      hl,vk_pf
        call    gtextf
        ld      a,(gt_x)
        ld      (vk_xp),a
        call    vk_t0
        ld      a,0                     ; (keeps the carry)
        ld      (vk_tm),a
        ret
vp_x:   pop     hl
        jp      vk_no
vk_pf:  defb    "USB0:",5Ch,0
vk_si:  defb    0
; ---- the machine: which SCREENs an MP4 can use (vc_scrtab index: 0 = 5, 1 = 6, 2 = 7, 3 = 8, 4 = 10, 5 = 11, 6 = 12)
; vk_mach (called by vdp_id, A = vdplv: 1 = V9938, 2 = V9958 or later) sets vmask (the usable ones) and vsc (the best one)
;   V9938 with 64KB VRAM: 5, 6 (best 5);  V9938 with 128KB: 5..8 (best 8);  V9958: 5..8, 10..12 (best 12)
vk_mach:cp      2
        jr      nc,vm_58
        call    vk_v128                 ; A = 1: the VRAM has 128KB
        or      a
        ld      a,3
        ld      e,0
        jr      z,vm_set
        ld      a,0Fh
        ld      e,3
        jr      vm_set
vm_58:  ld      a,7Fh
        ld      e,6
vm_set: ld      (vmask),a
        ld      a,e
        ld      (vsc),a
        ret
; A = 1 when the VRAM is 128KB: a byte written to the VRAM address 10000h shows up at 0000h on a 64KB machine (A16 is ignored)
vk_v128:di
        xor     a
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a               ; R#14 = 0
        xor     a
        out     (VDP_C),a
        ld      a,40h
        out     (VDP_C),a               ; write at 0000h
        ld      a,55h
        ex      (sp),hl                 ; VDP access time (as the BIOS does)
        ex      (sp),hl
        out     (VDP_D),a
        ld      a,4
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a               ; R#14 = 4: the VRAM address bit 16
        xor     a
        out     (VDP_C),a
        ld      a,40h
        out     (VDP_C),a
        ld      a,0AAh
        ex      (sp),hl                 ; VDP access time (as the BIOS does)
        ex      (sp),hl
        out     (VDP_D),a               ; write at 10000h
        xor     a
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a               ; R#14 = 0
        xor     a
        out     (VDP_C),a
        out     (VDP_C),a               ; read from 0000h
        ex      (sp),hl                 ; VDP access time (as the BIOS does)
        ex      (sp),hl
        in      a,(VDP_D)
        ei
        cp      0AAh
        ld      a,1
        ret     nz
        xor     a
        ret
; vk_fall (called by vc.asm after a failed OPEN, A = the error code): code 6 on SCREEN 10..12 -> SCREEN 8 and CY (open again)
vk_fall:cp      6
        jr      z,vfa_6
        or      a
        ret
vfa_6:  ld      a,(vk_mvf)              ; an MV5..MVC file has its own SCREEN: no retry
        or      a
        jr      nz,vfa_n
        ld      a,(vsc)
        cp      4
        jr      c,vfa_n
        cp      7
        jr      nc,vfa_n                ; V1.11.15: V9990 (13 / 14): no silent retry on SCREEN 8, the note shows why the cartridge refused
        ld      a,3
        ld      (vsc),a
        ld      a,6
        scf
        ret
vfa_n:  ld      a,6
        or      a
        ret
; vk_mv (called by vc.asm before the OPEN): A = 3rd letter of ".MV?" (0 = not an MV name), C = SCREEN of the setting -> C = P4 to send
;   MV2 = 2; with the cartridge's USB MV5..MVC bit (caps bit 4): '5'..'8' = 5..8, 'A'..'C' = 10..12.  vk_mvf = 1 for those (errors 4 / 6 get MV notes, no SCREEN 8 retry)
vk_mv:  ld      b,a
        ld      a,(br_host)
        cp      2
        jr      nz,vmv_n
        push    bc                      ; V1.11.7: keep C (the SCREEN for P4): the name request and the counter below use C
        ld      de,(vc_item)            ; USB: the record keeps only the first 12 characters, so a long name has lost its ".MV?":
        call    vk_gn                   ; ask the cartridge for the full name of this item and take the extension from its end
        jr      c,vmv_g
        ld      a,(vk_len)              ; (NMBUF + 100 does not carry out of the low byte)
        ld      hl,NMBUF-1
        add     a,l
        ld      l,a
        ld      b,(hl)                  ; the 3rd letter
        ld      de,vmv_t
        ld      c,3
vmv_c:  dec     hl
        ld      a,(de)
        inc     de
        xor     (hl)
        and     0DFh                    ; any case
        jr      nz,vmv_g
        dec     c
        jr      nz,vmv_c
        pop     de                      ; .MV?: B stays the 3rd letter, C = the SCREEN again
        ld      c,e
        jr      vmv_n
vmv_g:  pop     bc
        ld      b,0                     ; not .MV?
vmv_n:  xor     a
        ld      (vk_mvf),a
        ld      a,b
        or      a
        ret     z                       ; not .MV?: C stays
        ld      c,2                     ; MV2
        ld      a,(VC_CAPS)
        and     10h
        ret     z                       ; no MV5..MVC from USB
        ld      a,b
        cp      '2'
        ret     z
        cp      3Ah
        jr      c,vmv_d
        and     0DFh
        sub     37h                     ; A..C = 10..12
        jr      vmv_s
vmv_d:  sub     30h                     ; 5..8
vmv_s:  ld      c,a
        ld      a,1
        ld      (vk_mvf),a
        ret
vk_mvf: defb    0
; vk_info (called by vc.asm after a successful OPEN): HL = the length of the file in 1/15 s (INFO), asked again (one frame apart, up to 1.5 s) while it is 0:
;   the cartridge may need a moment to read the header of a file on a USB drive.  HL = 0 when it stays 0.
vk_info:ld      b,90
vki_l:  push    bc
        ld      a,08h
        call    vx_cmd
        call    vx_rd
        ld      l,a
        call    vx_rd
        ld      h,a
        pop     bc
        or      l
        ret     nz
        halt
        djnz    vki_l
        ret
vmv_t:  defb    "VM."
; vk_name (SCREEN 6 look): HL = record + 1, bl_ty = its type -> NC: the UTF-8 name is in NMBUF (ASCIIZ), CY: no long name
vk_name:ld      a,1
        ld      (vk_nm),a
        call    vk_draw
        push    af
        xor     a
        ld      (vk_nm),a
        pop     af
        ret
vk_nm:  defb    0
vk_lb:  defb    "[",0
vk_rb:  defb    "]",0
vk_len: defb    0
vk_w:   defb    0
vk_h:   defb    0
vk_bpr: defb    0
vk_x0:  defb    0
vk_y:   defb    0
vk_cn:  defb    0
vk_rp:  defw    0
vk_p:   defw    0
vk_xp:  defb    0
vk_r:   defb    0
vk_stop:defb    0
vk_sv:  defb    0
vk_nn:  defb    0
vk_tm:  defb    0                       ; 1 while the title is drawn (not a list entry)
vk_lim: defb    240                     ; the name is drawn up to this x
vk_u:   defb    0
vk_end:
        defs    VKBASE+VKLEN-vk_end     ; (fails if the module outgrew VKLEN)
