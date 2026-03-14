# ggbasemap 0.2.0 (Development)

## New Features

### Image Transformations
- Added `grayscale` parameter to convert basemaps to black & white
- Added `saturation` parameter to control color intensity
- Added `brightness` parameter to adjust overall lightness
- Added `contrast` parameter for contrast adjustment
- Added `gamma` parameter for gamma correction
- Transformations can be combined for complex effects

### Map Rotation
- Added `coord_rotate()` function for rotating maps
- Uses Oblique Mercator projection for accurate rotation
- Automatically calculates expanded bounding box
- Supports any rotation angle (positive or negative)

### Improvements
- Tiles now stored in Web Mercator (EPSG:3857) for sharpest display
- Auto-calculated zoom level is now +1 for sharper images
- Better error messages with verbose mode
- Improved tile fetching with retry logic

## Bug Fixes
- Fixed saturation transformation not working correctly
- Fixed handling of named bbox vectors
- Fixed S2 geometry engine compatibility issues
- Fixed CRS string format for older PROJ versions

## Documentation
- Added comprehensive vignettes:
  - Introduction to ggbasemap
  - Image Transformations guide
  - Map Rotation tutorial
  - Advanced Usage examples
  - FAQ
- Added pkgdown site configuration
- Improved function documentation with examples

# ggbasemap 0.1.0 (Initial Release)

## Features
- Basic basemap functionality with XYZ tile servers
- Support for OpenStreetMap, Google, ESRI, CartoDB tiles
- Automatic bounding box detection from sf objects
- Automatic zoom level calculation
- Support for data frames with lon/lat columns
- Alpha transparency control
- Image interpolation option
- Padding control around data
- JPEG and PNG tile support
- Integration with ggspatial for coordinate management

## Functions
- `add_basemap()`: Main function to add basemaps
- Helper functions for coordinate conversions
- Internal functions for tile fetching and raster creation

## Documentation
- Basic README with examples
- Function documentation
- Test suite with good coverage
