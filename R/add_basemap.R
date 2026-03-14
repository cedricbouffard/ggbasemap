#' Add Basemap Tiles to ggplot2
#'
#' Adds basemap tiles from an XYZ tile server to a ggplot2 plot.
#' Uses ggspatial for proper coordinate management and tile stitching.
#' Automatically calculates the appropriate zoom level.
#'
#' @param data A data frame or sf object containing the spatial data (optional if bbox is provided)
#' @param x The name of the longitude column. Can be unquoted (bare name) or quoted (character string). Optional if data is sf object or bbox is provided.
#' @param y The name of the latitude column. Can be unquoted (bare name) or quoted (character string). Optional if data is sf object or bbox is provided.
#' @param bbox Bounding box as c(xmin, ymin, xmax, ymax) or sf bbox object in WGS84 (EPSG:4326). Optional if data is provided.
#' @param crs Coordinate reference system (default: 4326 for WGS84). Can be an EPSG code or crs object.
#' @param url XYZ tile URL template with {x}, {y}, {z} placeholders
#' @param zoom Zoom level (optional, auto-calculated if not provided)
#' @param alpha Transparency of the basemap (0-1)
#' @param hires Download high resolution tiles by increasing zoom level (default FALSE). When TRUE, adds +2 to zoom level for sharper images.
#' @param interpolate Whether to interpolate the raster image
#' @param padding Fraction of range to add as padding around the data (default 0.1)
#' @param grayscale Convert image to grayscale (default FALSE)
#' @param saturation Saturation multiplier (1 = no change, 0 = grayscale, >1 = more saturated, default 1)
#' @param brightness Brightness multiplier (1 = no change, <1 = darker, >1 = brighter, default 1)
#' @param contrast Contrast multiplier (1 = no change, <1 = less contrast, >1 = more contrast, default 1)
#' @param gamma Gamma correction value (1 = no change, <1 = brighter midtones, >1 = darker midtones, default 1)
#' @param verbose Print debugging information (default FALSE)
#'
#' @return A ggplot2 layer (or list of layers) that can be added to a plot
#' @export
#' @importFrom httr GET content timeout
#' @importFrom png readPNG
#' @importFrom rlang ensym as_name is_missing
#' @importFrom sf st_bbox st_as_sf st_set_crs st_transform st_coordinates st_is
#' @importFrom terra rast ext crs
#' @import ggplot2
#'
#' @examples
#' \dontrun{
#' library(ggplot2)
#' 
#' # Method 1: Using a data frame with bare column names
#' df <- data.frame(lon = c(-74.0, -73.9), lat = c(40.7, 40.8))
#' ggplot() +
#'   add_basemap(df, lon, lat) +
#'   geom_point(data = df, aes(x = lon, y = lat), color = "red", size = 3)
#'
#' # Method 1b: Using a data frame with quoted column names
#' ggplot() +
#'   add_basemap(df, "lon", "lat") +
#'   geom_point(data = df, aes(x = lon, y = lat), color = "red", size = 3)
#'
#' # Method 2: Using an sf object
#' library(sf)
#' nc <- st_read(system.file("shape/nc.shp", package="sf"))
#' ggplot() +
#'   add_basemap(nc) +
#'   geom_sf(data = nc, fill = NA, color = "red")
#'
#' # Method 3: Using ggspatial layer_spatial
#' ggplot() +
#'   add_basemap(nc) +
#'   layer_spatial(nc, fill = NA, color = "red")
#'
#' # Method 4: Using bbox directly
#' bbox <- c(xmin = -74.1, ymin = 40.6, xmax = -73.8, ymax = 40.9)
#' ggplot() +
#'   add_basemap(bbox = bbox) +
#'   geom_point(data = df, aes(x = lon, y = lat), color = "red", size = 3)
#' }
add_basemap <- function(data = NULL, x = NULL, y = NULL, bbox = NULL, crs = 4326,
                         url = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                         zoom = NULL,
                         alpha = 1,
                         hires = FALSE,
                         interpolate = TRUE,
                         padding = 0.1,
                         grayscale = FALSE,
                         saturation = 1,
                         brightness = 1,
                         contrast = 1,
                         gamma = 1,
                         verbose = FALSE) {
  
  # Determine bbox from inputs
  if (!is.null(bbox)) {
    # Use provided bbox
    if (inherits(bbox, "bbox")) {
      # sf bbox object - check if it has a CRS attribute
      if (!is.null(attr(bbox, "crs"))) {
        bbox_crs <- sf::st_crs(attr(bbox, "crs"))
        if (!is.na(bbox_crs) && bbox_crs$epsg != 4326) {
          stop("bbox must be in WGS84 (EPSG:4326). Use sf::st_bbox(st_transform(your_data, 4326))")
        }
      }
      bbox_vec <- c(xmin = bbox["xmin"], ymin = bbox["ymin"], 
                    xmax = bbox["xmax"], ymax = bbox["ymax"])
    } else {
      # Vector form
      bbox_vec <- bbox
      if (length(bbox_vec) != 4) {
        stop("bbox must be a vector of length 4: c(xmin, ymin, xmax, ymax)")
      }
      names(bbox_vec) <- c("xmin", "ymin", "xmax", "ymax")
      # Check if values look like meters instead of degrees
      if (any(abs(bbox_vec) > 180)) {
        stop("bbox values appear to be in meters (projected CRS). Please provide bbox in WGS84 degrees (EPSG:4326) or use data parameter with sf object.")
      }
    }
  } else if (!is.null(data)) {
    # Extract bbox from data
    if (inherits(data, "sf")) {
      # sf object
      bbox_vec <- extract_bbox_from_sf(data, padding)
    } else if (is.data.frame(data)) {
      # Regular data frame - need x and y
      if (is.null(x) || is.null(y)) {
        stop("For data frames, x and y columns must be specified")
      }
      bbox_vec <- extract_bbox_from_df(data, x, y, padding)
    } else {
      stop("data must be a data.frame or sf object")
    }
  } else {
    stop("Must provide either data (data.frame or sf object) or bbox")
  }
  
  # Calculate zoom level if not provided
  # Add 1 to auto-calculated zoom for sharper images
  if (is.null(zoom)) {
    zoom <- calculate_zoom(bbox_vec) + 1
  }
  
  # Increase zoom for high resolution
  if (hires) {
    zoom <- zoom + 2
    if (verbose) message("High resolution mode: zoom increased to ", zoom)
  }
  
  # Fetch and create raster
  raster_obj <- fetch_and_create_raster(bbox_vec, zoom, url, verbose)

  # Apply image transformations if requested
  if (grayscale || saturation != 1 || brightness != 1 || contrast != 1 || gamma != 1) {
    raster_obj <- apply_image_transforms(raster_obj, grayscale = grayscale, 
                                         saturation = saturation, brightness = brightness,
                                         contrast = contrast, gamma = gamma)
  }

  # Use ggspatial's annotation_spatial for proper coordinate handling
  layer <- ggspatial::annotation_spatial(raster_obj,
                                alpha = alpha,
                                interpolate = interpolate)

  # Return just the layer for direct use in ggplot
  layer
}

#' Extract Bounding Box from sf Object
#'
#' @param data sf object
#' @param padding Fraction to pad
#' @return Named vector with xmin, ymin, xmax, ymax
#' @noRd
extract_bbox_from_sf <- function(data, padding) {
  # Get initial bbox
  bbox <- sf::st_bbox(data)
  
  # Debug output
  bbox_values <- as.numeric(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]))
  
  # Check for NaN/Inf values
  if (any(!is.finite(bbox_values))) {
    stop(sprintf("Invalid bbox values detected: xmin=%s, xmax=%s, ymin=%s, ymax=%s. Check input data geometry.",
                 bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]))
  }
  
  max_abs_value <- max(abs(bbox_values), na.rm = TRUE)
  
  # If any coordinate > 180, it's likely in meters (projected CRS)
  if (max_abs_value > 180) {
    message(sprintf("Converting data from projected CRS (max abs value: %.2f) to WGS84 (EPSG:4326)...", max_abs_value))
    
    # Check if transformation is possible
    data_crs <- sf::st_crs(data)
    if (is.na(data_crs)) {
      stop("Data has no CRS and cannot be converted to WGS84. Please assign a CRS first using st_crs(data) <- EPSG_code")
    }
    
    data <- sf::st_transform(data, 4326)
    bbox <- sf::st_bbox(data)
    
    message(sprintf("After transformation: xmin=%.4f, xmax=%.4f, ymin=%.4f, ymax=%.4f",
                    bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]))
  }
  
  # Validate bbox values are now in valid range
  bbox_values <- as.numeric(c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]))
  if (any(!is.finite(bbox_values))) {
    stop("Invalid bbox values after transformation. Check input data CRS.")
  }
  if (max(abs(bbox_values)) > 180) {
    stop(sprintf("Cannot convert data to WGS84. Max abs value is %.2f. Please provide data in EPSG:4326 or a recognized projected CRS.", 
                 max(abs(bbox_values))))
  }
  
  # st_bbox returns a named vector
  x_range <- c(as.numeric(bbox["xmin"]), as.numeric(bbox["xmax"]))
  y_range <- c(as.numeric(bbox["ymin"]), as.numeric(bbox["ymax"]))
  
  x_padding <- diff(x_range) * padding
  y_padding <- diff(y_range) * padding
  
  c(
    xmin = x_range[1] - x_padding,
    ymin = y_range[1] - y_padding,
    xmax = x_range[2] + x_padding,
    ymax = y_range[2] + y_padding
  )
}

#' Extract Bounding Box from Data Frame
#'
#' @param data Data frame
#' @param x X column name (can be bare name or character string)
#' @param y Y column name (can be bare name or character string)
#' @param padding Fraction to pad
#' @return Named vector with xmin, ymin, xmax, ymax
#' @noRd
extract_bbox_from_df <- function(data, x, y, padding) {
  # Handle both bare names and character strings
  if (is.character(x)) {
    x_var <- x
  } else {
    x_var <- rlang::as_name(rlang::ensym(x))
  }
  
  if (is.character(y)) {
    y_var <- y
  } else {
    y_var <- rlang::as_name(rlang::ensym(y))
  }
  
  if (!(x_var %in% names(data))) {
    stop("Column '", x_var, "' not found in data")
  }
  if (!(y_var %in% names(data))) {
    stop("Column '", y_var, "' not found in data")
  }
  
  x_vals <- data[[x_var]]
  y_vals <- data[[y_var]]
  
  x_range <- range(x_vals, na.rm = TRUE)
  y_range <- range(y_vals, na.rm = TRUE)
  
  x_padding <- diff(x_range) * padding
  y_padding <- diff(y_range) * padding
  
  c(
    xmin = x_range[1] - x_padding,
    ymin = y_range[1] - y_padding,
    xmax = x_range[2] + x_padding,
    ymax = y_range[2] + y_padding
  )
}

#' Calculate Appropriate Zoom Level
#'
#' @param bbox Named vector with xmin, ymin, xmax, ymax
#' @return Integer zoom level
#' @noRd
calculate_zoom <- function(bbox) {
  # Get the width and height in degrees
  width <- bbox["xmax"] - bbox["xmin"]
  height <- bbox["ymax"] - bbox["ymin"]
  
  # Use the larger dimension
  max_dim <- max(width, height)
  
  # Calculate zoom based on dimension
  # Zoom 0 = 360 degrees, each zoom level doubles the resolution
  zoom <- floor(log2(360 / max_dim)) + 1
  
  # Clamp zoom level to valid range (0-19)
  zoom <- max(0, min(19, zoom))
  
  # Ensure minimum zoom for very small areas
  if (max_dim < 0.01) {
    zoom <- min(19, zoom + 2)
  }
  
  as.integer(zoom)
}

#' Convert Lat/Lon to Tile Coordinates
#'
#' @param lon Longitude
#' @param lat Latitude  
#' @param zoom Zoom level
#' @return List with x and y tile coordinates
#' @noRd
latlon_to_tile <- function(lon, lat, zoom) {
  n <- 2^zoom
  x <- floor((lon + 180) / 360 * n)
  y <- floor((1 - log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) / 2 * n)
  list(x = x, y = y)
}

#' Convert Tile Coordinates to Lat/Lon
#'
#' @param x Tile x coordinate
#' @param y Tile y coordinate
#' @param zoom Zoom level
#' @return List with lon and lat
#' @noRd
tile_to_latlon <- function(x, y, zoom) {
  n <- 2^zoom
  lon <- x / n * 360 - 180
  lat <- atan(sinh(pi * (1 - 2 * y / n))) * 180 / pi
  list(lon = lon, lat = lat)
}

#' Fetch Tiles and Create Raster
#'
#' @param bbox Bounding box
#' @param zoom Zoom level
#' @param url XYZ URL template
#' @return terra SpatRaster object
#' @noRd
fetch_and_create_raster <- function(bbox, zoom, url, verbose = FALSE) {
  # Convert bbox corners to tile coordinates
  tl <- latlon_to_tile(bbox["xmin"], bbox["ymax"], zoom)
  br <- latlon_to_tile(bbox["xmax"], bbox["ymin"], zoom)
  
  # Get tile ranges
  x_range <- seq(tl$x, br$x)
  y_range <- seq(tl$y, br$y)
  
  if (verbose) {
    message("Zoom: ", zoom)
    message("Tile ranges - x: ", min(x_range), " to ", max(x_range), 
            ", y: ", min(y_range), " to ", max(y_range))
    message("Total tiles: ", length(x_range) * length(y_range))
  }
  
  # Download tiles
  tiles <- list()
  tile_count <- 0
  errors <- list()
  
  for (x in x_range) {
    for (y in y_range) {
      tile_url <- gsub("\\{z\\}", zoom, url)
      tile_url <- gsub("\\{x\\}", x, tile_url)
      tile_url <- gsub("\\{y\\}", y, tile_url)
      
      if (verbose) {
        message("Fetching: ", tile_url)
      }
      
      tile_data <- tryCatch({
        # Add user agent to avoid blocks
        response <- httr::GET(
          tile_url, 
          httr::timeout(30),
          httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        )
        
        status <- httr::status_code(response)
        content_type <- httr::headers(response)[['content-type']]
        
        if (verbose) {
          message("  Status: ", status)
          if (!is.null(content_type)) {
            message("  Content-Type: ", content_type)
          }
        }
        
        if (status == 200) {
          content <- httr::content(response, "raw")
          # Check if content is valid
          if (length(content) == 0) {
            if (verbose) message("  Empty content")
            NULL
          } else {
            # Try to read as PNG first, then JPEG
            img <- tryCatch({
              png::readPNG(content)
            }, error = function(e) {
              # Try JPEG if PNG fails
              tryCatch({
                jpeg::readJPEG(content)
              }, error = function(e2) {
                if (verbose) message("  Could not read as PNG or JPEG")
                NULL
              })
            })
            
            if (!is.null(img)) {
              list(
                data = img,
                x = x,
                y = y,
                zoom = zoom
              )
            } else {
              NULL
            }
          }
        } else {
          errors[[length(errors) + 1]] <- paste("HTTP", status, "for", tile_url)
          NULL
        }
      }, error = function(e) {
        errors[[length(errors) + 1]] <- paste("Error:", conditionMessage(e), "for", tile_url)
        NULL
      })
      
      if (!is.null(tile_data)) {
        tile_count <- tile_count + 1
        tiles[[tile_count]] <- tile_data
      }
    }
  }
  
  if (tile_count == 0) {
    error_msg <- "Could not fetch any tiles. Check your URL and internet connection."
    if (length(errors) > 0) {
      error_msg <- paste0(error_msg, "\nErrors encountered:\n", 
                         paste(head(errors, 5), collapse = "\n"))
    }
    stop(error_msg)
  }
  
  if (verbose) {
    message("Successfully fetched ", tile_count, " tiles")
  }
  
  # Create a combined raster using terra
  create_terra_raster(tiles, x_range, y_range, zoom)
}

#' Create Terra Raster from Tiles
#'
#' @param tiles List of tile data
#' @param x_range X tile range
#' @param y_range Y tile range
#' @param zoom Zoom level
#' @return terra SpatRaster
#' @noRd
create_terra_raster <- function(tiles, x_range, y_range, zoom) {
  if (length(tiles) == 0) {
    stop("No tiles to create raster from")
  }
  
  # Get tile dimensions
  tile_size <- nrow(tiles[[1]]$data)
  n_channels <- if (length(dim(tiles[[1]]$data)) == 3) dim(tiles[[1]]$data)[3] else 1
  
  # Calculate extent in lat/lon
  # Note: y coordinates in tiles go from top (north) to bottom (south)
  tl <- tile_to_latlon(min(x_range), min(y_range), zoom)
  br <- tile_to_latlon(max(x_range) + 1, max(y_range) + 1, zoom)
  
  # For single tile
  if (length(tiles) == 1) {
    img <- tiles[[1]]$data
    
    # Convert to matrix/array for terra
    if (n_channels == 1) {
      # Grayscale
      r <- terra::rast(img)
    } else {
      # RGB or RGBA
      r_list <- list()
      for (i in 1:n_channels) {
        r_list[[i]] <- terra::rast(img[,,i])
      }
      r <- terra::rast(r_list)
    }
    
    # Set extent in Web Mercator (EPSG:3857) for sharpest display
    tl_merc <- latlon_to_mercator(tl$lat, tl$lon)
    br_merc <- latlon_to_mercator(br$lat, br$lon)
    
    terra::ext(r) <- terra::ext(tl_merc$x, br_merc$x, br_merc$y, tl_merc$y)
    terra::crs(r) <- "EPSG:3857"
    
    return(r)
  }
  
  # For multiple tiles, stitch them together
  nx <- length(x_range)
  ny <- length(y_range)
  
  # Create arrays for each channel
  if (n_channels > 1) {
    channel_arrays <- list()
    for (ch in 1:n_channels) {
      channel_arrays[[ch]] <- array(0, dim = c(tile_size * ny, tile_size * nx))
    }
  } else {
    combined <- matrix(0, nrow = tile_size * ny, ncol = tile_size * nx)
  }
  
  # Place tiles
  # In XYZ tile coordinates: y=0 is at the top (north), y increases going south
  # In image coordinates: row 1 is at the top, row numbers increase going down
  # So: smallest tile y -> row 1 (top), largest tile y -> row ny (bottom)
  # No flipping needed because both systems go top-to-bottom!
  for (tile in tiles) {
    x_idx <- which(x_range == tile$x)
    y_idx <- which(y_range == tile$y)
    
    if (length(x_idx) > 0 && length(y_idx) > 0) {
      # y_idx is already in the correct order (1 = smallest y = top)
      row_start <- (y_idx - 1) * tile_size + 1
      row_end <- y_idx * tile_size
      col_start <- (x_idx - 1) * tile_size + 1
      col_end <- x_idx * tile_size
      
      if (n_channels > 1) {
        for (ch in 1:n_channels) {
          channel_arrays[[ch]][row_start:row_end, col_start:col_end] <- tile$data[,,ch]
        }
      } else {
        combined[row_start:row_end, col_start:col_end] <- tile$data
      }
    }
  }
  
  # Create terra raster from channels
  if (n_channels > 1) {
    r_list <- list()
    for (ch in 1:n_channels) {
      r_list[[ch]] <- terra::rast(channel_arrays[[ch]])
    }
    r <- terra::rast(r_list)
  } else {
    r <- terra::rast(combined)
  }
  
  # Set extent in Web Mercator (EPSG:3857) for sharpest display
  # Convert lat/lon bounds to Web Mercator
  tl_merc <- latlon_to_mercator(tl$lat, tl$lon)
  br_merc <- latlon_to_mercator(br$lat, br$lon)
  
  terra::ext(r) <- terra::ext(tl_merc$x, br_merc$x, br_merc$y, tl_merc$y)
  terra::crs(r) <- "EPSG:3857"
  
  r
}

#' Convert Lat/Lon to Web Mercator (EPSG:3857)
#' @param lat Latitude
#' @param lon Longitude
#' @return List with x and y in meters
#' @noRd
latlon_to_mercator <- function(lat, lon) {
  x <- lon * 20037508.34 / 180
  y <- log(tan((90 + lat) * pi / 360)) / (pi / 180)
  y <- y * 20037508.34 / 180
  list(x = x, y = y)
}

#' Apply Image Transformations
#'
#' Applies image transformations (gamma, brightness, contrast, saturation, grayscale) to a raster
#' @param r terra SpatRaster object (3 bands assumed RGB)
#' @param grayscale Convert to grayscale (logical)
#' @param saturation Saturation multiplier (0-Inf, 1=no change, 0=grayscale, >1=more saturated)
#' @param brightness Brightness multiplier (0-Inf, 1=no change, <1=darker, >1=brighter)
#' @param contrast Contrast multiplier (0-Inf, 1=no change, <1=less contrast, >1=more contrast)
#' @param gamma Gamma correction (0-Inf, 1=no change, <1=brighter midtones, >1=darker midtones)
#' @return Modified terra SpatRaster
#' @noRd
apply_image_transforms <- function(r, grayscale = FALSE, saturation = 1, brightness = 1, contrast = 1, gamma = 1) {
  nlyr <- terra::nlyr(r)
  
  # Get raster values as matrix [ncells, nlayers]
  vals <- terra::values(r)
  
  if (is.null(vals) || nrow(vals) == 0) {
    return(r)
  }
  
  # Apply gamma correction first (non-linear)
  if (gamma != 1) {
    vals <- vals ^ (1 / gamma)
    vals <- pmin(pmax(vals, 0), 1)
  }
  
  # Apply brightness (linear)
  if (brightness != 1) {
    vals <- vals * brightness
    vals <- pmin(pmax(vals, 0), 1)
  }
  
  # Apply contrast (centered on 0.5)
  if (contrast != 1) {
    vals <- (vals - 0.5) * contrast + 0.5
    vals <- pmin(pmax(vals, 0), 1)
  }
  
  # If we have 3 bands (RGB), apply color transformations
  if (nlyr >= 3) {
    # Extract RGB
    r_vals <- vals[, 1]
    g_vals <- vals[, 2]
    b_vals <- vals[, 3]
    
    if (grayscale || saturation != 1) {
      # Calculate luminance (weighted grayscale)
      luminance <- 0.299 * r_vals + 0.587 * g_vals + 0.114 * b_vals
      
      if (grayscale) {
        # Full grayscale - all channels equal luminance
        r_vals <- luminance
        g_vals <- luminance
        b_vals <- luminance
      } else {
        # Adjust saturation
        # For each channel: move toward or away from luminance
        r_vals <- luminance + (r_vals - luminance) * saturation
        g_vals <- luminance + (g_vals - luminance) * saturation
        b_vals <- luminance + (b_vals - luminance) * saturation
        
        # Clamp values to [0, 1]
        r_vals <- pmin(pmax(r_vals, 0), 1)
        g_vals <- pmin(pmax(g_vals, 0), 1)
        b_vals <- pmin(pmax(b_vals, 0), 1)
      }
      
      # Put back
      vals[, 1] <- r_vals
      vals[, 2] <- g_vals
      vals[, 3] <- b_vals
    }
  }
  
  # Update raster values
  terra::values(r) <- vals
  
  return(r)
}
