.export BirdPalette
.export BirdFrame1, BirdFrame2, BirdFrame3, BirdFrame4, BirdFrame5,  BirdFrame6

.export PipePalette
.export PipeBottomCap, PipeShaft, PipeTopCap

.segment "TILES"
    ; Sprite Tiles
    .include "bird.inc"
    .include "deadbird.inc"
    .include "digits.inc"
    .res 8 * 2 * (256 - (24 + 11))
    ; Background Tiles
    .res 8 * 2 ; One blank tile at index 0
    .include "pipe.inc"
    .res 8 * 2 * (256 - 21)

.RODATA

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

    PipePalette:
        .byte $0F, $0D, $1A, $20

    ; Pipe tile indices
    PipeShaft:
        .byte $05, $06, $07, $08

    PipeBottomCap:
        .byte $09, $0A, $0B, $0C

    PipeTopCap:
        .byte $01, $02, $03, $04
