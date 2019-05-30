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
.include "bird.inc"
.res 8 * 2 * (256 - 16)
; Background Tiles
.res 8 * 2 ; One blank tile at index 0
.include "pipe.inc"
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
    sta z:PPUCTRLShadow
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
PPUCTRLShadow: .res 1
Center: .res 1
GapRadius: .res 1

    .segment "CODE"

main:

    lda #$0F
    sta z:Center
    lda #$04
    sta z:GapRadius

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

    lda z:PPUCTRLShadow
    ora #%00000100
    sta z:PPUCTRLShadow
    sta PPUCTRL

    bit PPUSTAT
    lda #$20
    sta PPUADDR
    lda #$0A
    sta PPUADDR

    sec
    lda z:Center
    sbc z:GapRadius
    tax
    dex

    lda PipeShaft
@topshaft:
    sta PPUDATA
    dex
    bne @topshaft

; Draw the 'bottom' cap
    lda PipeBottomCap
    sta PPUDATA

; Draw Gap
    lda z:GapRadius
    asl
    tax ; X has GapRadius * 2

    lda #$00
@gap:
    sta PPUDATA
    dex
    bne @gap

; Draw the 'top' cap
    lda PipeTopCap
    sta PPUDATA

; Draw lower part of pipe
    sec
    lda #30 ; NameTable is 30 tiles tall
    sbc z:Center
    sbc z:GapRadius
    tax
    dex

    lda PipeShaft
@bottomshaft:
    sta PPUDATA
    dex
    bne @bottomshaft

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

; Pipe tile indices
PipeShaft:
.byte $05

PipeBottomCap:
.byte $09

PipeTopCap:
.byte $01
