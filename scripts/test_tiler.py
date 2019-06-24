#!/usr/bin/env python3
import unittest
import tiler


class TestTiler(unittest.TestCase):

    BLANK_TILE = (
            (0, 0, 0, 0, 0, 0, 0, 0),
            (0, 0, 0, 0, 0, 0, 0, 0),
            (0, 0, 0, 0, 0, 0, 0, 0),
            (0, 0, 0, 0, 0, 0, 0, 0),
            (0, 0, 0, 0, 0, 0, 0, 0),
            (0, 0, 0, 0, 0, 0, 0, 0),
            (0, 0, 0, 0, 0, 0, 0, 0),
            (0, 0, 0, 0, 0, 0, 0, 0),
            )

    FILLED_TILE = (
            (1, 1, 1, 1, 1, 1, 1, 1),
            (1, 1, 1, 1, 1, 1, 1, 1),
            (1, 1, 1, 1, 1, 1, 1, 1),
            (1, 1, 1, 1, 1, 1, 1, 1),
            (1, 1, 1, 1, 1, 1, 1, 1),
            (1, 1, 1, 1, 1, 1, 1, 1),
            (1, 1, 1, 1, 1, 1, 1, 1),
            (1, 1, 1, 1, 1, 1, 1, 1),
            )

    def setUp(self):
        self._tileset = tiler.Tileset()

    def test_single_tile(self):
        t = tiler.Tiler(1, 1, self._tileset)
        t.place_tile(self.BLANK_TILE, 0, 0)
        self.assertSequenceEqual([[0]], t.get_tilemap())
        self.assertSequenceEqual([self.BLANK_TILE], self._tileset.as_list())

    def test_two_tiles_side_by_side(self):
        t = tiler.Tiler(2, 1, self._tileset)
        t.place_tile(self.BLANK_TILE, 0, 0)
        t.place_tile(self.FILLED_TILE, 1, 0)
        self.assertSequenceEqual([[0, 1]], t.get_tilemap())
        self.assertSequenceEqual([self.BLANK_TILE, self.FILLED_TILE], self._tileset.as_list())

    def test_checker_board(self):
        t = tiler.Tiler(2, 2, self._tileset)
        # Draw this pattern
        #  |0|1 <-X
        #--+-+--
        # 0|B|F
        #--+----
        # 1|F|B
        # ^-Y
        t.place_tile(self.BLANK_TILE, 0, 0)
        t.place_tile(self.FILLED_TILE, 1, 0)
        t.place_tile(self.FILLED_TILE, 0, 1)
        t.place_tile(self.BLANK_TILE, 1, 1)
        self.assertSequenceEqual([[0, 1],
                                  [1, 0]], t.get_tilemap())
        self.assertSequenceEqual([self.BLANK_TILE, self.FILLED_TILE], self._tileset.as_list())

if __name__ == '__main__':
    unittest.main()
