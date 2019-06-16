#!/usr/bin/env python3


class Tiler():

    def __init__(self, w, h):
        self._tileset = {}
        self._tilemap = [[0] * w for _ in range(h)]

    @staticmethod
    def tuplify_bitmap(bitmap):
        return tuple(tuple(row) for row in bitmap)

    def add_tile(self, bitmap, x, y):
        tile_key = Tiler.tuplify_bitmap(bitmap)
        # If this is a new tile, assign it the length
        # of the tileset.
        if tile_key not in self._tileset:
            self._tileset[tile_key] = len(self._tileset)

        self._tilemap[y][x] = self._tileset[tile_key]

    def get_tileset(self):
        return [bitmap for bitmap, index in sorted(self._tileset.items(), key=lambda t: t[1])]

    def get_tilemap(self):
        return self._tilemap
