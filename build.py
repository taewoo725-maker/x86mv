#!/usr/bin/env python3
# 만든이: KimTaeWoo
# 도와준이: Lee.J.H
# X86MV V1.11.28 build: pasmo (https://pasmo.speccy.org/) is needed.
#   python3 build.py          -> X86MV.COM, X86MV8.OVL (the MV8 module) and X86MVUI.OVL (the SCREEN 6 look of the list): copy both .OVL files next to X86MV.COM
# X86MV.COM carries the X86 Video client module (vc.asm, assembled at B560h) behind the font.  The module needs the main
# program's labels and the main program needs the module image, so: main (empty module) -> symbols -> vc.asm -> main again.
import os, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
BMLEN = 0xAA0
VKLEN = 0x780
def run(*a): subprocess.check_call(a, cwd=here)

# V1.11.21: the build stamp: modules (X86MV8.OVL, X86MVUI.OVL) carry it in their last two bytes, X86MV.COM compares it when it loads one.
# It is a CRC16 of all symbol addresses of the main program and the video module, so a module made for another build is refused.
import binascii
def stamp_of(here):
    items = []
    for f in ('x86mv.sym', 'vc.sym'):
        for line in open(os.path.join(here, f)):
            p = line.split()
            if len(p) == 3 and p[1] == 'EQU' and p[0].upper() != 'BSTAMP':
                items.append(p[0] + p[2])
    return binascii.crc_hqx(('V1.11.28' + ''.join(sorted(items))).encode(), 0)
def write_stamp(here, main_value, module_value):
    for name, v in (('stamp.inc', main_value), ('stampm.inc', module_value), (os.path.join('s6', 'stampm.inc'), module_value)):
        open(os.path.join(here, name), 'w').write('BSTAMP equ 0%04XH\n' % v)
write_stamp(here, 0, 0)
open(os.path.join(here, 'vc.bin'), 'wb').write(bytes(BMLEN))
open(os.path.join(here, 'vk.bin'), 'wb').write(bytes(VKLEN))
run('pasmo', '--bin', 'X86MV.ASM', 'X86MV.COM', 'x86mv.sym')
want = ('fitm dp_hook ui_ok br_ins br_cnt br_sel br_top br_entaddr br_host br_prev br_note err br_poll slot18 br_dm fillk gtext gtextf br_send br_depth bl_y bl_ty gt_x m_open br_on show_fps vmask br_scan br_findprev br_again br_filt BR_ENT BR_TMP playfile play_reset fname e_open '
        'mloop gotidx vmode vsc vcpres nframes cur ui_draw ov_ok ov_on ov_sg vol_lv paused pal JIFFY vdp_init mn_big mn_dec').split()
out = ''
for line in open(os.path.join(here, 'x86mv.sym')):
    p = line.split()
    if len(p) == 3 and p[1] == 'EQU' and p[0] in want:
        out += '%s equ 0%s\n' % (p[0], p[2])
open(os.path.join(here, 'mainsyms.inc'), 'w').write(out)
# vk.asm needs the main labels and the vx_* stubs of vc.asm (vcsyms.inc)
run('pasmo', '--bin', 'vc.asm', 'vc.bin', 'vc.sym')
vc = ''
for line in open(os.path.join(here, 'vc.sym')):
    p = line.split()
    if len(p) == 3 and p[1] == 'EQU' and p[0] in ('vx_cmd','vx_par','vx_rd','vx_st','vc_nc'):
        vc += '%s equ 0%s\n' % (p[0], p[2])
open(os.path.join(here, 'vcsyms.inc'), 'w').write(vc)
run('pasmo', '--bin', 'vk.asm', 'vk.bin', 'vk.sym')
assert os.path.getsize(os.path.join(here, 'vk.bin')) <= VKLEN, 'vk.asm outgrew VKLEN'
open(os.path.join(here, 'vk.bin'), 'ab').write(bytes(VKLEN - os.path.getsize(os.path.join(here, 'vk.bin'))))
assert os.path.getsize(os.path.join(here, 'vc.bin')) == BMLEN, 'vc.asm outgrew BMLEN'
run('pasmo', '--bin', 'X86MV.ASM', 'X86MV.COM', 'x86mv.sym')
print('X86MV.COM', os.path.getsize(os.path.join(here, 'X86MV.COM')), 'bytes')
STAMP = stamp_of(here)
write_stamp(here, STAMP, STAMP)
# the MV8 module (m8.asm at 5000h) against the final symbols of the main program
wm = ('c_cmd c_status c_pos c_send cart_detect cart_on h2 handle done err stop_play msg_nosnd e_fmt nframes cur t0 pstart paused redraw kprev8 kprev4 khold kd ke '
      'ui_vis ui_last vol_lv muted tbuf key_up key_down key_mute vdplv pal vmask fname rep br_on br_nextfile playfile vdp_init e_ufmt e_gen sp0 div16 tgt lead c_next c_eof cart_tail c_wpos c_wtick ui_draw ov_ok ov_on ov_sg vmode').split()
out = ''
for line in open(os.path.join(here, 'x86mv.sym')):
    p = line.split()
    if len(p) == 3 and p[1] == 'EQU' and p[0] in wm:
        out += '%s equ 0%s\n' % (p[0], p[2])
open(os.path.join(here, 'm8syms.inc'), 'w').write(out)
# V1.11.28: one module per format from the same source (m8.asm + m8bar6.inc): MODFMT = the format letter ('A' = MVA, MVB, MVC)
subprocess.check_call([sys.executable, 'mkbar6.py'], cwd=here)
for fmt in '86 57A'.replace(' ', ''):
    open(os.path.join(here, 'm8mode.inc'), 'w').write("MODFMT equ '%s'\n" % fmt)
    name = 'X86MV%s.OVL' % fmt
    run('pasmo', '--bin', 'm8.asm', name, 'm%s.sym' % fmt)
    size = os.path.getsize(os.path.join(here, name))
    assert size <= 0x1000, name + ' outgrew 4096 bytes'
    print(name, size, 'bytes')

# the SCREEN 6 look of the list (s6/s6ui.asm at 5000h; the list itself stays in browser.inc) against the final symbols
ws = ('set_old fitm s_fit s_vsc s_off s_on s_rep vsc show_fps rep set_sel br_cnt br_sel br_top br_host br_note br_entaddr utoa br_upath br_osel br_otop bl_ty gen vdplv').split()
out = ''
for line in open(os.path.join(here, 'x86mv.sym')):
    p = line.split()
    if len(p) == 3 and p[1] == 'EQU' and p[0] in ws:
        out += '%s equ 0%s\n' % (p[0], p[2])
for line in open(os.path.join(here, 'vc.sym')):
    p = line.split()
    if len(p) == 3 and p[1] == 'EQU' and p[0] in ('vx_cmd', 'vx_par', 'vx_rd', 'vx_st'):
        out += '%s equ 0%s\n' % (p[0], p[2])
open(os.path.join(here, 's6', 's6syms.inc'), 'w').write(out)
subprocess.check_call([sys.executable, 'mkhanfont.py'], cwd=os.path.join(here, 's6'))   # V1.11.27: the built-in Hangul dot fonts
subprocess.check_call(['pasmo', '--bin', 's6ui.asm', os.path.join('..', 'X86MVUI.OVL'), 's6ui.sym'], cwd=os.path.join(here, 's6'))
assert os.path.getsize(os.path.join(here, 'X86MVUI.OVL')) <= 0x1000, 's6ui.asm outgrew 4096 bytes'
print('X86MVUI.OVL', os.path.getsize(os.path.join(here, 'X86MVUI.OVL')), 'bytes')
# V1.11.25: the settings page and its popups are a second module of the same source (s6core.asm with S6SET = 1): 5000h holds one of them at a time
subprocess.check_call(['pasmo', '--bin', 's6st.asm', os.path.join('..', 'X86MVST.OVL'), 's6st.sym'], cwd=os.path.join(here, 's6'))
assert os.path.getsize(os.path.join(here, 'X86MVST.OVL')) <= 0x1000, 's6st.asm outgrew 4096 bytes'
print('X86MVST.OVL', os.path.getsize(os.path.join(here, 'X86MVST.OVL')), 'bytes')
# the main program again, now carrying the stamp (the stamp is a constant: no address moves)
run('pasmo', '--bin', 'X86MV.ASM', 'X86MV.COM', 'x86mv.sym')
assert stamp_of(here) == STAMP, 'the stamp changed: an address moved when the stamp was added'
print('X86MV.COM', os.path.getsize(os.path.join(here, 'X86MV.COM')), 'bytes, stamp %04X' % STAMP)
