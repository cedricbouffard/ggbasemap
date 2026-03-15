#' Rotation Matrix
#'
#' Creates a 2x2 rotation matrix for a given angle
#' @param a Angle in degrees
#' @return 2x2 rotation matrix
#' @export
rot <- function(a) {
  matrix(c(cos(a * pi / 180), sin(a * pi / 180), 
           -sin(a * pi / 180), cos(a * pi / 180)), 2, 2)
}

#' Create Coordinate System with Rotation
#'
#' Creates a coord_sf with rotation applied using Oblique Mercator projection.
#' Also returns the expanded bbox needed to cover the rotated area.
#' @param x sf object to base the extent on
#' @param angle Rotation angle in degrees
#' @param ratio Aspect ratio (width/height) for the output bbox. Default NULL uses natural ratio.
#'   Common values: 16/9 for widescreen, 4/3 for standard, 1 for square.
#' @return List with:
#'   - `coord`: A coord_sf object for the rotated view
#'   - `bbox`: Expanded bbox in WGS84 covering the rotated area (adjusted for ratio if specified)
#'   - `clip_poly`: sf polygon in WGS84 representing the rotated view extent for clipping
#'   - `crs`: The CRS string used for rotation
#'   - `angle`: Rotation angle in degrees
#'   - `ratio`: Aspect ratio (if specified)
#' @export
coord_rotate <- function(x, angle, ratio = NULL) {
  # Temporarily disable S2 to avoid geometry errors
  old_s2 <- sf::sf_use_s2(FALSE)
  on.exit(sf::sf_use_s2(old_s2))
  
  # Get original bbox and centroid
  orig_bbox <- sf::st_bbox(x)
  centroid <- suppressWarnings(sf::st_centroid(sf::st_combine(x)))
  centroid_wgs84 <- sf::st_transform(centroid, 4326)
  centroid_coords <- sf::st_coordinates(centroid_wgs84)
  
  lon <- as.numeric(centroid_coords[1, 1])
  lat <- as.numeric(centroid_coords[1, 2])
  
  # Create rotated CRS
  crs_string <- paste0("+proj=omerc +lat_0=", lat, 
                       " +lonc=", lon, 
                       " +alpha=0 +k=1 +gamma=", angle,
                       " +datum=WGS84 +units=m +no_defs")
  
  # Calculate expanded bbox that covers the rotated area
  # Create a grid of points around the bbox
  bbox_poly <- sf::st_as_sfc(orig_bbox)
  sf::st_crs(bbox_poly) <- sf::st_crs(x)
  
  # Sample points along the bbox edges
  bbox_coords <- sf::st_coordinates(bbox_poly)[, 1:2]
  n_points <- 20
  edge_points <- list()
  
  # Sample points on each edge
  for (i in 1:4) {
    next_i <- ifelse(i == 4, 1, i + 1)
    edge_x <- seq(bbox_coords[i, 1], bbox_coords[next_i, 1], length.out = n_points)
    edge_y <- seq(bbox_coords[i, 2], bbox_coords[next_i, 2], length.out = n_points)
    edge_points[[i]] <- cbind(edge_x, edge_y)
  }
  
  all_points <- do.call(rbind, edge_points)
  
  # Rotate these points around centroid
  cntr <- sf::st_coordinates(centroid)
  rotated_points <- t(apply(all_points, 1, function(pt) {
    (pt - cntr) %*% rot(angle) + cntr
  }))
  
  # Get expanded bbox
  expanded_bbox <- c(
    xmin = min(rotated_points[, 1]),
    ymin = min(rotated_points[, 2]),
    xmax = max(rotated_points[, 1]),
    ymax = max(rotated_points[, 2])
  )
  
  # If ratio is specified, adjust the bbox to fit that aspect ratio
  if (!is.null(ratio)) {
    bbox_width <- expanded_bbox["xmax"] - expanded_bbox["xmin"]
    bbox_height <- expanded_bbox["ymax"] - expanded_bbox["ymin"]
    current_ratio <- bbox_width / bbox_height
    
    centroid_x <- (expanded_bbox["xmin"] + expanded_bbox["xmax"]) / 2
    centroid_y <- (expanded_bbox["ymin"] + expanded_bbox["ymax"]) / 2
    
    if (current_ratio < ratio) {
      # Need to increase width
      new_width <- bbox_height * ratio
      expanded_bbox["xmin"] <- centroid_x - new_width / 2
      expanded_bbox["xmax"] <- centroid_x + new_width / 2
    } else {
      # Need to increase height
      new_height <- bbox_width / ratio
      expanded_bbox["ymin"] <- centroid_y - new_height / 2
      expanded_bbox["ymax"] <- centroid_y + new_height / 2
    }
  }
  
  # Transform x to get extent in rotated CRS
  x_rotated <- sf::st_transform(x, crs = crs_string)
  coords <- sf::st_coordinates(x_rotated)
  
  # Add padding
  x_range <- range(coords[, 1])
  y_range <- range(coords[, 2])
  x_pad <- diff(x_range) * 0.05
  y_pad <- diff(y_range) * 0.05
  
  # If ratio specified, also adjust the coord limits
  if (!is.null(ratio)) {
    coord_width <- diff(x_range)
    coord_height <- diff(y_range)
    coord_current_ratio <- coord_width / coord_height
    
    coord_centroid_x <- mean(x_range)
    coord_centroid_y <- mean(y_range)
    
    if (coord_current_ratio < ratio) {
      # Need to increase width
      new_width <- coord_height * ratio
      x_range <- c(coord_centroid_x - new_width / 2, coord_centroid_x + new_width / 2)
    } else {
      # Need to increase height
      new_height <- coord_width / ratio
      y_range <- c(coord_centroid_y - new_height / 2, coord_centroid_y + new_height / 2)
    }
  }
  
  sf::sf_use_s2(old_s2)
  
  # Calculate the bbox for tiles in the ROTATED CRS with ratio adjustment
  # This ensures the tile bbox matches the coord_sf limits
  tile_x_range <- c(x_range[1] - x_pad, x_range[2] + x_pad)
  tile_y_range <- c(y_range[1] - y_pad, y_range[2] + y_pad)
  
  # Create the tile bbox polygon in rotated CRS
  tile_bbox_rotated <- sf::st_bbox(c(xmin = tile_x_range[1], ymin = tile_y_range[1],
                                      xmax = tile_x_range[2], ymax = tile_y_range[2]))
  tile_bbox_poly <- sf::st_as_sfc(tile_bbox_rotated)
  sf::st_crs(tile_bbox_poly) <- crs_string
  
  # Transform to WGS84 for add_basemap
  tile_bbox_wgs84 <- sf::st_bbox(sf::st_transform(tile_bbox_poly, 4326))
  
  # Create the clip polygon (same as tile bbox)
  clip_poly_wgs84 <- sf::st_transform(tile_bbox_poly, 4326)
  
  list(
    coord = ggplot2::coord_sf(xlim = tile_x_range, 
                              ylim = tile_y_range, 
                              crs = crs_string, expand = FALSE),
    bbox = tile_bbox_wgs84,
    clip_poly = clip_poly_wgs84,
    crs = crs_string,
    angle = angle,
    ratio = ratio
  )
}