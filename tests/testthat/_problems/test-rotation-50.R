# Extracted from test-rotation.R:50

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "ggbasemap", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("sf")
df <- data.frame(lon = c(-79.5, -79.3), lat = c(35.4, 35.6))
sf_obj <- sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
orig_bbox <- sf::st_bbox(sf_obj)
result <- coord_rotate(sf_obj, 45)
