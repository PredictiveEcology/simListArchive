## The visible result: a user's module, listed with this one and no simulator, sees the saved outputs
## at each saved year. Only the download is replaced.
test_that("a module runs on archived outputs from a later start, with no simulator", {
  d <- withr::local_tempdir()
  modulePath <- file.path(d, "modules")
  dir.create(file.path(modulePath, "toyBirds"), recursive = TRUE)
  file.symlink(normalizePath(testthat::test_path("..", "..")), file.path(modulePath, "simListArchive"))
  writeLines(c(
    "defineModule(sim, list(name = 'toyBirds', description = 'toy', keywords = 'toy', childModules = character(0),",
    "  authors = person('A', 'B'), version = list(toyBirds = '0.0.1'), timeframe = as.POSIXlt(c(NA, NA)),",
    "  timeunit = 'year', citation = list(), documentation = list(), reqdPkgs = list('data.table'),",
    "  parameters = bindrows(defineParameter('x', 'numeric', 1, NA, NA, 'unused')),",
    "  inputObjects = bindrows(expectsInput('cohortData', 'data.table', ''), expectsInput('archiveTimes', 'numeric', '')),",
    "  outputObjects = bindrows(createsOutput('seen', 'data.frame', ''))))",
    "doEvent.toyBirds <- function(sim, eventTime, eventType) {",
    "  if (eventType == 'init') sim <- scheduleEvent(sim, start(sim), 'toyBirds', 'predict')",
    "  if (eventType == 'predict') {",
    "    sim$seen <- rbind(sim$seen, data.frame(year = time(sim), B = max(sim$cohortData$B)))",
    "    nxt <- sim$archiveTimes[sim$archiveTimes > time(sim)]",
    "    if (length(nxt)) sim <- scheduleEvent(sim, nxt[1], 'toyBirds', 'predict')",
    "  }",
    "  invisible(sim)",
    "}"), file.path(modulePath, "toyBirds", "toyBirds.R"))

  ledgerDir <- file.path(d, "ledger")
  dir.create(ledgerDir)
  row <- toyRow("A", 1, 0, 1e5)
  saved <- unlist(lapply(c(2620, 2720, 2820), function(y) toyFiles(file.path(d, "run"), 0, 1e5, y, base = as.integer(y))))
  led <- reproducible::CacheGeoLedger("runs.rds", remote = ledgerDir, destinationPath = file.path(d, "inputs0"), key = "runName")
  reproducible::CacheGeoWrite(led, row, verbose = 0)

  archived <- SpaDES.core::simInit()
  ## as registerOutputs() leaves them: `outputs<-` knows no save method for .qs2
  archived@outputs <- data.frame(file = saved, fun = NA_character_, package = NA_character_, objectName = NA_character_,
                                 saveTime = rep(c(2620, 2720, 2820), each = 2), saved = TRUE, arguments = NA)
  archived$climateYearRecord <- data.table::data.table(simYear = 2620:2900, climateYear = 2020L)
  asked <- list()
  testthat::local_mocked_bindings(
    reIndex = function(...) data.frame(name = sub("^/", "", saved)),
    reGetUntarLoad = function(gFiles, ..., outputsPattern) {
      asked <<- list(id = gFiles, pattern = outputsPattern)
      list(archived)
    }, .package = "SpaDES.project")

  out <- SpaDES.core::simInitAndSpades(
    times = list(start = 2720, end = 2820),
    modules = list("simListArchive", "toyBirds"),
    paths = list(modulePath = modulePath, inputPath = file.path(d, "inputs"), outputPath = file.path(d, "outputs"),
                 cachePath = file.path(d, "cache"), scratchPath = file.path(d, "scratch")),
    objects = list(studyArea = toyPoly(1e4, 9e4, 1e4, 9e4)),
    params = list(simListArchive = list(archiveFile = "runs.rds", archiveRemote = ledgerDir,
                                        scenario = list(rep = 1))))

  expect_identical(asked$id, row$driveId)
  expect_true(grepl("2720", asked$pattern) && grepl("2820", asked$pattern) && !grepl("2620", asked$pattern))
  expect_identical(as.numeric(out$seen$year), c(2720, 2820))
  expect_identical(out$seen$B, c(2720L, 2820L) * 2L)
  expect_identical(out$climateYearRecord$simYear, 2720:2820)
  expect_identical(out$climateYearRecord$runName, rep("A_NRV_370_1", 101L))
  expect_false(any(c("Biomass_core", "canClimateData") %in% unlist(SpaDES.core::modules(out))))
})
