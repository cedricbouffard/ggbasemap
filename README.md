# ggbasemap <img src="man/figures/logo.png" align="right" height="139" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/yourusername/ggbasemap/workflows/R-CMD-check/badge.svg)](https://github.com/yourusername/ggbasemap/actions)
[![Codecov test coverage](https://codecov.io/gh/yourusername/ggbasemap/branch/main/graph/badge.svg)](https://codecov.io/gh/yourusername/ggbasemap?branch=main)
[![CRAN status](https://www.r-pkg.org/badges/version/ggbasemap)](https://CRAN.R-project.org/package=ggbasemap)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**Add XYZ tile basemaps to ggplot2 with automatic zoom calculation, image transformations, and map rotation.**

## Overview

`ggbasemap` makes it effortless to add basemap tiles from services like OpenStreetMap, Google, ESRI, and CartoDB to your ggplot2 visualizations. It automatically detects data extents, calculates optimal zoom levels, and provides powerful image styling options.

### Key Features

- 🗺️ **Automatic Everything**: Detects bounding boxes and calculates optimal zoom
- 🎨 **Image Styling**: Grayscale, saturation, brightness, contrast, and gamma adjustment
- 🔄 **Map Rotation**: Rotate maps to any angle with Oblique Mercator projection
- 🚀 **High Performance**: Native Web Mercator (EPSG:3857) for sharpest display
- 🔧 **Flexible**: Works with sf objects, data frames, or manual bounding boxes
- 📱 **Multiple Sources**: OpenStreetMap, Google, ESRI, CartoDB, and custom XYZ tiles

## Installation

```r
# Install from CRAN (when available)
install.packages("ggbasemap")

# Or the development version from GitHub
# install.packages("devtools")
devtools::install_github("yourusername/ggbasemap")
```

## Quick Start

### Basic Map with sf Objects

```r
library(ggbasemap)
library(ggplot2)
library(sf)

# Read spatial data
nc <- st_read(system.file("shape/nc.shp", package = "sf"))

# Create map with basemap
ggplot() +
  add_basemap(nc) +
  geom_sf(data = nc, fill = NA, color = "red", linewidth = 1)
```

### With Data Frames

```r
df <- data.frame(
  lon = c(-74.0060, -73.9352),
  lat = c(40.7128, 40.7306),
  city = c("NYC", "Manhattan")
)

ggplot() +
  add_basemap(df, "lon", "lat") +
  geom_point(data = df, aes(x = lon, y = lat), color = "red", size = 3)
```

### Image Transformations

```r
# Grayscale
ggplot() +
  add_basemap(nc, grayscale = TRUE) +
  geom_sf(data = nc)

# Styled - Vintage look
ggplot() +
  add_basemap(nc, 
              saturation = 0.3,
              brightness = 0.9,
              contrast = 1.2) +
  geom_sf(data = nc)

# High contrast satellite
ggplot() +
  add_basemap(nc,
              url = "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}",
              contrast = 1.4,
              gamma = 0.9) +
  geom_sf(data = nc)
```

### Map Rotation

```r
# Rotate map 45 degrees
rot <- coord_rotate(nc, 45)

ggplot() +
  add_basemap(nc, bbox = rot$bbox) +
  geom_sf(data = nc) +
  rot$coord
```

## Documentation

Full documentation is available at [https://cedricbouffard.github.io/ggbasemap](https://cedricbouffard.github.io/ggbasemap)

- **[Introduction](https://cedricbouffard.github.io/ggbasemap/articles/introduction.html)**: Get started with ggbasemap
- **[Image Transformations](https://cedricbouffard.github.io/ggbasemap/articles/transformations.html)**: Style your basemaps
- **[Map Rotation](https://cedricbouffard.github.io/ggbasemap/articles/rotation.html)**: Create rotated maps

## Supported Tile Sources

- **OpenStreetMap** (default): `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- **Google Satellite**: `https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}`
- **ESRI World Imagery**: `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}`
- **CartoDB Positron**: `https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png`
- **CartoDB Dark Matter**: `https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png`
- **OpenTopoMap**: `https://a.tile.opentopomap.org/{z}/{x}/{y}.png`

## Function Reference

### Main Functions

- `add_basemap()`: Add basemap tiles to ggplot2
- `coord_rotate()`: Create rotated coordinate systems

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `data` | sf object or data frame | `NULL` |
| `x`, `y` | Column names (for data frames) | `NULL` |
| `bbox` | Bounding box vector | `NULL` |
| `url` | Tile server URL | OSM |
| `zoom` | Zoom level (auto + 1) | `NULL` |
| `alpha` | Transparency (0-1) | `1` |
| `grayscale` | Convert to B&W | `FALSE` |
| `saturation` | Color saturation (0-Inf) | `1` |
| `brightness` | Brightness multiplier | `1` |
| `contrast` | Contrast multiplier | `1` |
| `gamma` | Gamma correction | `1` |
| `padding` | Extra space around data | `0.1` |

## Examples Gallery

### Publication-Ready Maps

```r
# Clean, minimal
ggplot() +
  add_basemap(nc, grayscale = TRUE, contrast = 1.2) +
  geom_sf(data = nc, fill = NA, color = "black") +
  theme_void()

# Data-focused
ggplot() +
  add_basemap(nc, saturation = 0.2) +
  geom_sf(data = nc, aes(fill = value)) +
  scale_fill_viridis_c() +
  theme_minimal()

# High-quality satellite
ggplot() +
  add_basemap(nc,
              url = "ESRI_URL",
              zoom = 14,
              contrast = 1.3,
              gamma = 0.9) +
  geom_sf(data = nc, fill = NA, color = "yellow")
```

## Best Practices

### For Publications

```r
ggplot() +
  add_basemap(data, 
              grayscale = TRUE,  # Print-friendly
              contrast = 1.2) +  # Better ink coverage
  geom_sf(data = data) +
  theme_void()
```

### For Web

```r
ggplot() +
  add_basemap(data,
              saturation = 1.1,  # More vibrant
              brightness = 1.05) + # Brighter for screens
  geom_sf(data = data)
```

### For Large Areas

```r
ggplot() +
  add_basemap(big_country, 
              zoom = 6,        # Lower zoom
              padding = 0.05) + # Less padding
  geom_sf(data = big_country)
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Thanks to the [ggplot2](https://ggplot2.tidyverse.org/) team for the amazing visualization framework
- Thanks to [ggspatial](https://paleolimbot.github.io/ggspatial/) for spatial ggplot2 utilities
- Tile providers: OpenStreetMap, Google, ESRI, CartoDB, and others

## Citation

If you use `ggbasemap` in your research, please cite:

```bibtex
@software{ggbasemap,
  title = {ggbasemap: Add XYZ Tile Basemaps to ggplot2},
  author = {Your Name},
  year = {2024},
  url = {https://github.com/yourusername/ggbasemap}
}
```

---

**Note**: This package requires an internet connection to download tiles. Please be respectful of tile server usage policies and cache results when possible.
