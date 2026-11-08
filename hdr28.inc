; 만든이: KimTaeWoo
; 도와준이: Lee.J.H
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

