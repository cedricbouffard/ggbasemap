# Extracted from test-rotation.R:66

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "ggbasemap", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("sf")
nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
result <- coord_rotate(nc, 30)
