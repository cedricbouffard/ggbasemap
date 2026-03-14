# Introduction to ggbasemap

``` r

library(ggbasemap)
library(ggplot2)
library(sf)
#> Linking to GEOS 3.13.1, GDAL 3.11.4, PROJ 9.7.0; sf_use_s2() is TRUE
```

## Overview

**ggbasemap** is an R package that makes it easy to add basemap tiles
from XYZ tile servers (like OpenStreetMap, Google, ESRI) to ggplot2
plots. It automatically detects bounding boxes, calculates appropriate
zoom levels, and handles all the technical details of fetching and
displaying tiles.

### Key Features

- **Automatic zoom calculation**: No need to guess the right zoom level
- **Multiple tile sources**: Works with OpenStreetMap, Google, ESRI,
  CartoDB, and more
- **Image transformations**: Grayscale, saturation, brightness,
  contrast, gamma
- **Map rotation**: Rotate maps to any angle using Oblique Mercator
  projection
- **Web Mercator native**: Tiles are kept in EPSG:3857 for sharpest
  display
- **sf compatible**: Works seamlessly with sf objects

## Quick Start

### Installation

``` r

# Install from GitHub
devtools::install_github("yourusername/ggbasemap")

# Or from local source
devtools::install("path/to/ggbasemap")
```

### Basic Usage with sf Objects

The simplest way to use `ggbasemap` is with an sf object:

``` r

# Load required libraries
library(ggbasemap)
library(ggplot2)
library(sf)

# Read some spatial data
nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)

# Create a map with basemap
ggplot() +
  add_basemap(nc) +
  geom_sf(data = nc, fill = NA, color = "red", linewidth = 1)
```

This will: 1. Extract the bounding box from `nc` 2. Calculate the
optimal zoom level 3. Download tiles from OpenStreetMap 4. Display them
as a background layer

### Using Data Frames

If you have data in a data frame with longitude and latitude columns:

``` r

df <- data.frame(
  city = c("NYC", "Boston", "Philadelphia"),
  lon = c(-74.006, -71.0589, -75.1652),
  lat = c(40.7128, 42.3601, 39.9526)
)

ggplot() +
  add_basemap(df, "lon", "lat") +
  geom_point(data = df, aes(x = lon, y = lat), 
             color = "red", size = 3) +
  geom_text(data = df, aes(x = lon, y = lat, label = city),
            vjust = -1, color = "white")
```

### Different Tile Sources

You can easily switch between different tile providers:

``` r

# OpenStreetMap (default)
ggplot() + add_basemap(nc)

# Google Satellite
ggplot() +
  add_basemap(nc, 
    url = "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}")

# ESRI World Imagery
ggplot() +
  add_basemap(nc,
    url = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}")

# CartoDB Positron (clean, light)
ggplot() +
  add_basemap(nc,
    url = "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png")

# OpenTopoMap (topographic)
ggplot() +
  add_basemap(nc,
    url = "https://a.tile.opentopomap.org/{z}/{x}/{y}.png")
```

## Understanding the Parameters

### Core Parameters

- **`data`**: An sf object or data frame containing your spatial data
- **`x`, `y`**: Column names for longitude and latitude (only for data
  frames)
- **`bbox`**: Optional bounding box to override automatic detection
- **`url`**: Tile server URL template
- **`zoom`**: Zoom level (auto-calculated if not provided)

### Visual Parameters

- **`alpha`**: Transparency (0 = invisible, 1 = opaque)
- **`interpolate`**: Whether to interpolate pixels (default: TRUE)
- **`padding`**: Extra space around your data (default: 0.1 = 10%)

### Image Transformation Parameters

- **`grayscale`**: Convert to black and white (TRUE/FALSE)
- **`saturation`**: Color saturation (0 = grayscale, 1 = normal, \>1 =
  vivid)
- **`brightness`**: Brightness multiplier (1 = normal, \<1 = darker, \>1
  = brighter)
- **`contrast`**: Contrast adjustment (1 = normal, \<1 = flat, \>1 =
  punchy)
- **`gamma`**: Gamma correction (1 = normal, \<1 = brighter midtones,
  \>1 = darker midtones)

## Common Patterns

### Pattern 1: Simple Map

``` r

# Just add basemap to your ggplot
ggplot() +
  add_basemap(my_data) +
  geom_sf(data = my_data)
```

### Pattern 2: Styled Basemap

``` r

# Adjust transparency and sharpness
ggplot() +
  add_basemap(my_data, alpha = 0.7, zoom = 15) +
  geom_sf(data = my_data, fill = NA, color = "red")
```

### Pattern 3: Themed Basemap

``` r

# Create a specific mood
ggplot() +
  add_basemap(my_data,
              grayscale = TRUE,
              brightness = 0.9,
              contrast = 1.2) +
  geom_sf(data = my_data, color = "white")
```

### Pattern 4: With Manual Zoom

``` r

# Force a specific zoom level
ggplot() +
  add_basemap(my_data, zoom = 14) +
  geom_sf(data = my_data)
```

## Tips and Best Practices

### 1. Zoom Level Selection

The package auto-calculates zoom level, but sometimes you want control:

- **Low zoom (5-8)**: Regional/country views
- **Medium zoom (9-12)**: City/state views  
- **High zoom (13-16)**: Neighborhood/street views
- **Very high (17-19)**: Building-level detail

### 2. Handling Large Areas

For large geographic areas, consider:

``` r

# Use lower zoom for large areas
ggplot() +
  add_basemap(big_country, zoom = 6, padding = 0.05) +
  geom_sf(data = big_country)
```

### 3. Combining with Other Layers

``` r

ggplot() +
  # Base layer: basemap
  add_basemap(my_data, alpha = 0.6) +
  # Middle layer: boundaries
  geom_sf(data = boundaries, fill = NA, color = "black") +
  # Top layer: your data
  geom_sf(data = my_data, aes(color = category), size = 2) +
  # Legend and theme
  scale_color_viridis_d() +
  theme_minimal()
```

### 4. Saving Your Maps

``` r

p <- ggplot() +
  add_basemap(nc) +
  geom_sf(data = nc)

# Save with high resolution
ggsave("my_map.png", p, width = 10, height = 8, dpi = 300)
```

## Troubleshooting

### Tiles Not Loading

If you get “Could not fetch any tiles” errors:

1.  Check your internet connection
2.  Try a different tile URL
3.  Some corporate networks block tile servers
4.  Use `verbose = TRUE` to see what’s happening:

``` r

ggplot() +
  add_basemap(my_data, verbose = TRUE) +
  geom_sf(data = my_data)
```

### Blurry Images

The auto-zoom adds +1 for sharper images, but you can increase further:

``` r

ggplot() +
  add_basemap(my_data, zoom = 16) +  # Force high zoom
  geom_sf(data = my_data)
```

### Cropped Maps

If your data is getting cut off, increase padding:

``` r

ggplot() +
  add_basemap(my_data, padding = 0.3) +  # 30% extra space
  geom_sf(data = my_data)
```

## Next Steps

- Learn about **[Map
  Rotation](https://cedricbouffard.github.io/ggbasemap/articles/rotation.md)**
  to create angled maps
- Explore **[Image
  Transformations](https://cedricbouffard.github.io/ggbasemap/articles/transformations.md)**
  for styled basemaps
- See **[Advanced
  Usage](https://cedricbouffard.github.io/ggbasemap/articles/advanced-usage.md)**
  for power users
- Check the
  **[FAQ](https://cedricbouffard.github.io/ggbasemap/articles/faq.md)**
  for common questions

## References

- [ggplot2 documentation](https://ggplot2.tidyverse.org/)
- [sf package documentation](https://r-spatial.github.io/sf/)
- [ggspatial documentation](https://paleolimbot.github.io/ggspatial/)
- [Slippy Map
  Tilenames](https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames) -
  Technical details on XYZ tiles
