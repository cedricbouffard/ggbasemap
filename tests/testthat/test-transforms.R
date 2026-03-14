test_that("apply_image_transforms exists", {
  expect_type(apply_image_transforms, "closure")
})

test_that("grayscale transformation works", {
  skip_if_not_installed("terra")
  
  # Create a simple RGB raster
  set.seed(123)
  r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3)
  terra::values(r) <- runif(300)
  
  # Apply grayscale
  r_gray <- apply_image_transforms(r, grayscale = TRUE)
  
  # Check it's still a raster
  expect_s4_class(r_gray, "SpatRaster")
  expect_equal(terra::nlyr(r_gray), 3)
  
  # Check that all bands are equal (grayscale)
  vals <- terra::values(r_gray)
  expect_equal(vals[, 1], vals[, 2], tolerance = 0.0001)
  expect_equal(vals[, 2], vals[, 3], tolerance = 0.0001)
})

test_that("brightness transformation works", {
  skip_if_not_installed("terra")
  
  # Create a simple RGB raster
  r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3)
  terra::values(r) <- 0.5  # Mid gray
  
  # Make brighter
  r_bright <- apply_image_transforms(r, brightness = 1.5)
  vals_bright <- terra::values(r_bright)
  
  # Values should be higher (but clamped at 1)
  expect_true(all(vals_bright >= 0.5))
  expect_true(all(vals_bright <= 1))
  
  # Make darker
  r_dark <- apply_image_transforms(r, brightness = 0.5)
  vals_dark <- terra::values(r_dark)
  
  # Values should be lower
  expect_true(all(vals_dark <= 0.5))
  expect_true(all(vals_dark >= 0))
})

test_that("saturation transformation works", {
  skip_if_not_installed("terra")
  
  # Create a simple RGB raster with different values per band
  r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3)
  terra::values(r[[1]]) <- 0.9  # Red
  terra::values(r[[2]]) <- 0.1  # Green
  terra::values(r[[3]]) <- 0.1  # Blue
  
  # Desaturate
  r_desat <- apply_image_transforms(r, saturation = 0)
  vals <- terra::values(r_desat)
  
  # All bands should be equal (grayscale)
  expect_equal(vals[, 1], vals[, 2], tolerance = 0.0001)
  expect_equal(vals[, 2], vals[, 3], tolerance = 0.0001)
  
  # Half saturation
  r_half <- apply_image_transforms(r, saturation = 0.5)
  vals_half <- terra::values(r_half)
  
  # Should be between original and grayscale
  expect_true(all(vals_half >= 0))
  expect_true(all(vals_half <= 1))
})

test_that("combined transformations work", {
  skip_if_not_installed("terra")
  
  r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 3)
  terra::values(r) <- runif(300, 0.2, 0.8)
  
  # Apply all transformations
  r_transformed <- apply_image_transforms(r, 
                                          grayscale = FALSE, 
                                          saturation = 0.5, 
                                          brightness = 1.2)
  
  expect_s4_class(r_transformed, "SpatRaster")
  
  # Values should be clamped to [0, 1]
  vals <- terra::values(r_transformed)
  expect_true(all(vals >= 0))
  expect_true(all(vals <= 1))
})

test_that("add_basemap accepts image transform parameters", {
  df <- data.frame(lon = c(-74, -73.9), lat = c(40.7, 40.8))
  
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat", grayscale = TRUE)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
  
  expect_silent(
    tryCatch({
      result <- add_basemap(df, "lon", "lat", saturation = 0.5, brightness = 1.2)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)
      }
      stop(e)
    })
  )
})
