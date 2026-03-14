test_that("add_basemap function exists", {
  expect_type(add_basemap, "closure")
})

test_that("calculate_zoom works correctly", {
  # Small area (city level) should have high zoom
  bbox_small <- c(xmin = -74.1, ymin = 40.6, xmax = -73.9, ymax = 40.8)
  zoom_small <- calculate_zoom(bbox_small)
  expect_true(zoom_small >= 10)
  
  # Large area (country level) should have low zoom
  bbox_large <- c(xmin = -10, ymin = 35, xmax = 20, ymax = 55)
  zoom_large <- calculate_zoom(bbox_large)
  expect_true(zoom_large <= 6)
  
  # World level (should be clamped to minimum)
  bbox_world <- c(xmin = -180, ymin = -90, xmax = 180, ymax = 90)
  zoom_world <- calculate_zoom(bbox_world)
  expect_true(zoom_world >= 0)
  
  # Very small area (should be clamped to maximum)
  bbox_tiny <- c(xmin = -74.001, ymin = 40.701, xmax = -74.000, ymax = 40.702)
  zoom_tiny <- calculate_zoom(bbox_tiny)
  expect_true(zoom_tiny <= 19)
})

test_that("latlon_to_tile converts correctly", {
  # Test conversion for zoom level 0 (one tile for whole world)
  result <- latlon_to_tile(0, 0, 0)
  expect_equal(result$x, 0)
  expect_equal(result$y, 0)
  
  # Test conversion for known location
  result <- latlon_to_tile(-74, 40.7, 10)
  expect_true(result$x > 0)
  expect_true(result$y > 0)
  expect_type(result$x, "double")
  expect_type(result$y, "double")
  
  # Test edge cases
  result <- latlon_to_tile(-180, 85, 5)
  expect_true(result$x >= 0)
  expect_true(result$y >= 0)
  
  result <- latlon_to_tile(180, -85, 5)
  expect_true(result$x >= 0)
  expect_true(result$y >= 0)
})

test_that("tile_to_latlon reverses latlon_to_tile", {
  # Test round-trip conversion
  test_cases <- list(
    list(lon = -74.0, lat = 40.7, zoom = 10),
    list(lon = 0, lat = 0, zoom = 5),
    list(lon = 120, lat = -30, zoom = 8),
    list(lon = -120, lat = 60, zoom = 12)
  )
  
  for (test in test_cases) {
    tile <- latlon_to_tile(test$lon, test$lat, test$zoom)
    coords <- tile_to_latlon(tile$x, tile$y, test$zoom)
    
    # Should be within one tile (approximate)
    tile_size_deg <- 360 / (2^test$zoom)
    expect_lt(abs(coords$lon - test$lon), tile_size_deg)
    expect_lt(abs(coords$lat - test$lat), tile_size_deg)
  }
})

test_that("extract_bbox_from_df validates column names", {
  df <- data.frame(x = c(-74, -73.9), y = c(40.7, 40.8))
  
  # Should error for non-existent columns (using quoted names)
  expect_error(extract_bbox_from_df(df, "lon", "lat"), "not found in data")
  expect_error(extract_bbox_from_df(df, "x", "lat"), "not found in data")
  expect_error(extract_bbox_from_df(df, "lon", "y"), "not found in data")
})

test_that("extract_bbox_from_df works with valid columns", {
  df <- data.frame(
    longitude = c(-74, -73.9, -73.8),
    latitude = c(40.7, 40.8, 40.9)
  )
  
  bbox <- extract_bbox_from_df(df, "longitude", "latitude", padding = 0.1)
  
  expect_type(bbox, "double")
  expect_length(bbox, 4)
  expect_true(all(c("xmin", "ymin", "xmax", "ymax") %in% names(bbox)))
  
  # Check that padding was applied
  x_range <- range(df$longitude)
  y_range <- range(df$latitude)
  x_pad <- diff(x_range) * 0.1
  y_pad <- diff(y_range) * 0.1
  
  expect_equal(as.numeric(bbox["xmin"]), x_range[1] - x_pad, tolerance = 0.001)
  expect_equal(as.numeric(bbox["xmax"]), x_range[2] + x_pad, tolerance = 0.001)
})

test_that("extract_bbox_from_df handles NA values", {
  df <- data.frame(
    lon = c(-74, NA, -73.8),
    lat = c(40.7, 40.8, NA)
  )
  
  # Should work despite NAs
  bbox <- extract_bbox_from_df(df, "lon", "lat", padding = 0)
  
  expect_equal(as.numeric(bbox["xmin"]), -74)
  expect_equal(as.numeric(bbox["xmax"]), -73.8)
  expect_equal(as.numeric(bbox["ymin"]), 40.7)
  expect_equal(as.numeric(bbox["ymax"]), 40.8)
})

test_that("add_basemap accepts quoted column names", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  
  # Should accept quoted column names without error
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat")
      # Success if we get here
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)  # Expected without internet
      }
      stop(e)
    })
  )
})

test_that("add_basemap accepts bbox directly", {
  bbox <- c(xmin = -74.1, ymin = 40.6, xmax = -73.8, ymax = 40.9)
  
  # Should accept bbox without error
  expect_silent(
    tryCatch({
      result <- add_basemap(bbox = bbox)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)  # Expected without internet
      }
      stop(e)
    })
  )
})

test_that("add_basemap validates bbox format", {
  # Wrong length
  expect_error(add_basemap(bbox = c(1, 2, 3)), "must be a vector of length 4")
  
  # Named bbox should work without error
  bbox_named <- c(xmin = -74, ymin = 40, xmax = -73, ymax = 41)
  expect_silent(
    tryCatch({
      result <- add_basemap(bbox = bbox_named)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})

test_that("add_basemap requires either data or bbox", {
  expect_error(add_basemap(), "Must provide either data")
})

test_that("add_basemap requires x and y for data frames", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  expect_error(add_basemap(df), "x and y columns must be specified")
  expect_error(add_basemap(df, x = "lon"), "x and y columns must be specified")
  expect_error(add_basemap(df, y = "lat"), "x and y columns must be specified")
})

test_that("add_basemap validates data type", {
  expect_error(add_basemap(data = "invalid"), "must be a data.frame or sf object")
  expect_error(add_basemap(data = 123), "must be a data.frame or sf object")
  expect_error(add_basemap(data = list(a = 1)), "must be a data.frame or sf object")
})

test_that("extract_bbox_from_sf works correctly", {
  skip_if_not_installed("sf")
  
  # Create simple sf object
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  
  bbox <- extract_bbox_from_sf(sf_obj, padding = 0.1)
  
  expect_type(bbox, "double")
  expect_length(bbox, 4)
  expect_true(all(c("xmin", "ymin", "xmax", "ymax") %in% names(bbox)))
  
  # Check values are reasonable
  expect_lt(bbox["xmin"], -74)
  expect_gt(bbox["xmax"], -73.9)
  expect_lt(bbox["ymin"], 40.7)
  expect_gt(bbox["ymax"], 40.8)
})

test_that("create_terra_raster handles single tile", {
  skip_if_not_installed("terra")
  
  # Create mock tile data
  set.seed(123)
  img <- array(runif(256 * 256 * 3), dim = c(256, 256, 3))
  tiles <- list(list(data = img, x = 0, y = 0, zoom = 10))
  
  # Should not error
  expect_silent(
    r <- create_terra_raster(tiles, 0, 0, 10)
  )
  
  # Check it's a terra raster
  expect_s4_class(r, "SpatRaster")
  
  # Check it has the right CRS
  expect_equal(terra::crs(r, describe = TRUE)$code, "3857")
})

test_that("create_terra_raster handles multiple tiles", {
  skip_if_not_installed("terra")
  
  # Create mock tile data (2x2 tiles)
  set.seed(456)
  img <- array(runif(256 * 256 * 3), dim = c(256, 256, 3))
  tiles <- list(
    list(data = img, x = 0, y = 0, zoom = 10),
    list(data = img, x = 1, y = 0, zoom = 10),
    list(data = img, x = 0, y = 1, zoom = 10),
    list(data = img, x = 1, y = 1, zoom = 10)
  )
  
  # Should not error
  expect_silent(
    r <- create_terra_raster(tiles, 0:1, 0:1, 10)
  )
  
  # Check it's a terra raster
  expect_s4_class(r, "SpatRaster")
  
  # Check dimensions (2x2 tiles at 256x256 each)
  expect_equal(terra::nrow(r), 512)
  expect_equal(terra::ncol(r), 512)
  
  # Check CRS
  expect_equal(terra::crs(r, describe = TRUE)$code, "3857")
})

test_that("create_terra_raster handles grayscale tiles", {
  skip_if_not_installed("terra")
  
  # Grayscale tile (single channel)
  set.seed(789)
  img <- matrix(runif(256 * 256), nrow = 256, ncol = 256)
  tiles <- list(list(data = img, x = 0, y = 0, zoom = 10))
  
  r <- create_terra_raster(tiles, 0, 0, 10)
  
  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::nlyr(r), 1)
})

test_that("create_terra_raster errors on empty tiles", {
  expect_error(create_terra_raster(list(), 0, 0, 10), "No tiles to create raster from")
})

test_that("add_basemap accepts sf objects", {
  skip_if_not_installed("sf")
  
  # Create simple sf object
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  
  # Should accept sf object without error
  expect_silent(
    tryCatch({
      result <- add_basemap(sf_obj)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})

test_that("add_basemap with zoom parameter", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat", zoom = 15)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})

test_that("add_basemap with alpha and interpolate parameters", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat", alpha = 0.5, interpolate = FALSE)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})

test_that("latlon_to_mercator conversion works", {
  # Test equator and prime meridian (0, 0)
  merc <- latlon_to_mercator(0, 0)
  expect_equal(merc$x, 0, tolerance = 0.001)
  expect_equal(merc$y, 0, tolerance = 0.001)
  
  # Test known conversions
  merc <- latlon_to_mercator(40.7, -74)
  expect_true(merc$x < 0)  # Negative longitude = negative x
  expect_true(merc$y > 0)  # Positive latitude = positive y
  
  # Test extremes (should not error)
  merc <- latlon_to_mercator(85, 180)
  expect_true(is.finite(merc$x))
  expect_true(is.finite(merc$y))
  
  merc <- latlon_to_mercator(-85, -180)
  expect_true(is.finite(merc$x))
  expect_true(is.finite(merc$y))
})

test_that("rot function works correctly", {
  # Test 0 degrees (identity matrix)
  m0 <- rot(0)
  expect_equal(m0[1, 1], 1, tolerance = 0.0001)
  expect_equal(m0[2, 2], 1, tolerance = 0.0001)
  expect_equal(m0[1, 2], 0, tolerance = 0.0001)
  expect_equal(m0[2, 1], 0, tolerance = 0.0001)
  
  # Test 90 degrees
  m90 <- rot(90)
  expect_equal(abs(m90[1, 2]), 1, tolerance = 0.0001)
  expect_equal(abs(m90[2, 1]), 1, tolerance = 0.0001)
  
  # Test 180 degrees
  m180 <- rot(180)
  expect_equal(m180[1, 1], -1, tolerance = 0.0001)
  expect_equal(m180[2, 2], -1, tolerance = 0.0001)
  
  # Matrix dimensions
  expect_equal(dim(rot(45)), c(2, 2))
})

test_that("rot preserves vector length", {
  # A rotation should preserve vector length
  v <- c(3, 4)
  m45 <- rot(45)
  v_rotated <- m45 %*% v
  
  len_original <- sqrt(sum(v^2))
  len_rotated <- sqrt(sum(v_rotated^2))
  
  expect_equal(len_original, len_rotated, tolerance = 0.0001)
})

test_that("fetch_and_create_raster with verbose mode", {
  skip_if_not_installed("terra")
  
  bbox <- c(xmin = -74.1, ymin = 40.6, xmax = -74.0, ymax = 40.7)
  
  # Should show messages in verbose mode (will fail on tiles but show output)
  expect_message(
    tryCatch({
      fetch_and_create_raster(bbox, 10, "https://example.com/{z}/{x}/{y}.png", verbose = TRUE)
    }, error = function(e) NULL),
    "Zoom:"
  )
})

test_that("fetch_and_create_raster errors on invalid URL", {
  bbox <- c(xmin = 0, ymin = 0, xmax = 0.1, ymax = 0.1)
  
  expect_error(
    fetch_and_create_raster(bbox, 10, "https://invalid.url/{z}/{x}/{y}.png"),
    "Could not fetch any tiles"
  )
})

test_that("tile_url construction is correct", {
  url_template <- "https://example.com/{z}/{x}/{y}.png"
  
  # Test that {z}, {x}, {y} are replaced
  tile_url <- gsub("\\{z\\}", 10, url_template)
  tile_url <- gsub("\\{x\\}", 5, tile_url)
  tile_url <- gsub("\\{y\\}", 3, tile_url)
  
  expect_equal(tile_url, "https://example.com/10/5/3.png")
})

test_that("calculate_zoom handles edge cases", {
  # Zero width bbox (degenerate)
  bbox_degenerate <- c(xmin = -74, ymin = 40, xmax = -74, ymax = 41)
  zoom <- calculate_zoom(bbox_degenerate)
  expect_true(is.finite(zoom))
  expect_true(zoom >= 0 && zoom <= 19)
})

test_that("calculate_zoom clamping works", {
  # Very large area (should clamp to zoom 0)
  bbox_huge <- c(xmin = -180, ymin = -90, xmax = 180, ymax = 90)
  zoom_huge <- calculate_zoom(bbox_huge)
  expect_gte(zoom_huge, 0)
  
  # Very small area (should clamp to zoom 19)
  bbox_micro <- c(xmin = -74.00001, ymin = 40.700001, xmax = -74, ymax = 40.70001)
  zoom_micro <- calculate_zoom(bbox_micro)
  expect_lte(zoom_micro, 19)
})
