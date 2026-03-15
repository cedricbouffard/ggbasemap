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
  
  # Transform x to get extent in rotated CRS
  x_rotated <- sf::st_transform(x, crs = crs_string)
  coords <- sf::st_coordinates(x_rotated)
  
  # Get data extent in rotated CRS
  x_range <- range(coords[, 1])
  y_range <- range(coords[, 2])
  
  sf::sf_use_s2(old_s2)
  
  # Calculate final ranges with padding in ROTATED CRS (meters)
  x_pad <- diff(x_range) * 0.05
  y_pad <- diff(y_range) * 0.05
  tile_x_range <- c(x_range[1] - x_pad, x_range[2] + x_pad)
  tile_y_range <- c(y_range[1] - y_pad, y_range[2] + y_pad)
  
  # Apply ratio adjustment in ROTATED CRS where it makes sense
  if (!is.null(ratio)) {
    tile_width <- tile_x_range[2] - tile_x_range[1]
    tile_height <- tile_y_range[2] - tile_y_range[1]
    tile_current_ratio <- tile_width / tile_height
    
    tile_centroid_x <- mean(tile_x_range)
    tile_centroid_y <- mean(tile_y_range)
    
    if (tile_current_ratio < ratio) {
      # Need to increase width
      new_width <- tile_height * ratio
      tile_x_range <- c(tile_centroid_x - new_width / 2, tile_centroid_x + new_width / 2)
    } else {
      # Need to increase height
      new_height <- tile_width / ratio
      tile_y_range <- c(tile_centroid_y - new_height / 2, tile_centroid_y + new_height / 2)
    }
  }
  
  # Create the tile bbox polygon in ROTATED CRS (meters)
  tile_bbox_rotated <- sf::st_sfc(sf::st_polygon(list(rbind(
    c(tile_x_range[1], tile_y_range[1]),
    c(tile_x_range[2], tile_y_range[1]),
    c(tile_x_range[2], tile_y_range[2]),
    c(tile_x_range[1], tile_y_range[2]),
    c(tile_x_range[1], tile_y_range[1])
  ))))
  sf::st_crs(tile_bbox_rotated) <- crs_string
  
  # Transform to WGS84 for add_basemap
  tile_bbox_wgs84 <- sf::st_bbox(sf::st_transform(tile_bbox_rotated, 4326))
  
  list(
    coord = ggplot2::coord_sf(xlim = tile_x_range, 
                              ylim = tile_y_range, 
                              crs = crs_string, expand = FALSE),
    bbox = tile_bbox_wgs84,
    crs = crs_string,
    angle = angle,
    ratio = ratio
  )
}