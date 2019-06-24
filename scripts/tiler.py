#!/usr/bin/env python3


class Tileset():

    def __init__(self, capacity=256):
        self._capacity = capacity
        self._tiles = {}

    def has_bitmap(self, bitmap):
        tile_key = Tiler.tuplify_bitmap(bitmap)
        return tile_key in self._tiles

    def add_bitmap(self, bitmap):
        if self.has_bitmap(bitmap):
            return

        next_tile_index = len(self._tiles)
        assert(next_tile_index <  self._capacity)

        tile_key = Tiler.tuplify_bitmap(bitmap)
        self._tiles[tile_key] = next_tile_index

    def as_list(self):
        return [bitmap
                for bitmap, _
                in sorted(self._tiles.items(), key=lambda b: b[1])]

    def __getitem__(self, key):
        if not isinstance(key, tuple):
            key = Tiler.tuplify_bitmap(key)
        return self._tiles[key]


class Tiler():

    def __init__(self, w, h, tileset):
        self._tileset = tileset
        self._tilemap = [[0] * w for _ in range(h)]

    @staticmethod
    def tuplify_bitmap(bitmap):
        return tuple(tuple(row) for row in bitmap)

    def place_tile(self, bitmap, x, y):
        self._tileset.add_bitmap(bitmap)
        self._tilemap[y][x] = self._tileset[bitmap]

    def get_tileset(self):
        return [bitmap for bitmap, index in sorted(self._tileset.items(), key=lambda t: t[1])]

    def get_tilemap(self):
        return self._tilemap
