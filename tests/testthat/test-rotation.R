test_that("coord_rotate returns correct structure", {
  skip_if_not_installed("sf")
  
  df <- data.frame(lon = c(-79.5, -79.3), lat = c(35.4, 35.6))
  sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  
  result <- coord_rotate(sf_obj, 45)
  
  expect_type(result, "list")
  expect_true("coord" %in% names(result))
  expect_true("bbox" %in% names(result))
  expect_true("crs" %in% names(result))
  expect_true("angle" %in% names(result))
  
  # Check angle is preserved
  expect_equal(result$angle, 45)
  
  # Check bbox has correct structure
  expect_true(all(c("xmin", "ymin", "xmax", "ymax") %in% names(result$bbox)))
  
  # Check coord is a CoordSf object
  expect_s3_class(result$coord, "CoordSf")
})

test_that("coord_rotate with different angles", {
  skip_if_not_installed("sf")
  
  df <- data.frame(lon = c(-79.5, -79.3), lat = c(35.4, 35.6))
  sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  
  # Test various angles
  angles <- c(0, 30, 45, 90, 135, 180, -45, -90)
  
  for (angle in angles) {
    result <- coord_rotate(sf_obj, angle)
    expect_equal(result$angle, angle)
    expect_type(result$crs, "character")
    expect_true(grepl("omerc", result$crs))
    expect_true(grepl(paste0("gamma=", angle), result$crs))
  }
})

test_that("coord_rotate expanded bbox is larger than original", {
  skip_if_not_installed("sf")
  
  df <- data.frame(lon = c(-79.5, -79.3), lat = c(35.4, 35.6))
  sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  orig_bbox <- sf::st_bbox(sf_obj)
  
  result <- coord_rotate(sf_obj, 45)
  rotated_bbox <- result$bbox
  
  # Rotated bbox should cover more area
  expect_lte(rotated_bbox["xmin"], as.numeric(orig_bbox["xmin"]))
  expect_gte(rotated_bbox["xmax"], as.numeric(orig_bbox["xmax"]))
  expect_lte(rotated_bbox["ymin"], as.numeric(orig_bbox["ymin"]))
  expect_gte(rotated_bbox["ymax"], as.numeric(orig_bbox["ymax"]))
})

test_that("coord_rotate works with polygons", {
  skip_if_not_installed("sf")
  
  # Create a simple polygon
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  
  result <- coord_rotate(nc, 30)
  
  expect_type(result, "list")
  expect_equal(result$angle, 30)
  expect_type(result$bbox, "double")
})

test_that("rotation preserves relative positions", {
  # A rotation should preserve distances
  v1 <- c(1, 0)
  v2 <- c(0, 1)
  
  # Distance before rotation
  dist_before <- sqrt(sum((v2 - v1)^2))
  
  # Rotate both points
  m45 <- rot(45)
  v1_rot <- as.vector(m45 %*% v1)
  v2_rot <- as.vector(m45 %*% v2)
  
  # Distance after rotation
  dist_after <- sqrt(sum((v2_rot - v1_rot)^2))
  
  expect_equal(dist_before, dist_after, tolerance = 0.0001)
})

test_that("rotation composition", {
  # Rotating by 45 then 45 should equal rotating by 90
  m45 <- rot(45)
  m90 <- rot(90)
  m_composed <- m45 %*% m45
  
  expect_equal(m_composed, m90, tolerance = 0.0001)
})

test_that("rot handles negative angles", {
  # Negative rotation should be clockwise
  m_neg45 <- rot(-45)
  m_pos45 <- rot(45)
  
  v <- c(1, 0)
  v_neg <- as.vector(m_neg45 %*% v)
  v_pos <- as.vector(m_pos45 %*% v)
  
  # Y coordinates should be opposite
  expect_equal(v_neg[2], -v_pos[2], tolerance = 0.0001)
})

test_that("rot handles angles > 360", {
  # 360 + 45 should equal 45
  m405 <- rot(405)
  m45 <- rot(45)
  
  expect_equal(m405, m45, tolerance = 0.0001)
})

test_that("rot handles angles < 0", {
  # -315 should equal 45
  m_neg315 <- rot(-315)
  m45 <- rot(45)
  
  expect_equal(m_neg315, m45, tolerance = 0.0001)
})

test_that("coord_rotate bbox calculation is correct", {
  skip_if_not_installed("sf")
  
  # Create a rectangle
  df <- data.frame(
    lon = c(-80, -79, -79, -80),
    lat = c(35, 35, 36, 36)
  )
  sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  orig_bbox <- sf::st_bbox(sf_obj)
  
  # Rotate 45 degrees
  result <- coord_rotate(sf_obj, 45)
  
  # The expanded bbox should be larger than the original
  orig_width <- as.numeric(orig_bbox["xmax"]) - as.numeric(orig_bbox["xmin"])
  orig_height <- as.numeric(orig_bbox["ymax"]) - as.numeric(orig_bbox["ymin"])
  
  rotated_width <- as.numeric(result$bbox["xmax"]) - as.numeric(result$bbox["xmin"])
  rotated_height <- as.numeric(result$bbox["ymax"]) - as.numeric(result$bbox["ymin"])
  
  # Expanded bbox should be larger
  expect_gt(rotated_width, orig_width)
  expect_gt(rotated_height, orig_height)
})

test_that("coord_rotate works with different CRS inputs", {
  skip_if_not_installed("sf")
  
  # Test with data in different CRS
  df <- data.frame(lon = c(-79.5, -79.3), lat = c(35.4, 35.6))
  sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  
  # Transform to UTM
  sf_utm <- sf::st_transform(sf_obj, 32617)
  
  # Should still work
  result <- coord_rotate(sf_utm, 30)
  expect_type(result, "list")
  expect_true("bbox" %in% names(result))
})

test_that("Web Mercator conversion at boundaries", {
  # Test at extreme latitudes
  merc_85 <- latlon_to_mercator(85, 0)
  expect_true(is.finite(merc_85$y))
  
  merc_neg85 <- latlon_to_mercator(-85, 0)
  expect_true(is.finite(merc_neg85$y))
  
  # Test at date line
  merc_180 <- latlon_to_mercator(0, 180)
  expect_true(is.finite(merc_180$x))
  
  merc_neg180 <- latlon_to_mercator(0, -180)
  expect_true(is.finite(merc_neg180$x))
})

test_that("Web Mercator is reversible for longitude", {
  # For longitude, the conversion should be linear
  lons <- seq(-180, 180, by = 30)
  
  for (lon in lons) {
    merc <- latlon_to_mercator(0, lon)
    # x should be proportional to longitude
    expected_x <- lon * 20037508.34 / 180
    expect_equal(merc$x, expected_x, tolerance = 0.001)
  }
})
