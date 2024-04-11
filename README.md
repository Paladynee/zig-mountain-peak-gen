![processed](https://github.com/Paladynee/zig-mountain-peak-gen/assets/62181440/22f41e69-f66d-45eb-a645-c11cfbb1c15d)

# mountain peak generation using zig
this is one of my first zig projects. i implemented an idea from Josh's Channel titled [Better Mountain Generators That Aren't Perlin Noise or Erosion](https://www.youtube.com/watch?v=gsJHzBTPG0Y).

The idea is that you spawn pixels on the canvas, and they move around completely randomly until they get in contact with another pixel. This somehow generates some really unique mountain like patterns.
The only catch is that it's SLOW.

run `zig build run` to generate ~1800 bmp files inside `./images/`
