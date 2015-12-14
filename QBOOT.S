;fast seek/multi-read
;copyright (c) Peter Ferrie 2015
;assemble using ACME
!cpu 6502
!to "qboot",plain
*=$800
        sectors   = $d1         ;user-defined
        firsttrk  = $d1         ;user-defined, first track to read
        firstsec  = $d1         ;user-defined, first sector to read
        address   = $d1         ;user-defined
        entry     = $d1d1       ;user-defined
        zpread    = 0           ;set to 1 to allow reading into zero page
                                ;relies on memory wraparound, not supported on IIGS
                                ;also precludes reading to page $FF
        stkread   = 0           ;set to 1 to allow reading into stack page
                                ;but remember about the 6 bytes of stack
        seekback  = 0           ;set to 1 to enable seek backwards
        version   = 1

        ;memory usage:
        ;256 bytes ($bd00-bdff) static table
        grouped   = $bd00
        ;106 bytes ($xx00-xx69) static table
        preshift  = code_end
        zvalue    = $fd         ;only during init
        znibble   = $fe         ;only during init
        zmask     = $ff         ;only during init

        !byte   1               ;we'll read the other two ourselves
        lsr                     ;check sector number

        ;the following TAY is a workaround for a CFFA bug
        ;the bug is that Y isn't zero on entry
        ;the workaround sets it to two instead
        ;it's not zero, but it's better than #$10

        tay
        adc     #$bd
        sta     $27             ;set or update address as needed
        asl
        bmi     +               ;branch if not 3
        inc     $3d             ;increment sector (faster to find)
        txa
        lsr
        lsr
        lsr
        lsr
        ora     #$c0            ;slot to PROM base
        pha
        lda     #$5b            ;read-1
        pha
        rts

+       txa
        ora     #$8c            ;slot to Q6L
-       iny
        ldx     patchtbl-3, y
        sta     code_begin, x   ;replace placeholders with Q6L
        bne     -
        and     #$f8            ;MOTOROFF
        sta     slotpatch7+1
        eor     #8              ;PHASEOFF
        sta     slotpatch8+1
        ldx     #$3f
        stx     zmask
        inx
        ldy     #$7f
        bne     +               ;branch always
*=$839
        jsr     preread
        jmp     $bf00           ;DOS 3.3 launcher entrypoint

patchtbl
        !byte   <(slotpatch1+1), <(slotpatch2+1), <(slotpatch3+1), <(slotpatch4+1), <(slotpatch5+1), <(slotpatch6+1)
indextbl        ;the 0 also terminates the patchtbl list!
        !byte   0, 2, 1, 3

        ;construct denibbilisation table
        ;pre-shifted for interleave read

+
--      sty     znibble
        tya
        asl
        bit     znibble
        beq     +
        ora     znibble
        eor     #$ff
        and     #$7e
-       bcs     +
        lsr
        bne     -
        dex
        txa
        asl
        asl
        sta     preshift-$16, y
+       dey
        bne     --

        ;construct 2-bit group table

        sty     zvalue
--      lsr     zmask
        lsr     zmask
-       lda     indextbl, x
        sta     grouped, y
        inc     zvalue
        lda     zvalue
        and     zmask
        bne     +
        inx
        txa
        and     #3
        tax
+       iny
        iny
        iny
        iny
        cpy     #3
        bcs     -
        iny
        cpy     #3
        bcc     --

preread

        lda     #>(entry-1)
        pha
        lda     #<(entry-1)
        pha

;copy post-read if necessary
;push post-read address here

        lda     #<(firsttrk*2)
        sta     phase+1
        ldx     #sectors
        ldy     #address
        lda     #firstsec
!if seekback { ;no room to do this in the routine
        sta     startsec+1
        stx     total+1
        sty     tmpadr+1
}
        jmp     seekread

*=$8fe
        !byte   $be, 1

;the following lives on sectors $0E and $0D
!pseudopc $be00 {
code_begin
        !byte   version

readnib
slotpatch1
-       lda     $c0d1
        bpl     -
        rts

        ;fill address array for one track

seekread
!if seekback=0 {
        sta     startsec+1
        stx     total+1
        sty     tmpadr+1
}

inittrk
        sec
        lda     #$10
        sbc     startsec+1
        cmp     total+1
        bcs     +
        tax
+       stx     partial1
        stx     partial2
        jsr     seek

startsec
        ldy     #$d1
!if zpread {
        inc     tmpadr+1
}
tmpadr
-       lda     #$d1
        sta     addrtbl, y
!if !zpread {
        inc     tmpadr+1
}
        iny
        dec     partial1
        bne     -

read
--	jsr	readnib
-       cmp     #$d5
        bne     --
	jsr	readnib
        cmp     #$aa
        bne     -
        tay                     ;we need Y=#$AA later
	jsr	readnib
        eor     #$ad            ;zero A if match
        beq     check_mode

        ;if not #$AD, then #$96 is assumed

        ldy     #2              ;volume, track, sector
-	jsr	readnib
        rol                     ;set carry
        sta     sector+1
	jsr	readnib
        and     sector+1
        dey
        bpl     -
        tay
        ldx     addrtbl, y      ;fetch corresponding address
        beq     read
        sta     sector+1        ;store index for later
!if zpread {
        stx     adrpatchx6+2
        dex
}
        stx     adrpatchx5+2
        stx     adrpatch6+2
        stx     adrpatchx1+2
        stx     adrpatchx2+2
        stx     adrpatchx3+2
        stx     adrpatchx4+2
!if !zpread {
        inx
        stx     adrpatchx6+2
        dex
}
        dex
        stx     adrpatch3+2
        stx     adrpatch5+2
!if stkread {
        inx
    !if zpread {
        inx
    }
}
        ldy     #$fe
adrpatchx5
-       lda     $d102, y
        pha
        iny
        bne     -

branch_read
        bcs     read            ;branch always
check_mode
        cpx     #0
        beq     read            ;loop if not expecting #$AD

--      sta     tmpval+1        ;zero rolling checksum
slotpatch2
-       ldx     $c0d1
        bpl     -
        lda     preshift-$96, x
adrpatchx1
        sta     $d102, y         ;store 2-bit array

tmpval
        eor     #$d1
        iny
        bne     --
        ldy     #$aa
slotpatch3
-       ldx     $c0d1
        bpl     -
        eor     preshift-$96, x
adrpatchx2
        ldx     $d102, y        ;bit2tbl
        eor     grouped+2, x    ;first 86 nibbles use group bits 0-1
adrpatch3
        sta     $d156, y
        iny
        bne     -
        and     #$fc
        ldy     #$aa
slotpatch4
-       ldx     $c0d1
        bpl     -
        eor     preshift-$96, x
adrpatchx3
        ldx     $d102, y        ;bit2tbl
        eor     grouped+1, x    ;second 86 nibbles use group bits 2-3
adrpatch5
        sta     $d1ac, y
        iny
        bne     -
        and     #$fc
        ldx     #$ac
slotpatch5
-       ldy     $c0d1
        bpl     -
        eor     preshift-$96, y
adrpatchx4
        ldy     $d100, x        ;bit2tbl
        eor     grouped, y      ;last 84 nibbles use group bits 4-5
adrpatch6
        sta     $d100, x
        inx
        bne     -
        and     #$fc
slotpatch6
-       ldy     $c0d1
        bpl     -
        eor     preshift-$96, y
        cmp     #1              ;carry = !zero
        ldy     #1
-       pla
adrpatchx6
        sta     $d100, y
        dey
        bpl     -
branch_read2
        bcs     branch_read     ;branch if checksum failure
sector
        ldy     #$d1
        txa
        sta     addrtbl, y      ;zero corresponding address
        dec     total+1
        dec     partial2        ;adjust remaining count (faster than looping over array)
        sec
        bne     branch_read2    ;read all requested sectors in one track
total
        ldx     #$d1
        beq     driveoff
        inc     phase+1
        inc     phase+1         ;update current track
        jmp     inittrk

driveoff
slotpatch7
        lda     $c0d1

seekret
        rts

seek
        lda     #0
        sta     step+1
copy_cur
curtrk
        lda     #0
        sta     tmpval+1
        sec
phase
        sbc     #$d1
        beq     seekret
!if seekback {
        bcs     +
}
        eor     #$ff
        inc     curtrk+1
!if seekback {
        bcc     ++
+       adc     #$fe
        dec     curtrk+1
++
}
        cmp     step+1
        bcc     +
step
        lda     #$d1
+       cmp     #8
        bcs     +
        tay
        sec
+       lda     curtrk+1
        ldx     step1, y
        bne     +
---     clc
        lda     tmpval+1
        ldx     step2, y
+       stx     sector+1
        and     #3
        rol
        tax
slotpatch8
        sta     $c0d1, x
--      ldx     #$13
-       dex
        bne     -
        dec     sector+1
        bne     --
        lsr
        bcs     ---
        inc     step+1
        bne     copy_cur

step1		!byte 1, $30, $28, $24, $20, $1e, $1d, $1c
step2		!byte $70, $2c, $26, $22, $1f, $1e, $1d, $1c
addrtbl         !fill 16
partial1 = *
partial2 = partial1+1
code_end=partial2+1
}
