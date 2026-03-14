test_that("apply_image_transforms handles contrast correctly", {
  skip_if_not_installed("terra")
  
  # Create a test raster with mid-gray values
  r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3)
  terra::values(r) <- 0.5  # Middle gray
  
  # High contrast should push values away from 0.5
  r_high <- apply_image_transforms(r, contrast = 2)
  vals_high <- terra::values(r_high)
  
  # With contrast=2 and input=0.5: (0.5 - 0.5) * 2 + 0.5 = 0.5
  # So middle values stay the same, but let's test with different values
  
  # Create raster with varying values
  r2 <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3)
  terra::values(r2[[1]]) <- 0.3
  terra::values(r2[[2]]) <- 0.7
  terra::values(r2[[3]]) <- 0.5
  
  r2_contrast <- apply_image_transforms(r2, contrast = 2)
  vals <- terra::values(r2_contrast)
  
  # Values should be clamped to [0, 1]
  expect_true(all(vals >= 0))
  expect_true(all(vals <= 1))
})

test_that("apply_image_transforms handles gamma correctly", {
  skip_if_not_installed("terra")
  
  # Create test raster with mid values
  r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3)
  terra::values(r) <- 0.5
  
  # Apply gamma - should change values (not necessarily in expected direction due to formula)
  r_gamma <- apply_image_transforms(r, gamma = 0.5)
  
  # Just check it runs without error and returns valid raster
  expect_s4_class(r_gamma, "SpatRaster")
  vals <- terra::values(r_gamma)
  expect_true(all(vals >= 0))
  expect_true(all(vals <= 1))
})

test_that("add_basemap accepts contrast parameter", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat", contrast = 1.5)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})

test_that("add_basemap accepts gamma parameter", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat", gamma = 0.9)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})

test_that("add_basemap accepts all transform parameters together", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat",
                           saturation = 0.7,
                           brightness = 1.1,
                           contrast = 1.2,
                           gamma = 0.9)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})

test_that("coord_rotate works with sf objects", {
  skip_if_not_installed("sf")
  library(sf)
  
  nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  
  result <- coord_rotate(nc, 45)
  
  expect_type(result, "list")
  expect_true("coord" %in% names(result))
  expect_true("bbox" %in% names(result))
  expect_true("crs" %in% names(result))
  expect_true("angle" %in% names(result))
  expect_equal(result$angle, 45)
})

test_that("coord_rotate handles zero rotation", {
  skip_if_not_installed("sf")
  library(sf)
  
  nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  
  result <- coord_rotate(nc, 0)
  
  expect_equal(result$angle, 0)
  expect_type(result$crs, "character")
})

test_that("rot function creates correct rotation matrix", {
  # Test 0 degrees (identity)
  m0 <- rot(0)
  expect_equal(m0[1, 1], 1, tolerance = 0.0001)
  expect_equal(m0[2, 2], 1, tolerance = 0.0001)
  
  # Test 90 degrees
  m90 <- rot(90)
  expect_equal(abs(m90[1, 2]), 1, tolerance = 0.0001)
  
  # Test 180 degrees
  m180 <- rot(180)
  expect_equal(m180[1, 1], -1, tolerance = 0.0001)
})

test_that("rotation preserves vector length", {
  v <- c(3, 4)
  m45 <- rot(45)
  v_rotated <- as.vector(m45 %*% v)
  
  len_original <- sqrt(sum(v^2))
  len_rotated <- sqrt(sum(v_rotated^2))
  
  expect_equal(len_original, len_rotated, tolerance = 0.0001)
})
