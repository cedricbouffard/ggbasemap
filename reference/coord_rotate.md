# Create Coordinate System with Rotation

Creates a coord_sf with rotation applied using Oblique Mercator
projection. Also returns the expanded bbox needed to cover the rotated
area.

## Usage

``` r
coord_rotate(x, angle, ratio = NULL)
```

## Arguments

- x:

  sf object to base the extent on

- angle:

  Rotation angle in degrees

- ratio:

  Aspect ratio (width/height) for the output bbox. Default NULL uses
  natural ratio. Common values: 16/9 for widescreen, 4/3 for standard, 1
  for square.

## Value

List with: - \`coord\`: A coord_sf object for the rotated view -
\`bbox\`: Expanded bbox in WGS84 covering the rotated area (adjusted for
ratio if specified) - \`crs\`: The CRS string used for rotation -
\`angle\`: Rotation angle in degrees - \`ratio\`: Aspect ratio (if
specified)
