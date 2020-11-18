
    !section "main", $0801
    !section "code",in="main"
    !section "utils",in="main"
    !section "text",in="main"

    !include "vera.inc"
    !include "x16.inc"

    !script "../lua/x16.lua"



tileMem = $1e000

USE_BITMAP = 0


    !section "main_code",in="code"

    !byte $0b, $08,$01,$00,$9e,$32,$30,$36,$31,$00,$00,$00
start:
    lda #0
    sta BANK_SELECT

    SetFileName("IMAGE");
    jsr kernel_load

    lda #0
    sta BANK_SELECT

    sei
    lda #SCALE_2X
    sta HSCALE
    sta VSCALE

;    BorderOn()

    lda #0
    sta BORDER

    LoadColors(colors)

    SetVReg(0)

    SetVAdr($0000 | INC_1)
    jsr copy_image

    SetL1Tiles(0x00000, 8, 8)
    SetL1MapBase(tileMem)

    !if USE_BITMAP {
        lda #MAP_WIDTH_64 | MAP_HEIGHT_64 | DEPTH_8BPP | BITMAP_MODE
        sta L1_CONFIG
    } else {
        lda #MAP_WIDTH_64 | MAP_HEIGHT_64 | DEPTH_8BPP
        sta L1_CONFIG
        SetVAdr(tileMem+4 | INC_1)
        jsr copy_indexes  
    }

    lda #2
    sta $9fb5


vbl:


    WaitLine(0)

    jsr techtech_effect


    jmp vbl

copy_indexes:


    ldy #80
    ldx #0
    clc
.loop
    lda indexes,x
    sta DATA0
    dey
    bne +

    ldy #128-80
    lda #0
.x  sta DATA0
    dey
    bne .x
    ldy #80
$
    inx
    bne .loop
    inc .loop+2
    lda .loop+2
    cmp  #((indexes_end+128)>>8)
    bne .loop

    rts

; ---------------------------------------------------------------------------

; Copy image data to VRAM
copy_image:
    lda #0
    sta BANK_SELECT
.loop2
    ldx #0
    ldy #32
    lda #pixels>>8
    sta .loop+2
.loop
    lda pixels,x
    sta DATA0
    inx
    bne .loop
    inc .loop+2
    dey
    bne .loop

    inc BANK_SELECT
    lda #8
    cmp BANK_SELECT
    bne .loop2
    rts


    
!test "pixel_copy"
    SetVReg(0)
    SetVAdr($0000 | INC_1)
    jsr copy_image

pixel:
    stx ADDR_L
    tax
    lda mul320_lo,y
    clc
    adc ADDR_L
    sta ADDR_L
    lda mul320_hi,y
    adc #0
    sta ADDR_M
    stx DATA0
    rts

mul320_lo:
mul320_hi:
    nop

;!test "pixel"
    stx ADDR_L
    tax
    lda mul320_lo,y
    clc
    adc ADDR_L
    sta ADDR_L
    lda mul320_hi,y
    adc #0
    sta ADDR_M
    stx DATA0
    rts


techtech_effect:

    ldx #100
    ldy #2
.loop3
    NextLine()
.ptr
    lda scales,x
    sta $05
.ptr2
    lda scales,x
    clc
    adc $05

    sta L1_HSCROLL_L

    inx
    bne .loop3
    dey
    bne .loop3

    inc .ptr+1
    inc .ptr2+1
    inc .ptr2+1

    rts


    !align 256
scales:
    !rept 256 { !byte (sin(i*Math.Pi*2/256)+1) * 10}
    !rept 256 { !byte (sin(i*Math.Pi*2/256)+1) * 10}

save: !byte 0,0

    load_png("../data/face.png")
    layout_image($, 8, 8)
    image = index_tiles($.pixels, 8*8)

indexes:
!if !USE_BITMAP {
    !fill image.indexes
}
indexes_end:

;------------------- INDEX COPY UNIT TEST -----------------

;!test "index_copy"
    SetVReg(0)
    SetVAdr(tileMem | INC_1)
    jsr copy_indexes
    rts

; Check first 2 line of screen tiles
vram = get_vram()
;rept 10 {
;    !assert compare(vram[tileMem+i*128:tileMem+i*128+80], png_indexes.indexes[i*80:(i+1)*80])
;}

;----------------------------------------------------------

    ;!section "colors", *
colors:
    !fill convert_palette($.colors, 12)


    !section "IMAGE", 0xa000, NoStore=true, ToFile=true
pixels:
    !if USE_BITMAP {
        !fill png.pixels
    } else {
        !fill image.tiles
    }




