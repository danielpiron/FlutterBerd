#!/usr/bin/env python
import math
from pprint import pprint as pp


pp([int(math.sin(s * 2 * math.pi / 8) * 2) + 2 for s in range(8)])
