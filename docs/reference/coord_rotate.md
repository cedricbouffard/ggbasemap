# Create Coordinate System with Rotation

Creates a coord_sf with rotation applied using Oblique Mercator
projection. Also returns the expanded bbox needed to cover the rotated
area.

## Usage

``` r
coord_rotate(x, angle)
```

## Arguments

- x:

  sf object to base the extent on

- angle:

  Rotation angle in degrees

## Value

List with coord (coord_sf), bbox (expanded bbox in WGS84), and crs
