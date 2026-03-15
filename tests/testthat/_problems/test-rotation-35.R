# Extracted from test-rotation.R:35

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "ggbasemap", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("sf")
df <- data.frame(lon = c(-79.5, -79.3), lat = c(35.4, 35.6))
sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
angles <- c(0, 30, 45, 90, 135, 180, -45, -90)
for (angle in angles) {
    result <- coord_rotate(sf_obj, angle)
    expect_equal(result$angle, angle)
    expect_type(result$crs, "character")
    expect_true(grepl("omerc", result$crs))
    expect_true(grepl(paste0("gamma=", angle), result$crs))
  }
