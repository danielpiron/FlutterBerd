PPUCTRL = $2000
PPUMASK = $2001
PPUSTAT = $2002
OAMADDR = $2003
PPUSCRL = $2005
PPUADDR = $2006
PPUDATA = $2007

JOYPAD1 = $4016


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

    ; Push sprite data via DMA
    sty OAMADDR
    lda #>oam
    sta $4014

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

    jsr PollController1
    jsr UpdateBird
    jsr DrawBird

    ldx #0
    stx $2003
    lda #>oam
    sta $4014

    ; Advance scroll position by 1
    clc
    lda z:ScrollPosition+0
    adc #$01
    sta z:ScrollPosition+0
    tax ; Save lower portion for later
    lda z:ScrollPosition+1
    adc #$00
    sta z:ScrollPosition+1
    tay ; Save upper porition for later

    ; X has latest LO byte of scroll
    ; y has latest HI byte of scroll

    ; Least significant bit of scroll position HI byte selects the nametable

    lda #%11111100       ; Clear nametable select
    and z:PPUCTRLShadow  ; portion of PPUCTRLShadow
    sta z:PPUCTRLShadow  ; and Save

    tya                 ; Restore upper portion of scroll
    and #%00000001      ; Mask away all except least significant bit
    ora z:PPUCTRLShadow ; OR with PPUCTRL to set nametable (0: $2000, 1: $2400)
    sta z:PPUCTRLShadow ; Save PPUTCTRL and set PPUCTRL
    sta PPUCTRL

    ; Set scroll registers
    bit PPUSTAT    ; Reset toggle to ensure first write is X
    stx PPUSCRL    ; X had lower porition from before
    lda #$00       ; No vertical scroll, always 0
    sta PPUSCRL

    ; Save the previous controller state
    lda z:Controller1
    sta z:Controller1Prev

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

NameTableHigh: .res 1
NameTableLow: .res 1

RNGSeed: .res 2       ; initialize 16-bit seed to any value except 0

ScrollPosition: .res 2

FrameAddress: .res 2
BirdCurrentFrame: .res 1
BirdFrameCounter: .res 1

; Align play field data at a 16 byte boundary, so it's easier to visualize
; with a hex editor.
Padding: .res 2

PlayFieldCenters: .res 16
PlayFieldGapRadii: .res 16

BirdHeight: .res 2
BirdVelocity: .res 2

Controller1: .res 1
Controller1Prev: .res 1

    .segment "CODE"

; https://wiki.nesdev.com/w/index.php/Controller_reading_code
; At the same time that we strobe bit 0, we initialize the ring counter
; so we're hitting two birds with one stone here
PollController1:
    lda #$01
    ; While the strobe bit is set, buttons will be continuously reloaded.
    ; This means that reading from JOYPAD1 will only return the state of the
    ; first button: button A.
    sta JOYPAD1
    sta Controller1
    lsr              ; now A is 0
    ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
    ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
    sta JOYPAD1
loop:
    lda JOYPAD1
    lsr              ; bit 0 -> Carry
    rol Controller1  ; Carry -> bit 0; bit 7 -> Carry
    bcc loop
    rts

; PRNG - https://wiki.nesdev.com/w/index.php/Random_number_generator
;
; Returns a random 8-bit number in A (0-255), clobbers X (0).
;
; Requires a 2-byte value on the zero page called "seed".
; Initialize seed to any value except 0 before the first call to prng.
; (A seed value of 0 will cause prng to always return 0.)
;
; This is a 16-bit Galois linear feedback shift register with polynomial $002D.
; The sequence of numbers it generates will repeat after 65535 calls.
;
; Execution time is an average of 125 cycles (excluding jsr and rts)

PRNG:
    ldx #8     ; iteration count (generates 8 bits)
    lda RNGSeed+0
:
    asl        ; shift the register
    rol RNGSeed+1
    bcc :+
    eor #$2D   ; apply XOR feedback whenever a 1 bit is shifted out
:
    dex
    bne :--
    sta RNGSeed+0
    cmp #0     ; reload flags
    rts

InitPRNG:
; Set a hard coded initial seed of 0510 (clobbers A)
    lda #$05
    sta RNGSeed+0
    lda #$10
    sta RNGSeed+1
    rts

InitPlayField:
    lda #$FF
    ldx #$00
:   ; Set playfield values to 0xFF (no pipes)
    sta PlayFieldCenters, x
    sta PlayFieldGapRadii, x
    inx
    cpx #$10
    bne :-

    ; Use RNG to populate centers and radii
    ldy #$08  ; Start at second screen
:
    jsr PRNG
    tax ; Save random value in X
    and #%00000011 ; Take lowest 2 bits (range 0-3)
    clc
    adc #02        ; Add two to make a 2-5 range for gap radii
    sta PlayFieldGapRadii, y

    txa ; Restore the randomly generated value
    lsr ; Get the higher nibble
    lsr
    lsr
    lsr
    and #%00000111 ; Take lowest 2 bits (range 0-7)
    ; Not clearing the carry flag, because last add
    ; couldn't have possibly set it.
    adc #11        ; Makes a range (11-18)
    sta PlayFieldCenters, y

    iny    ; Skip a space
    iny
    cpy #$10
    bcc :-

    rts

; Render a 4x30 strip of background
RenderBackground:
    lda z:PPUCTRLShadow
    ora #%00000100 ; Set vertical increment mode
    sta PPUCTRL

    ldy #$00 ; Y indexes the segment of strip we are rendering (0-3)
@renderstrip:
    bit PPUSTAT
    lda NameTableHigh
    sta PPUADDR
    lda NameTableLow
    sta PPUADDR

    ldx #30
    lda #$00
: ; Write 30 0s to name table vertically
    sta PPUDATA
    dex
    bne :-

    inc NameTableLow
    iny
    cpy #4
    bcc @renderstrip

    ; We do not change PPUCTRLShadow
    ; So we can restore PPUCTRL from here
    lda z:PPUCTRLShadow
    sta PPUCTRL

    rts

; RenderPipe
; Draws upper and lower pipes (obstacles) starting at name table location specified by
; NameTableLow and NameTableHigh. The gap and height are specified by GapRadius and
; Center respectively. Destroys X, Y, A
RenderPipe:
    lda z:PPUCTRLShadow
    ora #%00000100 ; Set vertical increment mode
    sta PPUCTRL

    ldy #$00 ; Y indexes the segment of strip we are rendering (0-3)
; Set starting address within nametable
@RenderPipeStrip:
    bit PPUSTAT
    lda z:NameTableHigh
    sta PPUADDR
    lda z:NameTableLow
    sta PPUADDR

    sec
    lda z:Center
    sbc z:GapRadius
    tax
    dex

    lda PipeShaft, y
@topshaft:
    sta PPUDATA
    dex
    bne @topshaft

; Draw the 'bottom' cap
    lda PipeBottomCap, y
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
    lda PipeTopCap, y
    sta PPUDATA

; Draw lower part of pipe
    sec
    lda #30         ; NameTable is 30 tiles tall
    sbc z:Center    ; Subtract Center point
    sbc z:GapRadius ; and gap radius
    tax
    dex             ; Minus -1 to account for pipe cap

    lda PipeShaft, y
@bottomshaft:
    sta PPUDATA
    dex
    bne @bottomshaft

    ; Unless we reach the right edge of the pipe, move onto
    ; next strip
    inc z:NameTableLow
    iny
    cpy #$04
    bne @RenderPipeStrip

    ; We do not change PPUCTRLShadow
    ; So we can restore PPUCTRL from here
    lda z:PPUCTRLShadow
    sta PPUCTRL

    rts
; Ends RenderPipe
;
UpdateBird:

    lda z:Controller1
    eor z:Controller1Prev ; Get keys that changed compared to last
    and #$80              ; If the A key was JUST pressed
    beq :+                ; Skip jump if not pressed

    lda #$80
    sta z:BirdVelocity+0
    lda #$FC
    sta z:BirdVelocity+1

:
    ; Apply gravity to Bird's Velocity
    clc
    lda z:BirdVelocity+0
    adc #$30
    sta z:BirdVelocity+0
    lda z:BirdVelocity+1
    adc #$00
    sta z:BirdVelocity+1

    clc ; Calcuate new position based on velocity
    lda z:BirdHeight+0
    adc z:BirdVelocity+0
    sta z:BirdHeight+0
    lda z:BirdHeight+1
    adc z:BirdVelocity+1
    sta z:BirdHeight+1

    ; If the 230 < BirdHeight
    lda #230
    cmp z:BirdHeight+1
    bcc :+
    jmp @advanceframe
:   ; Clamp height to 230 and zero out velocity
    sta z:BirdHeight+1
    lda #$00
    sta z:BirdVelocity+0
    sta z:BirdVelocity+1

@advanceframe:
    dec z:BirdFrameCounter
    bne :+
    inc z:BirdCurrentFrame
    lda #$08
    sta z:BirdFrameCounter
:
    rts

DrawBird:
    ; Bird is made of 4 sprites arranged around its center
    lda z:BirdCurrentFrame
    and #$03
    tax

    lda BirdFramesLo, x
    sta FrameAddress+0
    lda BirdFramesHi, x
    sta FrameAddress+1

    ldx #$00 ; Curren OAM
    ldy #$00 ; sub-tile index
:
    clc
    lda z:BirdHeight+1   ; Higher portion of heigh contains 'whole'
    adc BirdYOffsets, y  ; Offset sprite from object position
    sta oam, x           ; Store Y Component
    inx

    lda (FrameAddress), y     ; Tile index
    sta oam, x
    inx

    lda #$00             ; No attributes right now (i.e. no flip/mirror)
    sta oam, x           ; Palette is 0 (first)
    inx

    lda #$80
    adc BirdXOffsets, y
    sta oam, x
    inx

    iny
    cpy #$04
    bne :-

    rts

main:
    lda #$08
    sta z:BirdFrameCounter

    ; set first background
    bit PPUSTAT
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR

    ldx #$01
    stx PPUDATA
:
    lda PipePalette, x
    sta PPUDATA
    inx
    cpx #$04
    bne :-

    lda #$3F
    sta PPUADDR
    lda #$11
    sta PPUADDR
    ldx #$01
:
    lda BirdPalette, x
    sta PPUDATA
    inx
    cpx #$04
    bne :-

    jsr InitPRNG
    jsr InitPlayField

    ldx #$08
@WorldDrawLoop:
    ; Pipe rendering parameters
    lda z:PlayFieldCenters, x
    sta z:Center
    lda z:PlayFieldGapRadii, x
    sta z:GapRadius

    ; Calculate starting address of pipe or background
    txa  ; RenderPipe destroys X
    pha  ; Save it on stack for later
    asl  ; X * 4
    asl  ;
    ; Y Will contain high name table value
    cmp #$20       ; If A greater than or equal to 32
    bcs @selectnt1 ; branch to select name table 1
    ldy #$20       ; else select name table 0
    jmp :+
@selectnt1:
    ldy #$24  ; nametable 1 starts at $2400 in VRAM
    and #$1F  ; Clamp to 0-31 range
:
    sty z:NameTableHigh
    sta z:NameTableLow

    lda z:GapRadius
    cmp #$FF
    bne @willdrawpipe             ; If current Radii is not $ff

    jsr RenderBackground          ; Else draw background
    jmp @EndsPipeOrBG

@willdrawpipe:
    jsr RenderPipe

@EndsPipeOrBG:

    pla  ; Restore X counter
    tax

    inx
    cpx #$10
    bne @WorldDrawLoop

@gitout:
    lda #$00
    sta PPUSCRL
    sta PPUSCRL

    ; enable background and sprite rendering
    lda #%00011110
    sta PPUMASK

    lda #128
    sta BirdHeight+1

@loopforever:
    jmp @loopforever
    rts

.RODATA

BirdFramesLo:
    .byte <BirdFrame1, <BirdFrame2, <BirdFrame3, <BirdFrame4
BirdFramesHi:
    .byte >BirdFrame1, >BirdFrame2, >BirdFrame3, >BirdFrame4

BirdPalette:
.byte $0F, $0D, $11, $20

BirdFrame1:
    .byte $00, $01, $08, $09
BirdFrame2:
    .byte $02, $03, $0A, $0B
BirdFrame3:
    .byte $04, $05, $0C, $0D
BirdFrame4:
    .byte $06, $07, $0E, $0F

BirdXOffsets:
    .byte $FF+(-8)+1, 0, $FF+(-8)+1, 0

BirdYOffsets:
    .byte $FF+(-8)+1, $FF+(-8)+1, 0, 0

PipePalette:
.byte $0F, $0D, $1A, $20

; Pipe tile indices
PipeShaft:
.byte $05, $06, $07, $08

PipeBottomCap:
.byte $09, $0A, $0B, $0C

PipeTopCap:
.byte $01, $02, $03, $04
