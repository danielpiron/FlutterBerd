#!/usr/bin/env python
#
# Parse FamiTracker TXT
#
import sys
import re
from pprint import pprint as pp


def is_comment(line):
    return re.match('\#', line) is not None


def parse_pattern_index(line):
    mo = re.match('\s*PATTERN\s+(?P<pindex>\d+)', line)
    if not mo:
        return -1
    return  int(mo.group('pindex'))


def parse_pattern(lines, numrows):
    COLSEP = ' : '
    rows = []
    for _ in range(numrows):
        line = next(lines)
        declaration, columns = line.split(COLSEP, 1)
        for column in columns.split(COLSEP):
            pp(parse_column(column))

def parse_column(text):
    note, inst, vol, effect = text.split(' ')
    return {
        'note': note,
        'inst': inst,
        'vol': vol,
        'effect': effect,
    }

def parse_track(line):
    mo = re.match('\s*TRACK\s+(?P<numrows>\d+)\s+(?P<speed>\d+)\s+(?P<tempo>\d+)\s+\"(?P<title>.*)\"$', line)
    if not mo:
        return {}

    return {
            'numrows': int(mo.group('numrows')),
            'speed': int(mo.group('speed')),
            'tempo': int(mo.group('tempo')),
            'title': mo.group('title')
            }

if __name__ == '__main__':
    track = {}
    reading_patterns = False
    with open(sys.argv[1], 'r') as f:
        # Strip comments and empty line to simplfy parsing
        lines = iter([line.strip()
                      for line in f.readlines()
                      if not is_comment(line)
                      and not line.isspace()])
        try:
            while(True):
                line = next(lines)
                if line.startswith('TRACK'):
                    track = parse_track(line)
                elif line.startswith('PATTERN'):
                    i = parse_pattern_index(line)
                    parse_pattern(lines, track['numrows'])
        except StopIteration:
            pass

        pp(track)

