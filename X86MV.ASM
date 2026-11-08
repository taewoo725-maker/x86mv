; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
; ============================================================
;  X86MV.COM  -  MV2 player (video only)  for MSX-DOS2 / Nextor, MSX2 or later
;  MV2 = SCREEN 2 (256x192) frames, 15 fps, 16384 bytes/frame
;  frame: pattern 6144 | color 6144 | palette 30 (colors 1..15) | ...
;  build: pasmo --bin x86mv.asm x86mv.com x86mv.sym
; ============================================================
        org     0100h
        include "stamp.inc"             ; V1.11.21: BSTAMP = the build stamp the modules must carry at their last two bytes (see mod_load)

BDOS    equ     0005h
VDP_D   equ     98h
VDP_C   equ     99h
VDP_P   equ     9Ah
PPI_A   equ     0A9h
PPI_C   equ     0AAh
JIFFY   equ     0FC9Eh
SCRMOD  equ     0FCAFh
RG9SAV  equ     0FFE8h
EXPTBL  equ     0FCC1h
CALSLT  equ     001Ch
RDSLT   equ     000Ch
PSG_A   equ     0A0h
PSG_D   equ     0A1h
PCM_D   equ     0A4h
PCM_C   equ     0A5h
CP_C    equ     2Ch             ; X86MV sound cartridge (X86MSX): command / status
CP_D    equ     2Dh             ;   MP3 data in / identification out
CP_L    equ     2Eh             ;   parameter low / position low
CP_H    equ     2Fh             ;   parameter high / position high
LEADMAX equ    16              ; most frames `lead` may reach
CLEAD   equ     8               ; send MP3 pieces this many frames ahead of the playing position
LINE_END equ    224             ; line interrupts only on lines 4..LINE_END-1 (lines beyond ~233 do not exist)
VTAB    equ     2800h           ; volume tables (page aligned, 2800h-3FFFh, just below RING)
RING    equ     4000h           ; audio ring buffer 4000h-4FFFh (4 KB, wrap: H = 40h | (H & 0Fh)); also the MP3 piece buffer in cartridge mode
CHGMOD  equ     005Fh

BUF     equ     8000h           ; frame buffer 8000h-BFFFh
FRMSZ   equ     4000h           ; bytes per frame (16384)
FRDSZ   equ     3200h           ; bytes of a frame the player needs: pattern, color, palette (12800 = 25 sectors); the MP3 piece is read by its own handle
OVB     equ     0C000h          ; overlay cache: the 8 overlay tile rows (0-2, 19-23) as rendered, 2 KB pattern + 2 KB color; only if the TPA reaches 0D000h
fontc   equ     BUF+3200h       ; Galmuri7 6x8 glyphs (96 x 8 bytes), then the advance widths (96 bytes): BUF is only read up to 3200h
fontw   equ     fontc+768
FONTSZ  equ     864
PALOFS  equ     3000h           ; palette offset in frame
BMBASE  equ     0B560h          ; X86 Video cartridge client (vc.asm): image carried behind the font, copied here at start
BMLEN   equ     0AA0h
VC_DETECT equ   BMBASE
VC_LIST equ     BMBASE+3
VC_PLAYH equ    BMBASE+6
VC_FRAME equ    BMBASE+9
VC_REDRAW equ   BMBASE+12
VC_SEEK equ     BMBASE+15
VC_PAUSE equ    BMBASE+18
VC_RESUME equ   BMBASE+21
VC_STOP equ     BMBASE+24
VC_VOL  equ     BMBASE+27
VC_UP   equ     BMBASE+30
VC_RET  equ     BMBASE+33
VC_ENTER equ    BMBASE+36
VC_RUN  equ     BMBASE+39
VC_ADDHOST equ  BMBASE+42
VC_POP  equ     BMBASE+45       ; drive popup (D key, BS at the top)
VC_KEYD equ     BMBASE+48       ; A = new press of the D key
VC_PLAYD equ    BMBASE+51       ; vc.asm: an MP4 of the MSX disk is played by the cartridge
VU_DEP  equ     7180h           ; vc.asm data (DPS = 7000h): USB folder level, selected drive, per-drive memory records of 80 bytes
VU_CUR  equ     7183h
UM_REC  equ     7300h
VKBASE  equ     7600h           ; vk.asm (names the cartridge draws, Korean): image behind vc.bin, copied here at start
VKLEN   equ     0780h
VK_DRAW equ     VKBASE
VK_TITLE equ    VKBASE+6
VK_PATH equ     VKBASE+12
VK_MACH equ     VKBASE+15
COLOFS  equ     1800h           ; color table offset (in 256-byte blocks: 6144)

; ------------------------------------------------------------
start:
        ld      (sp0),sp
        ld      hl,fontsrc      ; the Galmuri7 glyphs travel in the program image behind the volume tables (4000h, the audio ring
        ld      de,fontc        ; area, free until the sound starts) and are copied to the unused tail of the frame buffer once
        ld      bc,FONTSZ
        ldir
        ld      hl,vcsrc        ; the X86 Video client module
        ld      de,BMBASE
        ld      bc,BMLEN
        ldir
        ld      hl,vksrc        ; the Korean name module
        ld      de,VKBASE
        ld      bc,VKLEN
        ldir
        call    VC_DETECT       ; X86 Video cartridge present?
        ld      a,0
        jr      c,st_nv
        inc     a
st_nv:  ld      (vcpres),a
        ld      a,(0007h)       ; TPA top (high byte)
        cp      0C0h
        jp      c,e_mem

        ; ---- MSX-DOS2 / Nextor needed (handle file functions) ----
        ld      bc,0
        ld      de,0
        ld      hl,0
        ld      ix,0
        ld      c,6Fh           ; _DOSVER: DOS2 returns A=0, B>=2; DOS1 leaves B=0
        call    BDOS
        or      a
        jp      nz,e_dos1
        ld      a,b
        cp      2
        jp      c,e_dos1

        ; ---- machine generation (MSXVER at main ROM 002Dh) ----
        ld      a,(EXPTBL)
        ld      hl,002Dh
        call    RDSLT
        ei
        ld      (gen),a
        or      a
        jp      z,e_msx1        ; MSX1 = TMS9918: no ID register, do not touch it
        call    vdp_id          ; VDP level for the SCREEN limits (1 = V9938, 2 = V9958)
        cp      3
        call    z,cpu_r800      ; turbo R (and GT): run on the R800 (the Z80 needs ~70 ms to write one frame)

        ; ---- command line ----
        ld      hl,0080h
        ld      a,(hl)
        or      a
        jp      z,br_noarg
        ld      c,a
        ld      b,0
        inc     hl
        push    hl
        add     hl,bc
        ld      (hl),0
        pop     hl
skipsp: ld      a,(hl)
        cp      ' '
        jr      nz,sk1
        inc     hl
        jr      skipsp
sk1:    or      a
        jp      z,br_noarg
        ld      (fname),hl
tok:    ld      a,(hl)
        or      a
        jr      z,tokend
        cp      ' '
        jr      z,tokend
        inc     hl
        jr      tok
tokend: ld      (hl),0
        xor     a
        ld      (br_on),a
playfile:
        ld      a,(br_host)
        or      a
        jp      nz,VC_PLAYH     ; an entry of the X86 Video library (the cartridge reads the file)
        call    play_reset
        ld      hl,(fname)              ; a disk file named *.MP4 / .M4V / .MOV / .AVI: the X86 Multimedia cartridge plays it (caps bit 5), else a note
        call    ext_cls
        cp      2
        jr      nz,pm_no
        ld      a,(vcpres)
        or      a
        ld      de,m_nocart
        jp      z,err
        ld      a,(VC_CAPS)             ; caps bit 5: the cartridge opens a file of the MSX disk
        and     20h
        jp      nz,VC_PLAYD
        ld      de,m_mp4lib
        jp      err
pm_no:
        ; ---- open ----
        ld      de,(fname)
        ld      a,01h           ; read only
        ld      c,43h           ; _OPEN
        call    BDOS
        or      a
        jp      nz,e_open
        ld      a,b
        ld      (handle),a

        ; ---- header ----
        call    fread
        jp      c,e_fmt
        ld      hl,BUF
        ld      de,magic
        ld      b,8
chk:    ld      a,(de)
        cp      (hl)
        jp      nz,e_fmt
        inc     hl
        inc     de
        djnz    chk
        ld      hl,(BUF+18h)
        ld      a,h
        or      l
        jr      nz,hdr_n
        call    size_frames     ; some MV2 files have 0 here: the frame count is the file size / 16384 - 1
        jp      c,e_fmt
        jr      hdr_ok
hdr_n:  ld      (nframes),hl
hdr_ok:

        ; ---- which SCREEN does this file need, and can this machine do it? ----
        ld      a,(BUF+11h)     ; header version "v2.00" -> format digit
        ld      b,a
        ld      hl,fmttab
ft1:    ld      a,(hl)
        or      a
        jp      z,m8_load       ; not MV2: the module X86MV8.OVL knows the other formats (MV5-MVC) or says "not supported"
        cp      b
        jr      z,ft2
        inc     hl
        inc     hl
        inc     hl
        jr      ft1
ft2:    inc     hl
        ld      a,(hl)
        ld      (smode),a       ; SCREEN number of the file
        inc     hl
        ld      b,(hl)          ; minimum VDP level (1 = V9938, 2 = V9958)
        ld      a,(vdplv)
        cp      b
        jp      c,e_gen


        ; ---- sound: X86MV sound cartridge (X86MSX) first, else the optional companion NAME.MVA ----
        call    cart_detect
        jr      c,st_aud
        ld      a,1
        ld      (cart_on),a
        jr      st_snd
st_aud: call    audio_open
        ld      a,(aud_on)
        or      a
        call    z,msg_nosnd     ; no cartridge and no MVA: say why it is silent
st_snd:

        ; ---- screen ----
        call    vdp_init
        ld      hl,0
        ld      (fpos),hl
        ld      hl,0FFFFh
        ld      (cur),hl
        ld      hl,(JIFFY)
        ld      (t0),hl
        call    audio_start
        call    cart_start

; ------------------------------------------------------------
mloop:  call    keys
        call    keys_s
        ld      a,(redraw)
        or      a
        call    nz,redraw_frame
        ld      a,(paused)
        or      a
        jr      z,run
        ld      a,(aud_on)
        ld      hl,vmode
        or      (hl)
        jp      nz,pz_dly       ; audio / X86 Video cartridge: the VDP interrupts may be off while paused, HALT would never wake
        halt
        jr      mloop
run:    ld      a,(vmode)
        or      a
        jp      nz,VC_RUN       ; X86 Video: the clock is the cartridge position
        ld      a,(cart_on)
        or      a
        jr      z,run_a
        ld      a,(cart_tail)
        or      a
        jr      nz,run_a        ; sound is over: the JIFFY clock finishes the last frames
        call    cart_refill
        call    c_pos           ; HL = frame number being heard (cartridge clock)
        call    cart_watch
        jr      gotidx
run_a:  ld      a,(aud_on)
        or      a
        jr      z,run_j
        call    refill
        call    audio_idx       ; HL = frame index from the audio clock
        jr      gotidx
run_j:  ld      hl,(JIFFY)
        ld      de,(t0)
        or      a
        sbc     hl,de           ; HL = ticks since start
        ld      a,(pal)
        or      a
        jr      nz,palidx
        srl     h               ; 60 Hz: idx = ticks / 4
        rr      l
        srl     h
        rr      l
        jr      gotidx
palidx: ld      d,h             ; 50 Hz: idx = ticks * 3 / 10
        ld      e,l
        add     hl,hl
        jp      c,done
        add     hl,de
        jp      c,done
        call    div10
gotidx: ld      b,h
        ld      c,l             ; BC = frame index due now
        ld      a,(vmode)       ; V1.11.11: the cartridge shows the pictures (fpos stays 0): its position alone runs the overlay's 3 s
        or      a
        jr      nz,gi_f
        ld      hl,(fpos)       ; no picture shown yet (slow start: reading, sound set-up): the overlay's 3 s start with the first picture
        ld      a,h
        or      l
        jr      nz,gi_f
        ld      (ui_last),bc
gi_f:   ld      a,(ui_vis)      ; overlay: hide after UIHIDE frames without a key
        or      a
        jr      z,gi_ok
        ld      h,b
        ld      l,c
        ld      de,(ui_last)
        or      a
        sbc     hl,de
        jr      nc,gi_a
        ld      (ui_last),bc    ; time went backwards (seek): restart the timer
        jr      gi_ok
gi_a:   ld      de,UIHIDE
        or      a
        sbc     hl,de
        jr      c,gi_ok
        xor     a
        ld      (ui_vis),a
gi_ok:
        ld      hl,(nframes)
        or      a
        sbc     hl,bc
        jp      z,ended
        jp      c,ended
        ; A/V sync on a slow machine: the picture appears about `lead` frames after this decision (reading + writing take that long),
        ; so show the frame that will be due then, not the one that is due now.
        ld      a,(lead)
        or      a
        jr      z,gl_n
        ld      e,a
        ld      d,0
        ld      h,b
        ld      l,c
        add     hl,de           ; HL = due + lead
        ex      de,hl
        ld      hl,(nframes)
        dec     hl
        or      a
        sbc     hl,de
        jr      nc,gl_c
        ld      de,(nframes)    ; never past the last frame
        dec     de
gl_c:   ld      b,d
        ld      c,e
gl_n:   ld      hl,(cur)
        or      a
        sbc     hl,bc
        jr      z,wait          ; already shown
        jr      c,gl_s          ; cur < frame: a newer frame is due
        ld      a,h             ; cur > frame: the lead shrank by a frame or two -> keep the picture; a real jump back (seek) shows
        or      a
        jr      nz,gl_s
        ld      a,l
        cp      LEADMAX+1
        jr      c,wait
gl_s:   ld      (cur),bc
        ld      hl,(JIFFY)
        ld      (fr_t0),hl      ; start of this frame's reading and drawing
        ld      hl,(cnt)
        ld      (fr_c0),hl      ; (NAME.MVA sound: the line interrupt counter is the clock)
        ld      a,(vmode)
        or      a
        jp      nz,VC_FRAME     ; X86 Video: the cartridge shows the frames; only the overlay is refreshed here
        ld      hl,(fpos)
        or      a
        sbc     hl,bc
        jr      z,rd            ; file pointer already at this frame
        call    fseek           ; skip frames (we are late)
        jp      c,done
rd:     call    fread
        jp      c,done
        call    refill          ; keep the audio ring topped up between the long steps
        call    cart_refill
        ld      hl,(fpos)
        inc     hl
        ld      (fpos),hl
        ld      hl,(dbg_shown)
        inc     hl
        ld      (dbg_shown),hl
        call    fps_tick
        ld      hl,(cur)
        ld      (dbg_last),hl
        call    ui_draw
        call    showframe
        call    lead_upd
        jp      mloop
wait:   halt
        jp      mloop

; measure how long this frame took (JIFFY ticks, the picture is on screen when showframe returns) and set `lead` = that many movie frames.
; The BIOS timer (JIFFY) does not run while the PSG/PCM line-interrupt audio owns the interrupt: then lead stays 0.
lead_upd:
        ld      a,(aud_on)
        or      a
        jr      nz,lead_aud
        ld      hl,(JIFFY)
        ld      de,(fr_t0)
        or      a
        sbc     hl,de
        ld      a,h
        or      a
        jr      z,lu_1
        ld      l,255
lu_1:   ld      a,(lead_t)      ; smoothed ticks: (3 * old + new + 2) / 4
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
        rr      l
        ld      a,l
        ld      (lead_t),a
        ld      h,0
        ld      a,(pal)
        or      a
        jr      nz,lu_5
        ld      de,2            ; 60 Hz: frames = (ticks + 2) / 4
        add     hl,de
        srl     h
        rr      l
        srl     h
        rr      l
        jr      lu_c
lu_5:   ld      d,h             ; 50 Hz: frames = (ticks * 3 + 5) / 10
        ld      e,l
        add     hl,hl
        add     hl,de
        ld      de,5
        add     hl,de
        call    div10
lu_c:   ld      a,l
        cp      LEADMAX+1
        jr      c,lu_s
        ld      a,LEADMAX
lu_s:   ld      (lead),a
        ret

; NAME.MVA sound (PSG / PCM): JIFFY does not run, the audio clock does.  Cost in samples = interrupts since the frame started (x2 for
; 2 samples per interrupt); smoothed like above; lead = samples / samples-per-frame, rounded.
lead_aud:
        ld      hl,(cnt)
        ld      de,(fr_c0)
        or      a
        sbc     hl,de
        ld      a,(aud_k)
        cp      2
        jr      nz,la_1
        add     hl,hl
la_1:   ld      de,(lead_s)     ; (3 * old + new + 2) / 4
        add     hl,de
        add     hl,de
        add     hl,de
        ld      de,2
        add     hl,de
        srl     h
        rr      l
        srl     h
        rr      l
        ld      (lead_s),hl
        ld      de,(aud_spf)    ; + half a frame, then count whole frames
        ld      b,h
        ld      c,l
        ld      h,d
        ld      l,e
        srl     h
        rr      l
        add     hl,bc
        ld      c,0
la_l:   or      a
        sbc     hl,de
        jr      c,la_d
        inc     c
        ld      a,c
        cp      LEADMAX
        jr      c,la_l
la_d:   ld      a,c
        cp      LEADMAX+1
        jr      c,la_s
        ld      a,LEADMAX
la_s:   ld      (lead),a
        ret

; paused with audio: poll the keys every ~32 ms
pz_dly: ld      de,32
pz1:    ld      b,0
pz2:    djnz    pz2
        dec     de
        ld      a,d
        or      e
        jr      nz,pz1
        jp      mloop


; ============================================================
;  X86MV sound cartridge (X86MSX): the MP3 pieces inside the MV2 frames go to the cartridge,
;  which plays them; the cartridge position (frame number) is the video clock.
;  Protocol: see X86MV_soundcart_request (ports 2Ch-2Fh).  A second handle on the MV2 file feeds it.
; ============================================================
; carry = no cartridge.  An empty bus reads FFh; a real status byte never has bits 6,5,4,2 set.
cart_detect:
        in      a,(CP_C)
        cp      0FFh
        jr      z,cd_no
        and     74h
        jr      nz,cd_no
        xor     a
        out     (CP_C),a                ; IDENT
        ld      hl,csig
        ld      b,4
cd_l:   in      a,(CP_D)
        cp      (hl)
        jr      nz,cd_no
        inc     hl
        djnz    cd_l
        or      a
        ret
cd_no:  scf
        ret
; A = command, HL = parameter (written first)
c_cmd:  push    af
        ld      a,l
        out     (CP_L),a
        ld      a,h
        out     (CP_H),a
        pop     af
        out     (CP_C),a
        ret
c_status:
        in      a,(CP_C)
        ret
; HL = position
c_pos:  in      a,(CP_L)
        ld      l,a
        in      a,(CP_H)
        ld      h,a
        ret
; send DE bytes from HL
c_send: ld      c,CP_D
cs_l:   ld      a,d
        or      e
        ret     z
        ld      b,e
        ld      a,d
        or      a
        jr      z,cs_o
        ld      b,0                     ; 256 bytes
        otir
        dec     d
        jr      cs_l
cs_o:   otir
        ret
csig:   defb    "MVS",1

cart_start:
        ld      a,(cart_on)
        or      a
        ret     z
        ld      de,(fname)              ; second handle on the same file, used only for the sound pieces
        ld      a,01h
        ld      c,43h                   ; _OPEN
        call    BDOS
        or      a
        jr      z,cs_ok
        xor     a                       ; no second handle: play without sound
        ld      (cart_on),a
        ret
cs_ok:  ld      a,b
        ld      (h2),a
        ld      hl,150                  ; 15.0 frames per second
        ld      a,5
        call    c_cmd
        ld      hl,0
        ld      (c_next),hl
        ld      a,1                     ; OPEN, first data frame = 0
        call    c_cmd
        call    cart_refill             ; fill CLEAD frames ahead before starting
        ld      hl,0
        ld      a,2                     ; PLAY
        jp      c_cmd

; keep the cartridge fed: send frames up to (position + CLEAD)
cart_refill:
        ld      a,(cart_on)
        or      a
        ret     z
cr_l:   call    c_status
        and     02h
        ret     z                       ; FIFO has no room
        call    c_pos
        ld      de,CLEAD
        add     hl,de                   ; HL = position + CLEAD
        ex      de,hl
        ld      hl,(c_next)
        or      a
        sbc     hl,de                   ; c_next - (position + CLEAD)
        ret     nc                      ; far enough ahead
        ld      hl,(nframes)
        ld      de,(c_next)
        or      a
        sbc     hl,de
        jr      z,cr_eof
        jr      c,cr_eof                ; past the last frame
        call    cart_piece
        jr      c,cr_eof                ; read error / end of file: no more sound to send
        ld      hl,(c_next)
        inc     hl
        ld      (c_next),hl
        jr      cr_l

cr_eof: ld      a,1
        ld      (c_eof),a
        ret

; The cartridge clock stops when its sound runs out (the last MV2 frames have no sound).  When everything
; has been sent and the position has not moved for ~0.5 s, continue on the JIFFY clock.  HL = position.
cart_watch:
        ld      de,(c_wpos)
        or      a
        sbc     hl,de
        add     hl,de                   ; (flags: Z = unchanged; HL restored)
        jr      nz,cw_mv
        ld      a,(c_eof)
        or      a
        jr      nz,cw_t
        push    hl                      ; not everything sent yet: stalled only if we are already a full lead ahead
        ld      de,CLEAD                ; (the rest of the pieces are silent) -- otherwise the cartridge just waits for data
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
        ret     c                       ; not long enough
        ld      (tgt),hl
        ld      a,1
        ld      (cart_tail),a
        call    st_j                    ; t0 = JIFFY - ticks(position)
        ld      hl,(tgt)
        ret
cw_mv:  ld      (c_wpos),hl
        ld      de,(JIFFY)
        ld      (c_wtick),de
        ret

; send the MP3 piece of frame c_next (frame offset 3200h: count byte N, then N*32 bytes)
cart_piece:
        ld      bc,(c_next)
        call    cseek
        ret     c
        ld      a,(h2)
        ld      b,a
        ld      de,tmp16
        ld      hl,1
        ld      c,48h                   ; _READ
        call    BDOS
        or      a
        jr      nz,cp_err
        ld      a,(tmp16)
        or      a
        ret     z                       ; silent frame (no carry)
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; N * 32
        push    hl
        ld      a,(h2)
        ld      b,a
        ld      de,RING                 ; RING is free in cartridge mode
        ld      c,48h
        call    BDOS
        pop     de
        or      a
        jr      nz,cp_err
        ld      hl,RING
        call    c_send
        or      a
        ret
cp_err: scf
        ret

; seek the sound handle to frame BC : offset (BC+1)*16384 + 3200h.  carry = error
cseek:  push    bc
        inc     bc
        ld      a,c
        and     3
        rrca
        rrca
        ld      h,a
        ld      l,0
        ld      de,3200h
        add     hl,de
        srl     b
        rr      c
        srl     b
        rr      c
        ld      d,b
        ld      e,c
        ld      a,(h2)
        ld      b,a
        xor     a
        ld      c,4Ah                   ; _SEEK
        call    BDOS
        pop     bc
        or      a
        ret     z
        scf
        ret

cart_pause:
        ld      a,(vmode)
        or      a
        jp      nz,VC_PAUSE
        ld      a,(cart_on)
        or      a
        ret     z
        ld      hl,0
        ld      a,3
        jp      c_cmd
cart_resume:
        ld      a,(vmode)
        or      a
        jp      nz,VC_RESUME
        ld      a,(cart_on)
        or      a
        ret     z
        ld      hl,0
        ld      a,2
        jp      c_cmd
cart_stop:
        ld      a,(vmode)
        or      a
        jp      nz,VC_STOP
        ld      a,(cart_on)
        or      a
        ret     z
        ld      hl,0
        ld      a,4
        call    c_cmd
        ld      a,(h2)
        ld      b,a
        ld      c,45h                   ; _CLOSE
        call    BDOS
        xor     a
        ld      (cart_on),a
        ret
; seek: HL = target frame.  Start 2 frames early so the MP3 decoder is in sync at the target.
cart_seek:
        ld      de,2
        or      a
        sbc     hl,de
        jr      nc,ck1
        ld      hl,0
ck1:    ld      (c_next),hl
        xor     a
        ld      (c_eof),a
        ld      (cart_tail),a
        ld      (c_wpos+1),a            ; force the watchdog to re-arm
        dec     a
        ld      (c_wpos),a
        ld      a,1                     ; OPEN with the new first frame
        call    c_cmd
        call    cart_refill
        ld      a,(paused)
        or      a
        ret     nz
        ld      hl,0
        ld      a,2
        jp      c_cmd
; volume: C = level index 0..5 (5 = mute) -> percent
cart_vol:
        ld      a,(vmode)
        or      a
        jp      nz,VC_VOL
        ld      a,(cart_on)
        or      a
        ret     z
        ld      hl,pcttab
        ld      b,0
        add     hl,bc
        ld      l,(hl)
        ld      h,0
        ld      a,6
        jp      c_cmd
pcttab: defb    100,71,50,35,25,0

; "no sound" notice, then wait about 0.75 s so it can be read
msg_nosnd:
        ld      de,m_nosnd
        ld      c,09h
        call    BDOS
        ld      bc,(JIFFY)
ms1:    ld      hl,(JIFFY)
        or      a
        sbc     hl,bc
        ld      de,45
        or      a
        sbc     hl,de
        jr      c,ms1
        ret

; ------------------------------------------------------------
; quit: close file, restore text screen + palette, back to DOS
done:   ld      sp,(sp0)
        ld      a,(br_on)
        or      a
        jr      z,dn_q
        call    stop_play
        jp      br_again                ; back to the list
dn_q:   call    stop_play
quit:   ld      sp,(sp0)
        call    cpu_z80
        ld      a,(SCRMOD)
        ld      iy,(EXPTBL-1)
        ld      ix,CHGMOD
        call    CALSLT
        call    defpal
        ei
        ld      b,0
        ld      c,62h           ; _TERM
        jp      BDOS

br_noarg:
        ld      a,1
        ld      (br_on),a
        jp      br_start

; per-play state (also used when the next file is started from the browser)
play_reset:
        ld      hl,0            ; overlay cache needs C000h-CFFFh free: DOS puts the stack just below the BDOS entry (top of the TPA),
        add     hl,sp           ; so it is enough that the stack is above 0D200h
        ld      a,h
        cp      0D2h
        ld      a,0
        jr      c,pr_o
        inc     a
pr_o:   ld      (ov_ok),a
        xor     a
        ld      (aud_on),a
        ld      (cart_on),a
        ld      (cart_tail),a
        ld      (c_eof),a
        ld      (paused),a
        ld      (menu_open),a
        ld      (redraw),a
        ld      (kprev8),a
        ld      (kprev4),a
        ld      (kprev5),a
        ld      (khold),a
        ld      (handle),a
        ld      (vmode),a
        ld      (fps_n),a
        ld      (fps_v),a
        ld      (ov_on),a
        ld      (lead),a
        ld      (lead_t),a
        ld      (lead_s),a
        ld      (lead_s+1),a
        dec     a
        ld      (ov_sg),a
        inc     a
        inc     a
        ld      (ui_vis),a
        ld      hl,0
        ld      (c_next),hl
        ld      (ui_last),hl
        ld      hl,0FFFFh
        ld      (cur),hl
        ld      (c_wpos),hl
        ld      hl,(JIFFY)
        ld      (fps_t),hl
        ret


; frame count from the file size (_SEEK to the end), then back to frame 0.  carry = error
size_frames:
        ld      a,(handle)
        ld      b,a
        ld      a,2             ; from the end
        ld      de,0
        ld      hl,0
        ld      c,4Ah           ; _SEEK
        call    BDOS
        or      a
        jr      nz,sf_err
        push    de
        push    hl
        ld      a,(handle)
        ld      b,a
        xor     a
        ld      de,0
        ld      hl,FRMSZ        ; offset 4000h = frame 0
        ld      c,4Ah
        call    BDOS
        pop     hl
        pop     de
        ld      a,h
        rlca
        rlca
        and     3
        ld      c,a
        ex      de,hl
        add     hl,hl
        add     hl,hl
        ld      a,l
        or      c
        ld      l,a             ; HL = size / 16384
        dec     hl              ; minus the header block
        ld      a,h
        or      l
        jr      z,sf_err
        ld      (nframes),hl
        or      a
        ret
sf_err: scf
        ret


; ---- turbo R: CHGCPU (BIOS 0180h).  A bit 7 = LED shows the CPU, bits 0-1: 0 = Z80, 1 = R800 ROM mode ----
cpu_r800:
        ld      a,81h
        jr      cpu_set
cpu_z80:ld      a,(gen)
        cp      3
        ret     nz
        ld      a,80h
cpu_set:ld      iy,(EXPTBL-1)
        ld      ix,0180h
        call    CALSLT
        ei
        ret

; ------------------------------------------------------------
; read one frame into BUF: only the first FRDSZ bytes (pattern, color, palette; 22 % less for DOS to copy and the disk to deliver),
; then step the file pointer over the rest of the frame (the MP3 piece, which the sound code reads through its own handle).
; carry = error / short / EOF
fread:  ld      a,(handle)
        ld      b,a
        ld      de,BUF
        ld      hl,FRDSZ
        ld      c,48h           ; _READ
        call    BDOS
        or      a
        jr      nz,fr_err
        ld      de,FRDSZ
        or      a
        sbc     hl,de
        jr      nz,fr_err
        ld      a,(handle)      ; _SEEK from the current position: to the start of the next frame
        ld      b,a
        ld      a,1
        ld      de,0
        ld      hl,FRMSZ-FRDSZ
        ld      c,4Ah
        call    BDOS            ; (an error here only happens at the end of the file; the next read reports it)
        or      a
        ret
fr_err: scf
        ret

; seek to frame BC (file offset = (BC+1)*16384).  carry = error
fseek:  push    bc
        inc     bc
        ld      a,c
        and     3
        rrca
        rrca
        ld      h,a
        ld      l,0
        srl     b
        rr      c
        srl     b
        rr      c
        ld      d,b
        ld      e,c
        ld      a,(handle)
        ld      b,a
        xor     a               ; from beginning
        ld      c,4Ah           ; _SEEK
        call    BDOS
        pop     bc
        or      a
        jr      z,fs_ok
        scf
        ret
fs_ok:  ld      (fpos),bc
        or      a
        ret

; HL = HL / 10
div10:  ld      b,h
        ld      c,l
        ld      hl,0
        ld      de,10
        ld      a,16
dv1:    sla     c
        rl      b
        adc     hl,hl
        or      a
        sbc     hl,de
        jr      nc,dv2
        add     hl,de
        jr      dv3
dv2:    inc     c
dv3:    dec     a
        jr      nz,dv1
        ld      h,b
        ld      l,c
        ret

; (keys, seek, volume and the overlay live in ui.inc)
        include "ui.inc"
        include "browser.inc"

; ------------------------------------------------------------
; vdp_id: read the VDP chip ID (S#1 bits 5..1: V9938 = 0, V9958 = 2)
; -> (vdplv) = 1 + ID/2   (1 = V9938, 2 = V9958, higher = newer)
vdp_id: di
        ld      a,1
        out     (VDP_C),a
        ld      a,8Fh           ; R#15 = 1 (select S#1)
        out     (VDP_C),a
        in      a,(VDP_C)
        ld      c,a
        xor     a
        out     (VDP_C),a
        ld      a,8Fh           ; R#15 = 0
        out     (VDP_C),a
        ei
        ld      a,c
        and     3Eh
        srl     a
        srl     a
        inc     a
        ld      (vdplv),a
        call    VK_MACH         ; the SCREENs an MP4 can use on this machine (vmask) and the best one (vsc): vk.asm
        ld      a,(VC_CAPS)     ; V1.11.18: a Gfx9000 (V9990) in the machine: the movie is shown on it by default (V9 FAST = index 7); the SCREEN can still be changed
        and     40h
        ret     z
        ld      a,7
        ld      (vsc),a
        ret

; ------------------------------------------------------------
; VDP setup for SCREEN 2 (display blanked until first frame)
vdp_init:
        xor     a
        ld      (vcur),a        ; registers go back to set A
        inc     a
        ld      (vhid),a
        ld      a,(RG9SAV)
        and     02h
        ld      (pal),a
        ld      (rtab9),a
        di
        ld      hl,rtab
        ld      a,(vdplv)
        cp      2
        ld      b,rcount-3      ; V9938: skip R#25..27
        jr      c,vr
        ld      b,rcount        ; V9958 or later
vr:     ld      a,(hl)
        out     (VDP_C),a
        inc     hl
        ld      a,(hl)
        out     (VDP_C),a
        inc     hl
        djnz    vr
        xor     a               ; name table at 1800h
        out     (VDP_C),a
        ld      a,58h
        out     (VDP_C),a
        ei
        ld      e,3
nt3:    xor     a
        ld      b,0
nt1:    out     (VDP_D),a
        inc     a
        djnz    nt1
        dec     e
        jr      nz,nt3
        di                      ; palette color 0 = black
        xor     a
        out     (VDP_C),a
        ld      a,90h
        out     (VDP_C),a
        xor     a
        out     (VDP_P),a
        out     (VDP_P),a
        ei
        ld      a,1
        ld      (first),a
        ret

; ------------------------------------------------------------
; show one frame (BUF): palette, pattern table, color table
showframe:
        ld      a,(vcur)        ; two table sets: the one on screen (vcur) is never touched, the other is filled
        xor     1               ; and swapped in during the vertical retrace -> no tear line
        ld      (vhid),a
        ; (the palette is written together with the table switch in vflip, inside the vertical retrace)
        ; pattern row and color row of the same tile row are written one after the other, so at any moment only the
        ; row being written is inconsistent (one tear line instead of new patterns with old colors all over the screen)
        xor     a
        ld      (sh_r),a
sh_l:   ld      a,(sh_r)
        ld      e,a
        di                      ; VRAM write address = r * 256 (pattern row)
        ld      a,(vhid)        ; R#14 = 0 (set A at 0000h/2000h) or 1 (set B at 4000h/6000h)
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a
        xor     a
        out     (VDP_C),a
        ld      a,e
        or      40h
        out     (VDP_C),a
        ei
        ld      a,e
        call    sf_pat          ; source page of this screen row (BUF; browser list: ring slot; overlay rows: the cache)
        ld      h,a
        ld      l,0
        call    outrow
        ld      a,(sh_r)        ; color row: VRAM 2000h + r * 256
        add     a,60h
        ld      e,a
        di
        ld      a,(vhid)
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a
        xor     a
        out     (VDP_C),a
        ld      a,e
        out     (VDP_C),a
        ei
        ld      a,(sh_r)
        call    sf_col
        ld      h,a
        ld      l,0
        call    outrow
        ld      a,(sh_r)
        and     7
        cp      7
        jr      nz,sh_n
        call    refill          ; keep the audio ring topped up (3 times per frame)
sh_n:   ld      a,(sh_r)
        inc     a
        ld      (sh_r),a
        cp      24
        jr      nz,sh_l
        call    vflip
        ld      a,(first)
        or      a
        ret     z
        xor     a
        ld      (first),a
        di                      ; display on
        ld      a,(r1on)
        out     (VDP_C),a
        ld      a,81h
        out     (VDP_C),a
        ei
        ret

; outrow: HL = 256 bytes -> VDP data port, 16 T-states per byte (OTIR needs 21).  The V9938/V9958 keep up with OUTI after OUTI on a
; 3.58 MHz Z80 (the minimum gap between two VRAM accesses is about 14.3 T-states; the turbo R S1990 waits by itself)
outrow: ld      c,VDP_D
        ld      b,0
or_l:   outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        outi
        jp      nz,or_l
        ret

; sf_pat / sf_col: A = screen tile row -> A = page (high byte) of its 256 pattern / color bytes.
; With ov_on the overlay rows (0-2, 19-23) come from the cache OVB (row index 0-2, 19-23 -> 0-7), all other rows from BUF.
sf_pat: ld      b,a
        ld      a,(ov_on)
        or      a
        jr      z,sfp_n
        ld      a,b
        cp      3
        jr      c,sfp_t
        cp      19
        jr      c,sfp_n
        sub     16
sfp_t:  add     a,OVB/256
        ret
sfp_n:  ld      a,b
        call    sf_src
        add     a,BUF/256
        ret
sf_col: ld      b,a
        ld      a,(ov_on)
        or      a
        jr      z,sfc_n
        ld      a,b
        cp      3
        jr      c,sfc_t
        cp      19
        jr      c,sfc_n
        sub     16
sfc_t:  add     a,OVB/256+8
        ret
sfc_n:  ld      a,b
        call    sf_src
        add     a,BUF/256+18h
        ret
; sf_src: A = screen tile row -> A = BUF row.  Rows 4..21 of the browser list are a ring (entry mod 18); sf_tm = top mod 18, 0 otherwise
sf_src: cp      4
        ret     c
        cp      22
        ret     nc
        sub     4
        push    hl
        ld      hl,sf_tm
        add     a,(hl)
        pop     hl
        cp      18
        jr      c,sfs_1
        sub     18
sfs_1:  add     a,4
        ret

; swap the table sets during the vertical retrace (S#2 bit 6 = VR; polled with R#15 = 2 inside DI, then R#15 back)
vflip:  ld      de,40000
vf_l:   di
        ld      a,2
        out     (VDP_C),a
        ld      a,8Fh
        out     (VDP_C),a
        in      a,(VDP_C)
        ld      c,a
        ld      a,(aud_on)      ; R#15 back: 1 while the line-interrupt audio runs (S#1 selected), else 0
        or      a
        jr      z,vf_0
        ld      a,1
vf_0:   out     (VDP_C),a
        ld      a,8Fh
        out     (VDP_C),a
        ei
        bit     6,c
        jr      nz,vf_go
        dec     de              ; never hang if VR does not show up
        ld      a,d
        or      e
        jr      nz,vf_l
vf_go:  di
        ld      a,1             ; palette colors 1..15 of the new frame, together with the switch
        out     (VDP_C),a
        ld      a,90h
        out     (VDP_C),a
        ld      hl,BUF+PALOFS
        ld      c,VDP_P
        ld      b,30
        otir
        ld      a,(vhid)        ; B: R#4 = 0Bh (4000h), R#10 = 1 (color table 6000h); A: 03h, 0
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        or      03h
        out     (VDP_C),a
        ld      a,84h
        out     (VDP_C),a
        ld      a,b
        out     (VDP_C),a       ; R#10 = set number (0/1)
        ld      a,8Ah
        out     (VDP_C),a
        xor     a               ; R#14 back to 0 for everyone else
        out     (VDP_C),a
        ld      a,8Eh
        out     (VDP_C),a
        ei
        ld      a,(vhid)
        ld      (vcur),a
        ret

; MSX2 default palette (colors 0..15), R<<4|B , G
defpal: di
        xor     a
        out     (VDP_C),a
        ld      a,90h
        out     (VDP_C),a
        ld      hl,dpal
        ld      c,VDP_P
        ld      b,32
        otir
        ei
        ret

; ============================================================
;  AUDIO  (only active when NAME.MVA exists next to the MV2)
;  Timer = VDP line interrupt (R#19 re-armed every LPS lines).
;  PSG: 3 volume registers form an ~8 bit DAC (2 samples averaged, LPS = 4)
;  turbo R: PCM DAC port A4h (A5h = 3), 1 sample per interrupt, LPS = 2
; ============================================================
; open NAME.MVA, check header, preload the ring buffer
audio_open:
        xor     a
        ld      (aud_on),a
        ld      hl,(fname)
        ld      de,mvaname
        ld      bc,0                    ; BC = position of the last '.' (0 = none)
ao_cp:  ld      a,(hl)
        ld      (de),a
        or      a
        jr      z,ao_end
        cp      '.'
        jr      nz,ao_n1
        ld      b,d
        ld      c,e
ao_n1:  cp      '\'
        jr      z,ao_sep
        cp      '/'
        jr      nz,ao_n2
ao_sep: ld      bc,0
ao_n2:  inc     hl
        inc     de
        jr      ao_cp
ao_end: ld      a,b
        or      c
        jr      z,ao_app
        ld      h,b
        ld      l,c
        inc     hl
        jr      ao_wr
ao_app: ld      h,d
        ld      l,e
        ld      (hl),'.'
        inc     hl
ao_wr:  ld      (hl),'M'
        inc     hl
        ld      (hl),'V'
        inc     hl
        ld      (hl),'A'
        inc     hl
        ld      (hl),0
        ld      de,mvaname
        ld      a,01h                   ; read only
        ld      c,43h                   ; _OPEN
        call    BDOS
        or      a
        ret     nz                      ; no MVA: silent
        ld      a,b
        ld      (h2),a
        ld      de,ahdr
        ld      hl,16
        ld      c,48h                   ; _READ
        call    BDOS
        or      a
        jr      nz,ao_bad
        ld      de,16
        or      a
        sbc     hl,de
        jr      nz,ao_bad
        ld      hl,ahdr
        ld      de,amagic
        ld      b,4
ao_ck:  ld      a,(de)
        cp      (hl)
        jr      nz,ao_bad
        inc     hl
        inc     de
        djnz    ao_ck
        ld      a,(ahdr+4)              ; codec 1 = unsigned 8-bit
        cp      1
        jr      nz,ao_bad
        ld      a,(ahdr+12)             ; base lines per sample must be 2
        cp      2
        jr      nz,ao_bad
        ld      hl,(ahdr+13)
        ld      (aud_spf),hl
        ld      a,h
        or      l
        jr      z,ao_bad
        ld      a,(gen)                 ; turbo R -> PCM port, otherwise PSG
        cp      3
        ld      a,0
        jr      nz,ao_m
        inc     a
ao_m:   ld      (aud_mode),a
        or      a
        ld      a,2                     ; PSG: 2 samples per interrupt
        jr      z,ao_k
        dec     a                       ; PCM: 1
ao_k:   ld      (aud_k),a
        ld      hl,RING
        ld      (rp),hl
        ld      (wr_ptr),hl
        call    refill
        ld      hl,(rp)
        ld      de,(wr_ptr)
        or      a
        sbc     hl,de
        jr      z,ao_bad                ; nothing could be read
        ld      a,1
        ld      (aud_on),a
        ret
ao_bad: ld      a,(h2)
        ld      b,a
        ld      c,45h                   ; _CLOSE
        call    BDOS
        xor     a
        ld      (aud_on),a
        ret

; refill the ring buffer in 512-byte chunks while there is room
refill: ld      a,(aud_on)
        or      a
        jr      nz,rf_go
        ld      a,(h2)                  ; (also used during audio_open before aud_on is set)
        or      a
        ret     z
rf_go:
rf_l:   ld      hl,(rp)
        ld      de,(wr_ptr)
        or      a
        sbc     hl,de
        dec     hl
        ld      a,h
        and     0Fh                     ; free bytes = (rp - wr - 1) & 0FFFh
        cp      2
        ret     c                       ; < 512 free
        ld      a,(aud_eof)
        or      a
        jr      nz,rf_sil
        ld      a,(h2)
        ld      b,a
        ld      de,(wr_ptr)
        ld      hl,512
        ld      c,48h                   ; _READ
        call    BDOS
        or      a
        jr      nz,rf_eof0
        ld      a,h
        cp      2
        jr      z,rf_adv                ; got all 512
        ld      b,h                     ; short read: pad the rest with silence
        ld      c,l
        ld      a,1
        ld      (aud_eof),a
        ld      hl,(wr_ptr)
        add     hl,bc
        ex      de,hl                   ; DE = first byte to pad
        ld      hl,512
        or      a
        sbc     hl,bc                   ; HL = bytes to pad
        jr      rf_fil
rf_eof0:ld      a,1
        ld      (aud_eof),a
rf_sil: ld      de,(wr_ptr)
        ld      hl,512
rf_fil: ld      a,h
        or      l
        jr      z,rf_adv
        ld      b,h
        ld      c,l
        ld      a,80h
        ld      (de),a
        dec     bc
        ld      a,b
        or      c
        jr      z,rf_adv
        ld      h,d
        ld      l,e
        inc     de
        ldir
rf_adv: ld      hl,(wr_ptr)
        inc     h
        inc     h
        ld      a,h
        cp      50h
        jr      nz,rf_ok
        ld      h,40h
rf_ok:  ld      (wr_ptr),hl
        jp      rf_l

; audio clock -> frame index.  HL = frame number due now
audio_idx:
        ld      hl,(cnt)
        ld      de,(lastcnt)
        ld      (lastcnt),hl
        or      a
        sbc     hl,de                   ; interrupts since the last call
        ld      a,(aud_k)
        cp      2
        jr      nz,ai_1
        add     hl,hl                   ; 2 samples per interrupt
ai_1:   ld      de,(rem)
        add     hl,de
        ld      de,(aud_spf)
        ld      bc,(aidx)
ai_l:   or      a
        sbc     hl,de
        jr      c,ai_d
        inc     bc
        jr      ai_l
ai_d:   add     hl,de
        ld      (rem),hl
        ld      (aidx),bc
        ld      h,b
        ld      l,c
        ret

; install the interrupt handler and start the line interrupt timer
audio_start:
        ld      a,(aud_on)
        or      a
        ret     z
        ld      a,0C0h                  ; display on without IE0 (vsync irq not used)
        ld      (r1on),a
        di
        ld      a,7                     ; PSG mixer: tone/noise off -> volume register = DC level
        out     (PSG_A),a
        ld      a,0BFh
        out     (PSG_D),a
        ld      a,(aud_mode)
        or      a
        jr      z,as_v
        ld      a,3                     ; turbo R PCM: DAC mode
        out     (PCM_C),a
as_v:   ld      hl,0038h
        ld      de,old38
        ld      bc,3
        ldir
        ld      a,0C3h
        ld      (0038h),a
        ld      hl,isr_psg
        ld      a,(aud_mode)
        or      a
        jr      z,as_h
        ld      hl,isr_pcm
as_h:   ld      (0039h),hl
        xor     a
        ld      (cnt),a
        ld      (cnt+1),a
        ld      (lastcnt),a
        ld      (lastcnt+1),a
        ld      a,80h                   ; R#1: blank, no IE0
        out     (VDP_C),a
        ld      a,81h
        out     (VDP_C),a
        ld      a,4                     ; first line interrupt at line 4
        ld      (nl),a
        out     (VDP_C),a
        ld      a,93h                   ; R#19
        out     (VDP_C),a
        ld      a,1                     ; R#15 = 1 : status register S#1 stays selected
        out     (VDP_C),a
        ld      a,8Fh
        out     (VDP_C),a
        in      a,(VDP_C)               ; clear a pending FH flag
        ld      a,12h                   ; R#0: Graphic 2 + IE1 (line interrupt)
        out     (VDP_C),a
        ld      a,80h
        out     (VDP_C),a
        ei
        ret

audio_pause:
        ld      a,(aud_on)
        or      a
        ret     z
        di
        ld      a,02h                   ; IE1 off
        out     (VDP_C),a
        ld      a,80h
        out     (VDP_C),a
        in      a,(VDP_C)
        call    psg_quiet
        ei
        ret

audio_resume:
        ld      a,(aud_on)
        or      a
        ret     z
        di
        ld      a,4
        ld      (nl),a
        out     (VDP_C),a
        ld      a,93h                   ; R#19
        out     (VDP_C),a
        in      a,(VDP_C)
        ld      a,12h                   ; IE1 on
        out     (VDP_C),a
        ld      a,80h
        out     (VDP_C),a
        ei
        ret

; volume registers 8..10 = 0
psg_quiet:
        ld      a,8
        out     (PSG_A),a
        xor     a
        out     (PSG_D),a
        ld      a,9
        out     (PSG_A),a
        xor     a
        out     (PSG_D),a
        ld      a,10
        out     (PSG_A),a
        xor     a
        out     (PSG_D),a
        ret

audio_stop:
        ld      a,(aud_on)
        or      a
        ret     z
        di
        ld      a,02h                   ; IE1 off, R#0 as before
        out     (VDP_C),a
        ld      a,80h
        out     (VDP_C),a
        in      a,(VDP_C)               ; clear FH (S#1 is selected)
        xor     a                       ; R#15 = 0 : S#0 again
        out     (VDP_C),a
        ld      a,8Fh
        out     (VDP_C),a
        ld      hl,old38                ; give the interrupt vector back
        ld      de,0038h
        ld      bc,3
        ldir
        call    psg_quiet
        ld      a,7
        out     (PSG_A),a
        ld      a,0B8h                  ; MSX default mixer
        out     (PSG_D),a
        ld      a,(aud_mode)
        or      a
        jr      z,asp_e
        xor     a                       ; turbo R PCM off
        out     (PCM_C),a
asp_e:  ei
        ld      a,(h2)
        ld      b,a
        ld      c,45h                   ; _CLOSE
        call    BDOS
        xor     a
        ld      (aud_on),a
        ret

; ---- interrupt handlers (line interrupt = sample clock) ----
; PSG: 2 samples averaged -> 3 volume registers (table set chosen by the volume)
isr_psg:push    af
        push    hl
        push    de
        in      a,(VDP_C)               ; S#1: clears FH
        ld      a,(nl)
        add     a,4
        cp      LINE_END
        jr      c,ip1
        ld      a,4                     ; wrap: next interrupt = line 4 of the next frame
ip1:    ld      (nl),a
        out     (VDP_C),a
        ld      a,93h                   ; R#19 = next line
        out     (VDP_C),a
        ld      hl,(rp)
        ld      e,(hl)
        inc     hl
        ld      a,h
        and     0Fh
        or      40h
        ld      h,a
        ld      a,(hl)
        inc     hl
        ld      d,a
        ld      a,h
        and     0Fh
        or      40h
        ld      h,a
        ld      (rp),hl
        ld      a,d
        add     a,e
        rra                             ; average of the two samples
        ld      l,a
        ld      a,(vtab_h)
        ld      h,a
        ld      e,(hl)                  ; volume A
        inc     h
        ld      d,(hl)                  ; volume B
        inc     h
        ld      h,(hl)                  ; volume C
        ld      a,8
        out     (PSG_A),a
        ld      a,e
        out     (PSG_D),a
        ld      a,9
        out     (PSG_A),a
        ld      a,d
        out     (PSG_D),a
        ld      a,10
        out     (PSG_A),a
        ld      a,h
        out     (PSG_D),a
        ld      hl,(cnt)
        inc     hl
        ld      (cnt),hl
        pop     de
        pop     hl
        pop     af
        ei
        reti

; turbo R PCM: 1 sample per interrupt (LPS = 2)
isr_pcm:push    af
        push    hl
        push    de
        in      a,(VDP_C)
        ld      a,(nl)
        add     a,2
        cp      LINE_END
        jr      c,ic1
        ld      a,4
ic1:    ld      (nl),a
        out     (VDP_C),a
        ld      a,93h
        out     (VDP_C),a
        ld      hl,(rp)
        ld      e,(hl)
        inc     hl
        ld      a,h
        and     0Fh
        or      40h
        ld      h,a
        ld      (rp),hl
        ld      a,(ptab_h)
        ld      h,a
        ld      l,e
        ld      a,(hl)
        out     (PCM_D),a
        ld      hl,(cnt)
        inc     hl
        ld      (cnt),hl
        pop     de
        pop     hl
        pop     af
        ei
        reti

amagic: defb    "MVA1"

; ------------------------------------------------------------
; error exits
e_mem:  ld      de,m_mem
        jr      err
e_open: ld      de,m_open
        jr      err
e_fmt:  ld      de,m_fmt
        jr      err
e_msx1: ld      de,m_msx1
        jr      err
e_dos1: ld      de,m_dos1
        jr      err
e_ufmt: ld      de,m_ufmt
        jr      err
e_gen:  ld      de,m_gen1
        ld      a,b
        cp      2
        jr      c,err
        ld      de,m_gen2
err:    ld      a,(br_on)
        or      a
        jr      z,err_p
        ld      (br_note),de            ; the list shows the message on its bottom line
        call    stop_play       ; browser mode: close what is open, back to the list
        jp      br_again
err_p:  push    de
        call    cpu_z80         ; leaving the program: back to the Z80
        pop     de
        ld      c,09h           ; _STROUT
        call    BDOS
        ld      b,1
        ld      c,62h           ; _TERM
        jp      BDOS

; ---- MV8 (and later formats): the module X86MV8.OVL lies next to X86MV.COM (path = DOS2 environment item PROGRAM); it is read to 5000h
; and started there (m8.asm).  The movie handle is open and BUF holds the header. ----
m8_load:xor     a
        ld      (ui_ok),a               ; 5000h is overwritten: the list look is read again when the list comes back
        ld      a,(BUF+11h)             ; V1.11.28: a module for each format: X86MV5 / 6 / 7 / 8.OVL, X86MVA.OVL for MVA, MVB, MVC (another letter: X86MV8.OVL says "not supported")
        cp      '5'
        jr      c,m8_d
        cp      '9'
        jr      c,m8_nm
        cp      'A'
        jr      c,m8_d
        cp      'D'
        jr      nc,m8_d
        ld      a,'A'
        jr      m8_nm
m8_d:   ld      a,'8'
m8_nm:  ld      (s_m8+5),a
        ld      hl,s_m8
        call    mod_load
        jp      z,5000h
        call    m8_msg
        jp      err
m8_msg: ld      hl,RING                 ; the message is built in mn_note, not in RING (RING is overwritten when the list reloads X86MVUI.OVL, and the list shows the note after that)
        ld      de,mn_note
m8_z:   ld      a,(hl)
        or      a
        jr      z,m8_t
        ldi
        jr      m8_z
m8_t:   ld      hl,m_m8
        ld      bc,m_m8e-m_m8
        ld      a,(mb_bad)
        or      a
        jr      z,m8_u
        ld      hl,m_m8b                ; V1.11.21: loaded, but from another build
        ld      bc,m_m8be-m_m8b
m8_u:   ldir
        ld      de,mn_note
        ret
; HL = file name (12 bytes), read next to X86MV.COM into 5000h (Z = done)
mod_load:xor     a
        ld      (mb_bad),a              ; V1.11.21: 1 = the module is from another build
        push    hl
        ld      a,(mb_ok)
        or      a
        call    z,mb_make
        ld      hl,mb_buf               ; RING = the program folder + the module name
        ld      de,RING
mb_c:   ld      a,(hl)
        or      a
        jr      z,mb_n
        ldi
        jr      mb_c
mb_n:   pop     hl
        ld      bc,12
        ldir
        ld      de,RING
        ld      a,01h
        ld      c,43h           ; _OPEN
        call    BDOS
        or      a
        ret     nz
        ld      a,b
        ld      (m8_h),a
        ld      de,5000h
        ld      hl,1000h
        ld      c,48h           ; _READ (a short file ends with .EOF: fine)
        call    BDOS
        ld      a,(m8_h)
        ld      b,a
        ld      c,45h           ; _CLOSE
        call    BDOS
        ld      hl,(5000h+0FFEh)        ; V1.11.21: the module carries the stamp of the build whose main-program addresses it uses;
        ld      de,BSTAMP               ; another build would read wrong variables (e.g. "This MV needs a V9938 VDP" on a V9958)
        or      a
        sbc     hl,de
        ld      a,h
        or      l
        ld      (mb_bad),a
        ret                             ; Z = loaded and from this build
; the folder of the modules, found once (at the first load, before the browser changes folders): the PROGRAM path of X86MV.COM,
; or, when the shell does not set it, the drive and folder X86MV was started in -> "X:\dir\" in mb_buf
mb_make:ld      hl,s_prog
        ld      de,mb_buf
        ld      b,60
        ld      c,6Bh                   ; _GENV
        call    BDOS
        ld      hl,mb_buf
        ld      d,h
        ld      e,l                     ; DE = just after the last '\' or ':'
mb_s:   ld      a,(hl)
        inc     hl
        or      a
        jr      z,mb_e
        cp      '\'
        jr      z,mb_m
        cp      ':'
        jr      nz,mb_s
mb_m:   ld      d,h
        ld      e,l
        jr      mb_s
mb_e:   ld      hl,mb_buf
        or      a
        sbc     hl,de
        ld      a,h
        or      l
        jr      z,mb_cur                ; no folder in PROGRAM: use the current one
        xor     a
        ld      (de),a
        jr      mb_d
mb_cur: ld      c,19h                   ; _CURDRV
        call    BDOS
        add     a,'A'
        ld      hl,mb_buf
        ld      (hl),a
        inc     hl
        ld      (hl),':'
        inc     hl
        ld      (hl),'\'
        inc     hl
        ex      de,hl
        ld      b,0
        ld      c,59h                   ; _GETCD (current drive)
        call    BDOS
        ld      hl,mb_buf+3
mb_z:   ld      a,(hl)
        inc     hl
        or      a
        jr      nz,mb_z
        dec     hl
        ld      de,mb_buf+3
        or      a
        sbc     hl,de
        ld      a,h
        or      l
        ld      hl,mb_buf+3
        jr      z,mb_t                  ; the root folder: "X:\"
        ld      a,(hl)
mb_f:   ld      a,(hl)
        inc     hl
        or      a
        jr      nz,mb_f
        dec     hl
        ld      (hl),'\'
        inc     hl
mb_t:   ld      (hl),0
mb_d:   ld      a,1
        ld      (mb_ok),a
        ret
mb_ok:  defb    0
mb_buf  equ     6FA0h                   ; 64 bytes behind the list records (BR_ENT ends at 6F9Fh)
; the drive popup is drawn by the SCREEN 6 module when it is there (called by vc.asm)
dp_hook:jp      5006h                   ; the drive popup of the SCREEN 6 module
; the list look: X86MVUI.OVL -> 5000h once (ui_ok); the file is required (V1.10.1: the old SCREEN 2 list look was removed)
ui_prep:ld      a,(ui_ok)
        or      a
        ret     nz
        ld      hl,s_ui
        call    mod_load
        jr      z,up_ok
        call    m8_msg                  ; X86MVUI.OVL is needed: "<folder>X86MVUI.OVL not found" and back to DOS
        jp      err_p
up_ok:  ld      a,1
        ld      (ui_ok),a
        ret
s_ui:   defb    "X86MVUI.OVL",0
s_prog: defb    "PROGRAM",0
s_m8:   defb    "X86MV8.OVL",0
m_m8:   defb    " not found",13,10,"$"
m_m8e:
m_m8b:  defb    " is from another version",13,10,"$"
m_m8be:
mb_bad: defb    0
mn_note: defs    112                    ; V1.11.21: the "<folder>X86MV8.OVL not found" / "is from another version" note
mn_big: defb    "Video too large (max 1920x1080)",0   ; V1.11.20: texts of the OPEN codes 13 / 14 (X86MSX 8.0.141), here because vc.asm is full in a DIAG build
mn_dec: defb    "Decoder could not start",0
m8_h:   defb    0

magic:  defb    "MMCSD_MV"
m_mem:  defb    "Not enough memory (needs TPA up to C000h)",13,10,"$"
m_nosnd:defb    "No sound: X86 Multimedia cartridge or NAME.MVA needed",13,10,"$"
m_open: defb    "Cannot open file",13,10,"$"
m_nocart:defb   "No cartridge: no MP4",13,10,"$"
m_mp4lib:defb   "MP4 plays from USB (D key)",13,10,"$"
m_fmt:  defb    "Not an MV file",13,10,"$"
m_msx1: defb    "MSX2 or later is required",13,10,"$"
m_dos1: defb    "MSX-DOS2 or Nextor is required",13,10,"$"
m_ufmt: defb    "This MV format is not supported",13,10,"$"
m_gen1: defb    "This MV needs a V9938 VDP or later",13,10,"$"
m_gen2: defb    "SCREEN 10-12 needs a V9958 VDP (MSX2+/turbo R)",13,10,"$"

; known formats: version digit, SCREEN mode, minimum VDP level
; (level: 1 = V9938, 2 = V9958).  SCREEN 10-12 (YJK) need a V9958.
fmttab: defb    '2',2,1
        defb    0

; VDP register init pairs: value, 80h+reg   (R#1 = A0h: blank, IE on)
; last 3 pairs (R#25..27) exist on V9958 only
rtab:   defb    02h,80h         ; R#0  mode: M3 (Graphic 2)
        defb    0A0h,81h        ; R#1  16K, blank, IE
        defb    06h,82h         ; R#2  name table 1800h
        defb    0FFh,83h        ; R#3  color table 2000h
        defb    03h,84h         ; R#4  pattern table 0000h
        defb    36h,85h         ; R#5  sprite attr (unused)
        defb    07h,86h         ; R#6  sprite pattern (unused)
        defb    00h,87h         ; R#7  backdrop = color 0
        defb    0Ah,88h         ; R#8  VR=1, sprites off
rtab9:  defb    00h,89h         ; R#9  192 lines (PAL bit patched)
        defb    00h,8Eh         ; R#14
        defb    00h,97h         ; R#23 vertical scroll 0
        defb    00h,99h         ; R#25 no YJK (V9958)
        defb    00h,9Ah         ; R#26
        defb    00h,9Bh         ; R#27
rcount  equ     16

dpal:   defb    00h,00h, 00h,00h, 11h,06h, 33h,07h
        defb    17h,01h, 27h,03h, 51h,01h, 27h,06h
        defb    71h,01h, 73h,03h, 61h,06h, 64h,06h
        defb    11h,04h, 65h,02h, 55h,05h, 77h,07h

; ---- variables ----
sp0:    defw    0
fname:  defw    0
handle: defb    0
nframes:defw    0
fpos:   defw    0
cur:    defw    0FFFFh
fr_t0:  defw    0               ; JIFFY when the frame being shown was started
lead:   defb    0               ; frames to show ahead of the clock (reading + drawing time)
lead_t: defb    0               ; smoothed ticks of one frame
lead_s: defw    0               ; (NAME.MVA sound) smoothed samples of one frame
fr_c0:  defw    0               ; (NAME.MVA sound) interrupt counter when the frame was started
t0:     defw    0
pstart: defw    0
paused: defb    0
pal:    defb    0
gen:    defb    0
vdplv:  defb    0
smode:  defb    0
vmode:  defb    0               ; 1 = the X86 Video cartridge is playing the file
vcpres: defb    0               ; X86 Video cartridge found at start
vsc:    defb    0               ; SCREEN for mp4 (index into vc_scrtab: 5 6 7 8 10 11 12)
vmask:  defb    0               ; bit i = vc_scrtab[i] can be used on this machine (the settings page shows only these)
first:  defb    0
ov_on:  defb    0               ; 1 = showframe takes the overlay rows from OVB
ov_ok:  defb    0               ; 1 = the TPA is big enough for OVB
ov_sg:  defb    0FFh,0,0,0,0,0,0,0   ; signature of what OVB holds (first byte FFh = nothing)
ov_sn:  defb    0,0,0,0,0,0,0,0      ; signature of the overlay now
sf_tm:  defb    0               ; ring rotation of the list rows for showframe (browser), 0 for the movie
vcur:   defb    0               ; table set on screen (0 = A at 0000h, 1 = B at 4000h)
vhid:   defb    1
dbg_shown:defw  0
dbg_last: defw  0
ui_vis: defb    1
ui_last:defw    0
vol_lv: defb    0
muted:  defb    0
kprev8: defb    0
kprev4: defb    0
khold:  defb    0
kd:     defb    0
ke:     defb    0
redraw: defb    0
tgt:    defw    0
pcell:  defb    0
uc:     defb    0
vfill:  defb    0
vpat:   defb    0
vtab_h: defb    VTAB/256
ptab_h: defb    VTAB/256+12h
fsrc:   defw    0
fdst:   defw    0
fcnt:   defw    0
fd:     defw    0
f_sec:  defw    0
f_min1: defw    0
tmp16:  defs    16
ahdr    equ     RING            ; audio_open scratch (the ring is not in use before audio starts)
mvaname equ     RING+16
tbuf:   defs    24
r1on:   defb    0E0h
aud_on: defb    0
cart_on:defb    0
c_next: defw    0
cart_tail:defb  0
c_eof:  defb    0
c_wpos: defw    0FFFFh
c_wtick:defw    0
aud_mode:defb   0
aud_k:  defb    2
aud_eof:defb    0
aud_spf:defw    0
h2:     defb    0
rp:     defw    RING
wr_ptr: defw    RING
cnt:    defw    0
lastcnt:defw    0
rem:    defw    0
aidx:   defw    0
nl:     defb    0
old38:  defb    0,0,0
gt_x:   defb    0
gt_fix: defb    0               ; 1 = fixed pitch (gtextf)
gt_y:   defb    0
gt_c:   defb    0
sh_r:   defb    0
show_fps:defb   0
        include "uidata.inc"
prog_end:
; ---- volume tables, page aligned (generated: voltabs.inc) ----
        defs    VTAB-$
        include "voltabs.inc"
        include "galmuri7_6x8.inc"     ; Galmuri7 6x8 glyphs (labels fontsrc, fontwsrc): at 4000h in the image, copied to fontc at the start
vcsrc:  incbin  "vc.bin"                ; X86 Video client module, BMLEN bytes (mkrom.py builds it from vc.asm)
vksrc:  incbin  "vk.bin"                ; names with non-ASCII characters drawn by the cartridge, VKLEN bytes (mkrom.py builds it from vk.asm)

