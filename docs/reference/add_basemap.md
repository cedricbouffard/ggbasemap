# Add Basemap Tiles to ggplot2

Adds basemap tiles from an XYZ tile server to a ggplot2 plot. Uses
ggspatial for proper coordinate management and tile stitching.
Automatically calculates the appropriate zoom level.

## Usage

``` r
add_basemap(
  data = NULL,
  x = NULL,
  y = NULL,
  bbox = NULL,
  crs = 4326,
  url = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  zoom = NULL,
  alpha = 1,
  interpolate = TRUE,
  padding = 0.1,
  grayscale = FALSE,
  saturation = 1,
  brightness = 1,
  contrast = 1,
  gamma = 1,
  verbose = FALSE
)
```

## Arguments

- data:

  A data frame or sf object containing the spatial data (optional if
  bbox is provided)

- x:

  The name of the longitude column. Can be unquoted (bare name) or
  quoted (character string). Optional if data is sf object or bbox is
  provided.

- y:

  The name of the latitude column. Can be unquoted (bare name) or quoted
  (character string). Optional if data is sf object or bbox is provided.

- bbox:

  Bounding box as c(xmin, ymin, xmax, ymax) or sf bbox object. Optional
  if data is provided.

- crs:

  Coordinate reference system (default: 4326 for WGS84). Can be an EPSG
  code or crs object.

- url:

  XYZ tile URL template with x, y, z placeholders

- zoom:

  Zoom level (optional, auto-calculated if not provided)

- alpha:

  Transparency of the basemap (0-1)

- interpolate:

  Whether to interpolate the raster image

- padding:

  Fraction of range to add as padding around the data (default 0.1)

- grayscale:

  Convert image to grayscale (default FALSE)

- saturation:

  Saturation multiplier (1 = no change, 0 = grayscale, \>1 = more
  saturated, default 1)

- brightness:

  Brightness multiplier (1 = no change, \<1 = darker, \>1 = brighter,
  default 1)

- contrast:

  Contrast multiplier (1 = no change, \<1 = less contrast, \>1 = more
  contrast, default 1)

- gamma:

  Gamma correction value (1 = no change, \<1 = brighter midtones, \>1 =
  darker midtones, default 1)

- verbose:

  Print debugging information (default FALSE)

## Value

A ggplot2 layer (or list of layers) that can be added to a plot

## Examples

``` r
if (FALSE) { # \dontrun{
library(ggplot2)

# Method 1: Using a data frame with bare column names
df <- data.frame(lon = c(-74.0, -73.9), lat = c(40.7, 40.8))
ggplot() +
  add_basemap(df, lon, lat) +
  geom_point(data = df, aes(x = lon, y = lat), color = "red", size = 3)

# Method 1b: Using a data frame with quoted column names
ggplot() +
  add_basemap(df, "lon", "lat") +
  geom_point(data = df, aes(x = lon, y = lat), color = "red", size = 3)

# Method 2: Using an sf object
library(sf)
nc <- st_read(system.file("shape/nc.shp", package="sf"))
ggplot() +
  add_basemap(nc) +
  geom_sf(data = nc, fill = NA, color = "red")

# Method 3: Using ggspatial layer_spatial
ggplot() +
  add_basemap(nc) +
  layer_spatial(nc, fill = NA, color = "red")

# Method 4: Using bbox directly
bbox <- c(xmin = -74.1, ymin = 40.6, xmax = -73.8, ymax = 40.9)
ggplot() +
  add_basemap(bbox = bbox) +
  geom_point(data = df, aes(x = lon, y = lat), color = "red", size = 3)
} # }
```
