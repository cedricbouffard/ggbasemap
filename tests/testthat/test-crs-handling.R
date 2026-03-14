test_that("add_basemap handles non-WGS84 CRS correctly", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  # Create test data in UTM (projected CRS)
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  nc_utm <- sf::st_transform(nc, 32617)  # UTM zone 17N
  
  # This should work (auto-converts to WGS84 with message)
  expect_message(
    tryCatch({
      result <- add_basemap(nc_utm)
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)  # Expected without internet
      }
      # Check if it's a NaN error
      if (grepl("NaN|must be a finite number", conditionMessage(e))) {
        stop(paste("NaN error:", conditionMessage(e)))
      }
      stop(e)
    }),
    "Converting data"
  )
})

test_that("add_basemap handles Web Mercator (3857) correctly", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  
  # Create test data in Web Mercator
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  nc_3857 <- sf::st_transform(nc, 3857)  # Web Mercator
  
  # This should work (auto-converts to WGS84 with message)
  expect_message(
    tryCatch({
      result <- add_basemap(nc_3857, url = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}")
      TRUE
    }, error = function(e) {
      if (grepl("Could not fetch any tiles", conditionMessage(e))) {
        return(TRUE)  # Expected without internet
      }
      if (grepl("NaN|must be a finite number|not a finite", conditionMessage(e))) {
        stop(paste("NaN/Infinity error:", conditionMessage(e)))
      }
      stop(e)
    }),
    "Converting data"
  )
})

test_that("extract_bbox_from_sf converts projected CRS correctly", {
  skip_if_not_installed("sf")
  
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  
  # Test UTM conversion
  nc_utm <- sf::st_transform(nc, 32617)
  bbox_utm <- extract_bbox_from_sf(nc_utm, padding = 0)
  
  # Check that bbox is now in degrees (WGS84)
  expect_true(all(abs(bbox_utm) <= 180))
  expect_true(bbox_utm["xmin"] < bbox_utm["xmax"])
  expect_true(bbox_utm["ymin"] < bbox_utm["ymax"])
  
  # Test Web Mercator conversion
  nc_3857 <- sf::st_transform(nc, 3857)
  bbox_3857 <- extract_bbox_from_sf(nc_3857, padding = 0)
  
  # Check that bbox is now in degrees
  expect_true(all(abs(bbox_3857) <= 180))
})

test_that("latlon_to_tile handles valid coordinates", {
  # Valid coordinates
  result <- latlon_to_tile(-80, 35, 10)
  expect_true(is.finite(result$x))
  expect_true(is.finite(result$y))
  expect_true(result$x >= 0)
  expect_true(result$y >= 0)
})

test_that("latlon_to_tile fails gracefully with invalid coordinates", {
  # Invalid coordinates (meters instead of degrees)
  expect_warning(
    result <- latlon_to_tile(1000000, 2000000, 10),
    "NaN"
  )
})
