
    !section "main", $800
!test "my_test"
start:
    ldx #0
.loop
    lda $1000,x
    sta $2000,x
    inx
    cpx #12
    bne .loop
    rts
    !section "data", $1000
    !byte 1,2,3,4,5,6,7


!test
dummy:
    jmp xxx
    nop
xxx:
    lda #4
    rts

    !print tests.my_test.A

!assert compare(tests.my_test.ram[0x2000:0x2007], bytes(1,2,3,4,5,6,7))
!assert tests.my_test.ram[0x2006] == 7
!assert tests.my_test.cycles < 220

!assert tests.dummy.A == 4

