PPUCTRL = $2000
PPUMASK = $2001
PPUSTAT = $2002
OAMADDR = $2003
PPUSCRL = $2005
PPUADDR = $2006
PPUDATA = $2007

JOYPAD1 = $4016

BIRD_FLAPPING = 1
BIRD_GLIDING = 2
BIRD_FALLING = 3

GAME_INIT  = 1
GAME_PLAY  = 2
GAME_SHAKE = 3
GAME_DEATH = 4
GAME_IDLE = 5

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
.include "deadbird.inc"
.res 8 * 2 * (256 - 24)
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

    jsr game_logic

    pla
    tay
    pla
    tax
    pla
    rti

irq:
    rti

game_logic:

    lda z:GameState
    cmp #GAME_INIT
    bne:+
    jmp game_init
:
    cmp #GAME_PLAY
    bne :+
    jmp game_play
:
    cmp #GAME_SHAKE
    bne :+
    jmp game_shake
:
    cmp #GAME_DEATH
    bne :+
    jmp game_death
:
    ; If no known gamestate is reached then
    ; do nothing and return, so weird stuff
    ; doesn't happen.
    rts

game_init:
    lda #$08
    sta z:BirdFrameCounter

    ; set first background
    bit PPUSTAT
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR

    lda #$01
    sta PPUDATA
    ldx #$01
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

    lda #$00
    sta PPUSCRL
    sta PPUSCRL

    ; enable background and sprite rendering
    lda #%00011110
    sta PPUMASK

    lda #128
    sta z:BirdHeight+1

    lda #GAME_PLAY
    sta z:GameState

    lda #$09 ; Enable noise and pulse 1
    sta $4015

    rts

game_play:

    jsr PollController1

    lda z:Controller1Changed
    and z:Controller1
    and #$10
    beq :+

    ; Toggle pause flag when START is pressed
    lda z:IsPaused
    eor #$01
    sta z:IsPaused
:

    lda z:IsPaused
    bne @end

    jsr UpdateBird
    jsr CheckCollision
    jsr DrawBird

    ; Add a new piece of world every 32 pixels of scroll
    lda z:ScrollPosition
    and #$3F ; If our position is multiple of 64 (lowest 5 bits are clear)
    bne :+

    jsr ScrollPosInNametableSpace ; Get nametable space 0-63
    lsr                           ; Divide by 4 to get 0-15 range
    lsr                           ; of world space
    clc
    adc #$08                      ; Look ahead 8 spaces
    and #$0F                      ; % 16 to cause wrap around

    tay                           ; Y has index into playing field

    jsr PRNG
    tax ; Save random value in X
    and #%00000011 ; Take lowest 2 bits (range 0-3)
    clc
    adc #03        ; Add two to make a 3-6 range for gap radii
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

:
    jsr UpdateScroll
    jsr DrawWorldStrip

    ; Wrote OAM
    ldx #0
    stx $2003
    lda #>oam
    sta $4014

    ; Least significant bit of scroll position HI byte selects the nametable

    lda #%11111100       ; Clear nametable select
    and z:PPUCTRLShadow  ; portion of PPUCTRLShadow
    sta z:PPUCTRLShadow  ; and Save

    lda z:ScrollPosition+1
    and #%00000001      ; Mask away all except least significant bit
    ora z:PPUCTRLShadow ; OR with PPUCTRL to set nametable (0: $2000, 1: $2400)
    sta z:PPUCTRLShadow ; Save PPUTCTRL and set PPUCTRL
    sta PPUCTRL

    ; Set scroll registers
    bit PPUSTAT             ; Reset toggle to ensure first write is X
    lda z:ScrollPosition+0
    sta PPUSCRL
    lda #$00                ; No vertical scroll, always 0
    sta PPUSCRL

@end:
    rts

game_shake:

    lda z:BirdFrameCounter
    and #$07
    tax

    ; Set scroll registers
    bit PPUSTAT             ; Reset toggle to ensure first write is X
    lda z:ScrollPosition+0

    clc
    adc ScreenShake, x

    sta PPUSCRL
    lda #$00                ; No vertical scroll, always 0
    sta PPUSCRL

    dec z:BirdFrameCounter
    bne :+

    lda #GAME_DEATH
    sta z:GameState
    lda #60
    sta z:BirdFrameCounter
:
    rts


game_death:

    lda z:BirdFrameCounter
    beq @drop

    dec z:BirdFrameCounter
    bne @end

    ; Play falling sound effect
    lda #$8F   ; Duty Cycle = 10, Volume 15
    sta $4000

    lda #(($80 | $40) | ($00 | $04)) ; Enable sweep, sweep down period 4, shift 4
    sta $4001

    lda #$c9 ; Should be G-4 (maybe)
    sta $4002

    lda #($08 << 3)  ; Length '8', high 3 bits of period = 0
    sta $4003

@drop:
    jsr BirdPhysics
    jsr DrawBird

    ; Push sprite data via DMA
    sty OAMADDR
    lda #>oam
    sta $4014
@end:
    lda z:BirdHeight+1
    cmp #248
    bcc :+

    lda #GAME_IDLE
    sta z:GameState
:

    rts

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

IsPaused: .res 1

; Align play field data at a 16 byte boundary, so it's easier to visualize
; with a hex editor.
Padding: .res 1

PlayFieldCenters: .res 16
PlayFieldGapRadii: .res 16

GameState: .res 1

BirdState: .res 1
BirdHeight: .res 2
BirdVelocity: .res 2

Controller1: .res 1
Controller1Prev: .res 1
Controller1Changed: .res 1

    .segment "CODE"

; https://wiki.nesdev.com/w/index.php/Controller_reading_code
; At the same time that we strobe bit 0, we initialize the ring counter
; so we're hitting two birds with one stone here
PollController1:
    ; Save the previous controller state
    lda z:Controller1
    sta z:Controller1Prev

    lda #$01
    ; While the strobe bit is set, buttons will be continuously reloaded.
    ; This means that reading from JOYPAD1 will only return the state of the
    ; first button: button A.
    sta JOYPAD1
    sta z:Controller1
    lsr              ; now A is 0
    ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
    ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
    sta JOYPAD1
:
    lda JOYPAD1
    lsr              ; bit 0 -> Carry
    rol z:Controller1  ; Carry -> bit 0; bit 7 -> Carry
    bcc :-

    lda z:Controller1
    eor z:Controller1Prev
    sta z:Controller1Changed

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
    adc #03        ; Add two to make a 3-6 range for gap radii
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
RenderBackgroundStrip:
    lda z:PPUCTRLShadow
    ora #%00000100 ; Set vertical increment mode
    sta PPUCTRL

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

    ; We do not change PPUCTRLShadow
    ; So we can restore PPUCTRL from here
    lda z:PPUCTRLShadow
    sta PPUCTRL

    rts

; RenderPipe
; Draws upper and lower pipes (obstacles) starting at name table location specified by
; NameTableLow and NameTableHigh. The gap and height are specified by GapRadius and
; Register Y contains pipe slice segment 0-3
; Center respectively. Destroys X, Y, A
RenderPipeStrip:
    lda z:PPUCTRLShadow
    ora #%00000100 ; Set vertical increment mode
    sta PPUCTRL

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

    ; We do not change PPUCTRLShadow
    ; So we can restore PPUCTRL from here
    lda z:PPUCTRLShadow
    sta PPUCTRL

    rts
; Ends RenderPipeStrip

UpdateScroll:
    ; Advance scroll position by 1
    clc
    lda z:ScrollPosition+0
    adc #$01
    sta z:ScrollPosition+0
    lda z:ScrollPosition+1
    adc #$00
    sta z:ScrollPosition+1
    rts

CheckCollision:

    jsr ScrollPosInNametableSpace
    clc                        ; Clear carry flag in anticipation of add
    adc #$10+1                 ; Offset to middle of screen plus one tile to accont for bird's face
    and #$3F
    lsr                        ; There are 4 tiles per pipe
    lsr                        ; Shift right twice to divide by 4 to get into pipe space

    tax                        ; X now indexes which section of the playfield to bird occupies
    lda z:PlayFieldCenters, x
    cmp #$FF                   ; Empty area have Center/Radius set to $FF, collision not possible
    beq @end                   ; Skip to end and return


    sec                        ; Set carry in anticipation of subtraction
    sbc z:PlayFieldGapRadii, x ; (center - radius)
    asl                        ; Shift left 3 times to multiply by 8
    asl                        ; (center - radius) * 8
    asl                        ; Now we are in pixel space like the bird's height

    adc #$04                   ; Add a little head room to make it a little
                               ; easier for the player to squeeze thought.
                               ; NOTE: Carry is not cleared as Center/Radii
                               ; differences will never be greater than 63
                               ; top_bound = (center - radius) * 8 + 4

    cmp z:BirdHeight+1         ; if top_bound >= bird_height goto collisiondetected
    bcs @collisiondetected

    lda z:PlayFieldCenters, x
    adc z:PlayFieldGapRadii, x
    asl
    asl
    asl

    sec
    sbc #$04

    cmp z:BirdHeight+1
    bcc @collisiondetected
;    beq @collisiondetected
;
    jmp @end                   ; No collision occurred

@collisiondetected:
    lda #GAME_SHAKE
    sta z:GameState
    lda #04
    sta z:BirdCurrentFrame
    lda #07
    sta z:BirdFrameCounter

    ; Play 'smack!' sound
    lda #$0f   ; 15 volume, use envelope
    sta $400C
    lda #$02   ; frequency selector
    sta $400E
    lda #$00   ; length counter - 0 => 10 (short blip)
    sta $400F

@end:

    rts

BirdPhysics:
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
    rts


UpdateBird:

    lda z:Controller1Changed ; And most recently changed buttons
    and z:Controller1        ; With buttons currently down
    and #$80                 ; Test is A was just pressed
    beq :+

    lda z:BirdVelocity+1
    cmp #$00
    bmi :+

    lda #$80
    sta z:BirdVelocity+0
    lda #$FC
    sta z:BirdVelocity+1

    lda #BIRD_FLAPPING
    sta z:BirdState

    lda #01
    sta z:BirdFrameCounter  ; Immediately go to flap 'blur' frame
    lsr
    sta z:BirdCurrentFrame

:
    jsr BirdPhysics

    lda z:BirdVelocity+1
    bne :+

    lda #BIRD_GLIDING
    sta z:BirdState
    lda #03
    sta z:BirdCurrentFrame

:
    lda #00
    cmp z:BirdVelocity+1
    bpl @check_floor

    lda #BIRD_FALLING
    sta z:BirdState
    lda z:BirdVelocity+1
    bmi @check_floor

    lda #00
    sta z:BirdCurrentFrame

@check_floor:
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
    lda z:BirdState
    cmp #BIRD_FLAPPING
    bne @endanimation

    dec z:BirdFrameCounter
    bne @endanimation
    inc z:BirdCurrentFrame

    lda z:BirdCurrentFrame
    cmp #$02
    bne :+

    lda #$00         ; Clear bird state at end of animation
    sta z:BirdState
   ; sta z:BirdCurrentFrame
:
    lda #$06    ; Wait 6 frames until next 
    sta z:BirdFrameCounter
@endanimation:
    rts

DrawBird:
    ; Bird is made of 4 sprites arranged around its center
    lda z:BirdCurrentFrame
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

    clc
    lda #$80
    adc BirdXOffsets, y
    sta oam, x
    inx

    iny
    cpy #$04
    bne :-

    rts

; Express scroll position as a tile index across the two nametables 0-63
ScrollPosInNametableSpace:
    ; Use the 9 least significant bits of the scroll position 0-511
    ; and express in tile space by dividing by 3
    lda z:ScrollPosition+1   ; Load hi-byte of scroll position
    lsr                      ; Shift bit 0 into Carry
    lda z:ScrollPosition+0   ; Load lo-byte of scroll position
    ror                      ; Shift once to the right loading carry into bit 7
    lsr                      ;
    lsr                      ; A is now (ScrollPosition & 0x1FF) / 8

    rts

;
; Given X - 0-63 calculate address of top row of nametable
; Destorys A and X
SetNametableAddress:
    txa
    cmp #$20       ; If A greater than or equal to 32
    bcs @selectnt1 ; branch to select name table 1
    ldx #$20       ; else select name table 0
    jmp :+
@selectnt1:
    ldx #$24  ; nametable 1 starts at $2400 in VRAM
    and #$1F  ; Clamp to 0-31 range
:
    stx z:NameTableHigh
    sta z:NameTableLow

    rts

; Draw an 8x240 pixel slice of the world just ahead of the camera
DrawWorldStrip:

    jsr ScrollPosInNametableSpace
    clc
    adc #$20   ; A + 32 to look one 'screen' ahead
    and #$3F   ; Take 6 least significant bits for a 0-63 range
    tay        ; Save A in Y for the next step after this one
    tax
    jsr SetNametableAddress ; Set NameTableLow and High according to X

    tya        ; Restore Y
    ; A can be interpretted as follows
    ; A - 7 6 5 4 3 2|1 0
    ;  Bits 2-7 - Index into our Centers and Radii 'world' data
    ;  Bits 0-1 - Slide number 0-3 of world segment. Each world segment is 4 tiles wide
    lsr                     ; Divide A by 4
    lsr                     ;
    tax                     ; X is now world index 0-15

    tya
    and #$03                ; Take only 2 least significant bits
    tay                     ; Y is now which slice of pipe we want to draw

    ; Read Center and Radii data for this segment of world
    lda z:PlayFieldCenters, x
    sta z:Center
    lda z:PlayFieldGapRadii, x
    sta z:GapRadius

    cmp #$FF
    bne @willdrawpipe             ; If current Radii is not $ff

    jsr RenderBackgroundStrip
    jmp @EndsPipeOrBG

@willdrawpipe:
    jsr RenderPipeStrip

@EndsPipeOrBG:

    rts


main:
    lda #GAME_INIT
    sta z:GameState

@loopforever:
    jmp @loopforever
    rts

.RODATA

BirdFramesLo:
    .byte <BirdFrame1, <BirdFrame2, <BirdFrame3, <BirdFrame4, <BirdFrame5, <BirdFrame6
BirdFramesHi:
    .byte >BirdFrame1, >BirdFrame2, >BirdFrame3, >BirdFrame4, >BirdFrame5, >BirdFrame6

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
; Death Frames
BirdFrame5:
    .byte $10, $11, $14, $15
BirdFrame6:
    .byte $12, $13, $16, $17

BirdXOffsets:
    .byte (8^$FF)+1, 0, (8^$FF)+1, 0

BirdYOffsets:
    .byte (8^$FF)+1, (8^$FF)+1, 0, 0

PipePalette:
.byte $0F, $0D, $1A, $20

; Pipe tile indices
PipeShaft:
.byte $05, $06, $07, $08

PipeBottomCap:
.byte $09, $0A, $0B, $0C

PipeTopCap:
.byte $01, $02, $03, $04

ScreenShake:
    .byte $04, $06, $08, $06, $04, $02, $00, $02

