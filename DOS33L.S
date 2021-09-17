;qboot DOS 3.3 default launcher support
;copyright (c) Peter Ferrie 2016
;assemble using ACME
!cpu 6502
!to "dos33l",plain
;place on sector 1
*=$BF00
        stx     sectors
        sta     address
        lda     phase
        lsr
        sta     track
-       sty     index + 1
        lda     xlatsec, y
        sta     sector
        lda     #>iocb
        ldy     #<iocb
        jsr     $bd00
index   ldy     #0
        iny
        tya
        and     #$0f
        tay
        bne     +
        inc     track
+       inc     address
        bcc     +
        !byte   $d1
phase   !byte   $d1 ;set by bootsector if qboot loaded to $be00
+       dec     sectors
        bne     -
        rts

sectors !byte   $d1
xlatsec !byte   0, 7, $e, 6, $d, 5, $c, 4, $b, 3, $a, 2, 9, 1, 8, $f
iocb    !byte   1, $60, 1, 0
track   !byte   $d1
sector  !byte   $d1
        !byte   <dct, >dct, 0
address !byte   $d1
        !byte   0, 0, 1, 0, 0, $60, 1
dct     !byte   1, $ef, $d8, 0
