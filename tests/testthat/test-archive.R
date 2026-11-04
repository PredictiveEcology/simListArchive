rowsAB <- function() rbind(toyRow("A", 1, 0, 1e5), toyRow("A", 2, 0, 1e5), toyRow("B", 1, 1e5, 2e5), toyRow("B", 2, 1e5, 2e5))

test_that("the user does not need to know the ELF: the study area finds it", {
  led <- toyLedger(rowsAB())
  expect_identical(archiveSelectRuns(led, toyPoly(1e4, 9e4, 1e4, 9e4), list(rep = 2))$ELF, "A")
})

test_that("a 5 km spill into the neighbour does not bring the neighbour", {
  led <- toyLedger(rowsAB())
  expect_identical(archiveSelectRuns(led, toyPoly(1e4, 104000, 1e4, 9e4), list(rep = 1))$ELF, "A")
})

test_that("a study area spanning two ELFs gets one run from each", {
  led <- toyLedger(rowsAB())
  expect_setequal(archiveSelectRuns(led, toyPoly(5e4, 15e4, 1e4, 9e4), list(rep = 1))$runName,
                  c("A_NRV_370_1", "B_NRV_370_1"))
})

test_that("no run is ever picked silently: the error lists what exists", {
  led <- toyLedger(rowsAB())
  inA <- toyPoly(1e4, 9e4, 1e4, 9e4)
  expect_error(archiveSelectRuns(led, inA), "one run for each polygon.*rep")       # 2 reps, no scenario
  expect_error(archiveSelectRuns(led, inA, list(rep = 9)), "one run for each polygon")
  expect_error(archiveSelectRuns(led, inA, list(period = 1)), "does not have: period")
})

test_that("a scenario present in only one of two ELFs is an error, not half a study area", {
  led <- toyLedger(rbind(toyRow("A", 1, 0, 1e5), toyRow("B", 2, 1e5, 2e5)))
  expect_error(archiveSelectRuns(led, toyPoly(5e4, 15e4, 1e4, 9e4), list(rep = 1)), "one run for each polygon")
})

test_that("an area the archive does not fully cover stops and says so", {
  led <- toyLedger(rowsAB())
  expect_error(archiveSelectRuns(led, toyPoly(15e4, 35e4, 1e4, 9e4)), "only part")
  expect_error(archiveSelectRuns(led, toyPoly(5e5, 6e5)), "No run overlaps")
})

test_that("saved files are told by name, and only the requested objects", {
  tab <- .archiveFileTable(c("/x/cohortData_year2720.qs2", "/x/pixelGroupMap_year2720.tif", "/x/vegTypeMap_year2720.tif",
                             "/x/cohortDataFactorial_abc.df", "/x/vegAttr_Biomass_year_2720.png"),
                           c("cohortData", "pixelGroupMap"), run = 1L)
  expect_setequal(tab$object, c("cohortData", "pixelGroupMap"))
  expect_true(all(tab$year == 2720))
})

test_that("two ELFs join with unique pixelGroups and each keeps its own cohorts", {
  d <- withr::local_tempdir()
  fa <- toyFiles(file.path(d, "a"), 0, 1e5, 2720, base = 10L)
  fb <- toyFiles(file.path(d, "b"), 1e5, 2e5, 2720, base = 100L)
  files <- rbind(.archiveFileTable(fa, c("cohortData", "pixelGroupMap"), 1L),
                 .archiveFileTable(fb, c("cohortData", "pixelGroupMap"), 2L))
  runs <- rbind(toyRow("A", 1, 0, 1e5), toyRow("B", 1, 1e5, 2e5))
  out <- archiveLoadYear(files, runs, toyPoly(0, 2e5), 2720)
  ids <- sort(unique(terra::values(out$pixelGroupMap, mat = FALSE)))
  expect_identical(as.numeric(ids), c(1, 2, 3, 4))
  expect_setequal(out$cohortData$pixelGroup, ids)
  expect_identical(out$cohortData$B[out$cohortData$pixelGroup == 1], 10L)
  expect_identical(out$cohortData$B[out$cohortData$pixelGroup == 3], 100L)
  expect_false(999L %in% out$cohortData$B)      # a group on no pixel in the area is dropped
})

test_that("group 0 (no cohorts) is not moved onto another run's group", {
  d <- withr::local_tempdir()
  saved <- list(toyFiles(file.path(d, "a"), 0, 1e5, 2720), toyFiles(file.path(d, "b"), 1e5, 2e5, 2720))
  r <- terra::rast(saved[[2]][1]) - 1L             # run B's groups are 0 and 1
  f <- file.path(d, "b", "b0.tif")
  terra::writeRaster(r, f, datatype = "INT4S")
  file.rename(f, saved[[2]][1])
  files <- rbind(.archiveFileTable(saved[[1]], c("cohortData", "pixelGroupMap"), 1L),
                 .archiveFileTable(saved[[2]], c("cohortData", "pixelGroupMap"), 2L))
  out <- archiveLoadYear(files, rbind(toyRow("A", 1, 0, 1e5), toyRow("B", 1, 1e5, 2e5)), toyPoly(0, 2e5), 2720)
  expect_setequal(terra::values(out$pixelGroupMap, mat = FALSE), c(0, 1, 2, 3))
  expect_identical(sum(terra::values(out$pixelGroupMap, mat = FALSE) == 2), 50L)   # only run A's own group 2
})

test_that("objects are cropped to the study area and cohorts follow", {
  d <- withr::local_tempdir()
  fa <- toyFiles(d, 0, 1e5, 2720)
  files <- .archiveFileTable(fa, c("cohortData", "pixelGroupMap"), 1L)
  out <- archiveLoadYear(files, toyRow("A", 1, 0, 1e5), toyPoly(0, 1e4, 0, 1e4), 2720)
  expect_identical(terra::ncell(out$pixelGroupMap), 1)
  expect_identical(NROW(out$cohortData), 1L)
})

test_that("each year gets its own save, not a later one", {
  d <- withr::local_tempdir()
  saved <- c(toyFiles(d, 0, 1e5, 2720, base = 1L), toyFiles(d, 0, 1e5, 2820, base = 5L))
  files <- .archiveFileTable(saved, c("cohortData", "pixelGroupMap"), 1L)
  expect_identical(max(archiveLoadYear(files, toyRow("A", 1, 0, 1e5), toyPoly(0, 1e5), 2720)$cohortData$B), 2L)
  expect_identical(max(archiveLoadYear(files, toyRow("A", 1, 0, 1e5), toyPoly(0, 1e5), 2820)$cohortData$B), 10L)
})

test_that("a year between saves uses the latest save, with a warning", {
  d <- withr::local_tempdir()
  files <- .archiveFileTable(toyFiles(d, 0, 1e5, 2720), c("cohortData", "pixelGroupMap"), 1L)
  expect_warning(out <- archiveLoadYear(files, toyRow("A", 1, 0, 1e5), toyPoly(0, 1e5), 2750), "using year 2720")
  expect_named(out, c("pixelGroupMap", "cohortData"), ignore.order = TRUE)
})

test_that("archiveTimes keeps saved years every run has, within times", {
  files <- data.table::data.table(run = c(1, 1, 1, 2, 2), year = c(2620, 2720, 2820, 2720, 2820))
  expect_identical(archiveTimes(files, 2700, 2800), 2720)
  ## two objects saved in one year are one year
  expect_identical(archiveTimes(data.table::data.table(run = 1, year = c(2720, 2720)), 2700, 2800), 2720)
})

test_that("a start before the first save stops", {
  testthat::local_mocked_bindings(reIndex = function(gFile, destDir) {
    stopifnot(dir.exists(destDir))  # googledrive cannot write into a missing folder
    data.frame(name = "o/cohortData_year2720.qs2")
  }, .package = "SpaDES.project")
  expect_error(archiveFetch(toyRow("A", 1, 0, 1e5), "cohortData", 2500, 3000, file.path(withr::local_tempdir(), "new")),
               "no cohortData saved at or before")
})

test_that("each object starts from its own latest save, as objects are saved at different years", {
  ## as in the NRV runs: vegTypeMap more often than cohortData
  saved <- c(paste0("o/cohortData_year", c(2620, 2720, 2820), ".qs2"),
             paste0("o/vegTypeMap_year", c(2700, 2740, 2760, 2780), ".tif"))
  asked <- NULL
  testthat::local_mocked_bindings(
    reIndex = function(...) data.frame(name = saved),
    reGetUntarLoad = function(gFiles, ..., outputsPattern) {
      asked <<- outputsPattern
      sim <- SpaDES.core::simInit()
      sim$climateYearRecord <- data.table::data.table(simYear = 2720, climateYear = 2020)
      sim@outputs <- data.frame(file = file.path("/x", grep(outputsPattern, basename(saved), value = TRUE)),
                                saved = TRUE)
      list(sim)
    }, .package = "SpaDES.project")
  files <- archiveFetch(toyRow("A", 1, 0, 1e5), c("cohortData", "vegTypeMap"), 2750, 2800, tempdir())
  got <- basename(files$file)
  expect_setequal(got, c("cohortData_year2720.qs2", "vegTypeMap_year2740.tif", "vegTypeMap_year2760.tif",
                         "vegTypeMap_year2780.tif"))
})

## Two runs whose saved simLists hold a climateYearRecord, mocked as the lazy sim hands it out
mockRecords <- function(records) {
  testthat::local_mocked_bindings(
    reIndex = function(...) data.frame(name = "o/cohortData_year2720.qs2"),
    reGetUntarLoad = function(gFiles, ...) {
      sim <- SpaDES.core::simInit()
      sim$climateYearRecord <- records[[sub("^id", "", gFiles)]]
      sim@outputs <- data.frame(file = "/x/cohortData_year2720.qs2", saved = TRUE)
      list(sim)
    }, .package = "SpaDES.project", .env = parent.frame())
}
recFor <- function(climateYear) data.table::data.table(simYear = c(2720, 2721, 2722, 2900), climateYear = climateYear)

test_that("the climate year of each simulation year is supplied for each run, within start to end", {
  mockRecords(list(A_NRV_370_1 = recFor(c(2001, 2002, 2003, 2004)), B_NRV_370_1 = recFor(c(2001, 2002, 2003, 2004))))
  expect_no_warning(files <- archiveFetch(rbind(toyRow("A", 1, 0, 1e5), toyRow("B", 1, 1e5, 2e5)),
                                          "cohortData", 2720, 2800, tempdir()))
  rec <- attr(files, "climateYearRecord")
  expect_named(rec, c("runName", "ELF", "simYear", "climateYear"))
  expect_identical(NROW(rec), 6L)                                   # 3 years in 2720..2800, 2 runs
  expect_identical(rec$climateYear[rec$runName == "A_NRV_370_1"], c(2001, 2002, 2003))
})

test_that("runs that used different climate years for a simulation year give one warning naming them", {
  mockRecords(list(A_NRV_370_1 = recFor(c(2001, 2002, 2003, 2004)), B_NRV_370_1 = recFor(c(2001, 2012, 2013, 2004))))
  expect_warning(archiveFetch(rbind(toyRow("A", 1, 0, 1e5), toyRow("B", 1, 1e5, 2e5)), "cohortData", 2720, 2800, tempdir()),
                 "A_NRV_370_1, B_NRV_370_1 used different climate years in 2 of .*2721, 2722\\)")
})

test_that("a difference outside start to end is not a warning", {
  mockRecords(list(A_NRV_370_1 = recFor(c(2001, 2002, 2003, 2004)), B_NRV_370_1 = recFor(c(2001, 2002, 2003, 9999))))
  expect_no_warning(archiveFetch(rbind(toyRow("A", 1, 0, 1e5), toyRow("B", 1, 1e5, 2e5)), "cohortData", 2720, 2800, tempdir()))
})
