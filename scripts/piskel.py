#!/usr/bin/env python3
from PIL import Image

import base64
import json
import io


class Piskel:


    class Layer:

        def __init__(self, frame_width, frame_height, json_text):
            layer = json.loads(json_text)
            self._name = layer['name']
            self._opacity = layer['opacity']
            # 'Allocate' list of frames. We will fill in frames as we read
            # chunks. TODO: Verify there are no Nones left once chunks are read
            self._frames = [None] * layer['frameCount']

            for chunk in layer['chunks']:
                centent_type, encoded_data = chunk['base64PNG'].split(',')
                png_bytes = base64.decodebytes(encoded_data.encode())
                image = Image.open(io.BytesIO(png_bytes))

                layout_rows = len(chunk['layout'])
                layout_columns = len(chunk['layout'][0])

                for col, layout_col in enumerate(chunk['layout']):
                    for row, frame_index in enumerate(layout_col):
                        x1, y1 = col * frame_width, row * frame_height
                        x2, y2 = x1 + frame_width, y1 + frame_height
                        self._frames[frame_index] = image.crop((x1, y1, x2, y2))

        @property
        def frames(self):
            return iter(self._frames)

        @property
        def frame_count(self):
            return len(self._frames)

    def __init__(self, filename):

        with open(filename, 'r') as fp:
            piskel = json.load(fp)['piskel']
            self._name = piskel['name']
            self._description = piskel['description']
            self._width = piskel['width']
            self._height = piskel['height']
            self._fps = piskel['fps']
            # Layers are stored as a list
            self._layers = [Piskel.Layer(self._width, self._height, layer_json) for layer_json in piskel['layers']]

    @property
    def name(self):
        return self._name

    @property
    def description(self):
        return self._description

    @property
    def width(self):
        return self._width

    @property
    def height(self):
        return self._height

    @property
    def fps(self):
        return self._fps

    @property
    def frame_count(self):
        return self._layers[0].frame_count

    @property
    def frames(self):
        return self._layers[0].frames


if __name__ == '__main__':
    p = Piskel('../assets/FlutterBerd-FlappingAnim.piskel')
    print('Name:', p.name)
    print('Description:', p.description)
    print('Dimensions: {}x{}'.format(p.width, p.height))
    print('FPS:', p.fps)
    print('Frames:', p.frame_count)
    
    

