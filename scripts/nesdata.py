#!/usr/bin/env python3
from PIL import Image
import base64
import io
import json
import sys


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

def extract_8x8_tile_from_image(img, upperleft):
    x1, y1 = upperleft
    x2, y2 = x1 + 8, y1 + 8

    tile = img.crop((x1, y1, x2, y2))

    transcolor = tile.info['transparency']
    colors = [index for frequency, index
              in tile.getcolors() if index != transcolor]

    colormap = {}
    for mapped, original in enumerate([transcolor] + sorted(colors)):
        colormap[original] = mapped

    bitmap = []
    width, height = tile.size
    for y in range(height):
        row = []
        for x in range(width):
            row.append(colormap[tile.getpixel((x, y))])
        bitmap.append(row)

    return bitmap


def as_ca65_byte_definition(numbers):
    return '.byte ' + ', '.join('$' + format(b, '02X') for b in numbers)


if __name__ == '__main__':
    from pprint import pprint as pp
    with open('../assets/FlutterBerd-Pipe.piskel', 'r') as fp:
        piskel = json.load(fp)
        layer = json.loads(piskel['piskel']['layers'][0])
        content_type, encoded_data = layer['chunks'][0]['base64PNG'].split(',')
        png_bytes = base64.decodebytes(encoded_data.encode())
        img = Image.open(io.BytesIO(png_bytes))

        pp(img)

