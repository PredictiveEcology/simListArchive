## The module's functions, without a simInit
for (f in list.files(testthat::test_path("..", "..", "R"), full.names = TRUE)) source(f, local = FALSE)

## Two side-by-side 100 km ELFs, with reps; rows as SpaDES.project::outSaveTarUpload() writes them
toyPoly <- function(x0, x1, y0 = 0, y1 = 1e5)
  sf::st_sf(geometry = sf::st_sfc(sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0)))), crs = 3978))

toyRow <- function(elf, rep, x0, x1, saveTimes = c(2620, 2720, 2820)) {
  out <- toyPoly(x0, x1)
  out$runName <- paste0(elf, "_NRV_370_", rep)
  out$driveId <- paste0("id", out$runName)
  out$saveTimes <- I(list(saveTimes))
  out$uploaded <- Sys.time()
  out$outputPath <- file.path("/old/outputs", out$runName)
  out$ELF <- elf
  out$GCM <- "NRV"
  out$SSP <- 370
  out$rep <- rep
  out
}

toyLedger <- function(rows) {
  led <- reproducible::CacheGeoLedger("runs.rds", destinationPath = withr::local_tempdir(.local_envir = parent.frame()),
                                      key = "runName")
  reproducible::CacheGeoWrite(led, rows, verbose = 0)
  led
}

## One run's files for one year: 10 km pixels, pixelGroup = 1 to 2, in its own polygon
toyFiles <- function(dir, x0, x1, year, base = 1L) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  r <- terra::rast(xmin = x0, xmax = x1, ymin = 0, ymax = 1e5, res = 1e4, crs = "EPSG:3978")
  terra::values(r) <- rep(c(1L, 2L), length.out = terra::ncell(r))
  pgm <- file.path(dir, paste0("pixelGroupMap_year", year, ".tif"))
  terra::writeRaster(r, pgm, overwrite = TRUE, datatype = "INT4S")
  cd <- file.path(dir, paste0("cohortData_year", year, ".qs2"))
  qs2::qs_save(data.table::data.table(pixelGroup = c(1L, 2L, 3L), B = c(base, base * 2L, 999L)), cd)
  c(pgm, cd)
}
