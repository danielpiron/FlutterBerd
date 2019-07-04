#!/usr/bin/env python3
import piskel
import tiler

import argparse
import base64
import io
import json
import sys

NES_PALETTE = [
# $00
    (84, 84, 84),
    (0, 30, 116),
    (8, 16, 144),
    (48, 0, 136),
    (68, 0, 100),
    (92, 0, 48),
    (84, 4, 0),
    (60, 24, 0),
    (32, 42, 0),
    (8, 58, 0),
    (0, 64, 0),
    (0, 60, 0),
    (0, 50, 60),
    (0, 0, 0),
# Black padding
    (0, 0, 0),
    (0, 0, 0),
# $10
    (152, 150, 152),
    (8, 76, 196),
    (48, 50, 236),
    (92, 30, 228),
    (136, 20, 176),
    (160, 20, 100),
    (152, 34, 32),
    (120, 60, 0),
    (84, 90, 0),
    (40, 114, 0),
    (8, 124, 0),
    (0, 118, 40),
    (0, 102, 120),
    (0, 0, 0),
# Black padding
    (0, 0, 0),
    (0, 0, 0),
# $20
    (236, 238, 236),
    (76, 154, 236),
    (120, 124, 236),
    (176, 98, 236),
    (228, 84, 236),
    (236, 88, 180),
    (236, 106, 100),
    (212, 136, 32),
    (160, 170, 0),
    (116, 196, 0),
    (76, 208, 32),
    (56, 204, 108),
    (56, 180, 204),
    (60, 60, 60),
# Black padding
    (0, 0, 0),
    (0, 0, 0),
# $30
    (236, 238, 236),
    (168, 204, 236),
    (188, 188, 236),
    (212, 178, 236),
    (236, 174, 236),
    (236, 174, 212),
    (236, 180, 176),
    (228, 196, 144),
    (204, 210, 120),
    (180, 222, 120),
    (168, 226, 144),
    (152, 226, 180),
    (160, 214, 228),
    (160, 162, 160),
# Black padding
    (0, 0, 0),
    (0, 0, 0),
]


def extract_nth_bits(row, bit=0):
    result = 0
    mask = 1 << bit
    for value in row:
        if value & mask:
            result |= 1
        result <<= 1
    result >>= 1
    return result


def bitmap_to_nes_tile(bitmap):
    for bitplane in range(2):
        for row in bitmap:
            yield extract_nth_bits(row, bitplane)


def extract_8x8_bitmap_from_image(img, upperleft, colormap):
    x1, y1 = upperleft
    x2, y2 = x1 + 8, y1 + 8

    tile = img.crop((x1, y1, x2, y2))


    bitmap = []
    width, height = tile.size
    for y in range(height):
        row = []
        for x in range(width):
            row.append(colormap[tile.getpixel((x, y))])
        bitmap.append(row)

    return bitmap


def build_image_colormap(img):
    transparency = (0, 0, 0, 0)
    colors = [color for _, color in img.getcolors() if color != transparency]

    colormap = {}
    for mapped, original in enumerate([transparency] + sorted(colors)):
        colormap[original] = mapped

    return colormap


def closest_nes_color(color):

    # Return 0x0f for the transparency color (based on convention in SMB)
    if color == (0, 0, 0, 0):
        return 0x0f 

    rgb = (color[0], color[1], color[2])
    color_diffs = [(rgb[0] - nes_color[0])**2 +
                   (rgb[1] - nes_color[1])**2 +
                   (rgb[2] - nes_color[2])**2
                   for nes_color in NES_PALETTE]

    return min(enumerate(color_diffs), key=lambda c: c[1])[0]


def colors_as_nes_palette_values(colors):
    return [closest_nes_color(c) for c in colors]


def as_ca65_byte_definition(numbers):
    return '.byte ' + ', '.join('$' + format(b, '02X') for b in numbers)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='A .piskel to NES metatile compiler')
    parser.add_argument('piskel_files', type=str, nargs='+', help='Files to be compiled')
    parser.add_argument('-o', dest='output', help='.s containing compiled CHR data and metatiles')
    args = parser.parse_args()

    graphics = []
    tileset = tiler.Tileset()  # Tileset to be shared across all files
    for infile in args.piskel_files:

        p = piskel.Piskel(infile)

        frame_colors = set()
        for frame in p.frames:
            frame_colors.update(c[1] for c in frame.getcolors())

        # Transparency may or may not be part of frame_colors. Add it in as
        # the NES always has a transparent 'color' with an index of 0
        from pprint import pprint as pp

        frame_colors.add((0, 0, 0, 0))
        assert(len(frame_colors) <= 4)

        # Since transparency is (0, 0, 0, 0), it will always occupy the 0
        # index of the colormap when frame_colors is sorted.
        colormap = {rgba : idx for idx, rgba in enumerate(sorted(frame_colors))}


        metatiles = []
        for frame in p.frames:
            tiledata = tiler.Tiler(p.width // 8, p.height // 8, tileset)
            for top in range(0, p.height, 8):
                for left in range(0, p.width, 8):
                    bitmap = extract_8x8_bitmap_from_image(frame, (left, top), colormap)
                    tiledata.place_tile(bitmap, left // 8, top // 8)
            metatiles.append(tiledata)

        graphics.append({
            'name': p.name,
            'palette': sorted(colormap.keys()),
            'metatiles': [{'name': 'frame_{}'.format(frame_no),
                          'indicies': m.get_tilemap()}
                         for frame_no, m in enumerate(metatiles)]
            })

    data = {
        'tileset': tileset.as_list(),
        'graphics': graphics
    }

    pp(data)
