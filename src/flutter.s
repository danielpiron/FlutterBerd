PPUCTRL = $2000
PPUMASK = $2001
PPUSTAT = $2002
OAMADDR = $2003
PPUSCRL = $2005
PPUADDR = $2006
PPUDATA = $2007


    .segment "HEADER"

INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 1 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID
.byte $02 ; 16k PRG bank count
.byte $01 ; 8k CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding


    .segment "TILES"
; Sprite Tiles
.res 8 * 2 * 256
; Background Tiles
.res 8 * 2
.byte $FF, $8B, $8B, $8B, $8B, $8B, $8B, $8B, $00, $7F, $7F, $7F, $7F, $7F, $7F, $7F
.byte $FF, $CD, $CD, $CD, $CD, $CD, $CD, $CD, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.byte $FF, $80, $80, $80, $80, $80, $80, $80, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.byte $FF, $5F, $BF, $5F, $BF, $5F, $BF, $5F, $00, $A0, $40, $A0, $40, $A0, $40, $A0
.byte $8B, $8B, $8B, $C5, $7F, $7F, $25, $25, $7F, $7F, $7F, $3F, $00, $00, $1F, $1F
.byte $CD, $CD, $CD, $E6, $FF, $FF, $E6, $E6, $FF, $FF, $FF, $FF, $00, $00, $FF, $FF
.byte $80, $80, $80, $81, $FF, $FF, $81, $80, $FF, $FF, $FF, $FE, $00, $00, $FE, $FF
.byte $BF, $5F, $BF, $7F, $FE, $FE, $7C, $BC, $40, $A0, $40, $80, $00, $00, $80, $40
.byte $25, $25, $25, $25, $25, $25, $25, $25, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F
.byte $E6, $E6, $E6, $E6, $E6, $E6, $E6, $E6, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.byte $81, $80, $81, $80, $81, $80, $81, $80, $FE, $FF, $FE, $FF, $FE, $FF, $FE, $FF
.byte $7C, $BC, $7C, $BC, $7C, $BC, $7C, $BC, $80, $40, $80, $40, $80, $40, $80, $40
.byte $25, $25, $7F, $7F, $C5, $8B, $8B, $8B, $1F, $1F, $00, $00, $3F, $7F, $7F, $7F
.byte $E6, $E6, $FF, $FF, $E6, $CD, $CD, $CD, $FF, $FF, $00, $00, $FF, $FF, $FF, $FF
.byte $81, $80, $FF, $FF, $81, $00, $00, $00, $FE, $FF, $00, $00, $FE, $FF, $FF, $FF
.byte $7C, $BC, $FE, $FE, $7F, $BF, $5F, $BF, $80, $40, $00, $00, $80, $40, $A0, $40
.byte $8B, $8B, $8B, $8B, $8B, $8B, $8B, $FF, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $00
.byte $CD, $CD, $CD, $CD, $CD, $CD, $CD, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00
.byte $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00
.byte $5F, $BF, $5F, $BF, $5F, $BF, $5F, $FF, $A0, $40, $A0, $40, $A0, $40, $A0, $00
.res 8 * 2 * (256 - 21)


    .segment "VECTORS"
.word nmi
.word reset
.word irq


    .segment "OAM"
oam: .res 256        ; sprite OAM data to be uploaded by DMA


    .segment "CODE"
reset:
    sei        ; ignore IRQs
    cld        ; disable decimal mode
    ldx #$40
    stx $4017  ; disable APU frame IRQ
    ldx #$ff
    txs        ; Set up stack
    inx        ; now X = 0
    stx PPUCTRL
    stx PPUMASK
    stx $4010  ; disable DMC IRQs
    ; wait for first vblank
    bit PPUSTAT
@vblankwait1:
    bit PPUSTAT
    bpl @vblankwait1

    ; clear all RAM to 0
    lda #0
    ldx #0
@clearmem:
    sta $0000, x
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne @clearmem

    tay
    lda #$f8
@clearsprites:
    sta oam, x
    inx
    bne @clearsprites

    tya  ; At this point A, X, and Y registers are all zero
    ; wait for second vblank
@vblankwait2:
    bit PPUSTAT
    bpl @vblankwait2

    ;  Ready to initialize
    lda #%10010000
    sta PPUCTRL
    jmp main

    .segment "CODE"


nmi:
    pha
    txa
    pha
    tya
    pha

    pla
    tay
    pla
    tax
    pla
    rti

irq:
    rti


    .segment "ZEROPAGE"

    .segment "CODE"

main:

    ; set first background
    bit PPUSTAT
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR

    ldx #$01
    stx PPUDATA
@l1:
    lda PipePalette, x
    sta $2007
    inx
    cpx #$04
    bne @l1

    ; Super manually draw a pipe
    clc
    bit PPUSTAT
    ldy #$20
    sty PPUADDR
    lda #$2A
    sta PPUADDR

    ldy #01
    sty PPUDATA
    ldy #02
    sty PPUDATA
    ldy #03
    sty PPUDATA
    ldy #04
    sty PPUDATA

    ldy #$20
    sty PPUADDR
    adc #$20
    sta PPUADDR

    ldy #$05
    sty PPUDATA
    ldy #$06
    sty PPUDATA
    ldy #$07
    sty PPUDATA
    ldy #$08
    sty PPUDATA

    ldy #$20
    sty PPUADDR
    adc #$20
    sta PPUADDR


    ldx #$00
@midpipe:
    ldy #$09
    sty PPUDATA
    ldy #$0A
    sty PPUDATA
    ldy #$0B
    sty PPUDATA
    ldy #$0C
    sty PPUDATA

    ldy #$20
    sty PPUADDR
    adc #$20
    sta PPUADDR

    inx
    cpx #$04
    bne @midpipe

    ldy #$0D
    sty PPUDATA
    ldy #$0E
    sty PPUDATA
    ldy #$0F
    sty PPUDATA
    ldy #$10
    sty PPUDATA

    ldy #$21
    sty PPUADDR
    lda #$0A
    sta PPUADDR

    ldy #$11
    sty PPUDATA
    ldy #$12
    sty PPUDATA
    ldy #$13
    sty PPUDATA
    ldy #$14
    sty PPUDATA

    lda #$00
    sta PPUSCRL
    sta PPUSCRL

    ; enable background and sprite rendering
    lda #%00011110
    sta PPUMASK

@loopforever:
    jmp @loopforever
    rts

.RODATA

PipePalette:
.byte $0F, $0D, $1A, $20
