## Everything in this file and any files in the R directory are sourced during `simInit()`.
## The functions in R/ do the work; this file only schedules them.
defineModule(sim, list(
  name = "simListArchive",
  description = paste("Supplies the saved outputs of an earlier, long simulation, so that other modules can run on them",
                      "without running that simulation. The runs are found by the study area in a CacheGeo ledger,",
                      "and only the files needed are downloaded."),
  keywords = c("archive", "CacheGeo", "simList", "outputs"),
  authors = c(person("Eliot", "McIntire", email = "eliot.mcintire@nrcan-rncan.gc.ca", role = c("aut", "cre"))),
  childModules = character(0),
  version = list(simListArchive = "0.0.0.9000"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list(),
  documentation = list("README.md"),
  reqdPkgs = list("data.table", "qs2", "sf", "terra",
                  "PredictiveEcology/reproducible@development (>= 3.2.1.9084)",
                  "PredictiveEcology/SpaDES.project@development"),
  parameters = bindrows(
    defineParameter("archiveFile", "character", "nrvRuns_phase5.rds", NA, NA,
                    "The ledger's file name. One file per campaign of runs."),
    defineParameter("archiveRemote", "character",
                    "https://drive.google.com/drive/folders/188ERmd1k6s6YMv3wHtnHQHD7pgLseBjf", NA, NA,
                    "The Google Drive or shared-disk folder that holds the ledger."),
    defineParameter("scenario", "list", list(), NA, NA,
                    paste("Which run, as a named list matched against the ledger's columns,",
                          "e.g. `list(GCM = 'NRV', SSP = 370, rep = 1)`. It must identify exactly one run",
                          "for each polygon of the study area; if not, the error lists what is available.")),
    defineParameter("objects", "character", c("cohortData", "pixelGroupMap"), NA, NA,
                    "The saved objects to supply. Each is a file `<object>_year<year>.<ext>` in the run's outputs.")
  ),
  inputObjects = bindrows(
    expectsInput("studyArea", "sf", "The area to supply outputs for. It may cover more than one polygon of the ledger.")
  ),
  outputObjects = bindrows(
    createsOutput("archiveTimes", "numeric", "The saved years within `times`; other modules can schedule on these."),
    createsOutput("cohortData", "data.table", "From the latest saved year; `pixelGroup` ids are unique across runs."),
    createsOutput("pixelGroupMap", "SpatRaster", "From the latest saved year, cropped to `studyArea`."),
    createsOutput("rstTimeSinceFire", "SpatRaster", "If in `objects`."),
    createsOutput("standAgeMap", "SpatRaster", "If in `objects`."),
    createsOutput("vegTypeMap", "SpatRaster", "If in `objects`.")
  )
))

doEvent.simListArchive <- function(sim, eventTime, eventType) {
  switch(eventType,
    init = {
      if (is.null(sim$studyArea)) stop("simListArchive needs `studyArea`, to find the runs")
      ledger <- reproducible::CacheGeoLedger(P(sim)$archiveFile, remote = P(sim)$archiveRemote,
                                             destinationPath = inputPath(sim), key = "runName")
      mod$runs <- archiveSelectRuns(ledger, sim$studyArea, P(sim)$scenario)
      mod$files <- archiveFetch(mod$runs, P(sim)$objects, start(sim), end(sim),
                                destDir = file.path(inputPath(sim), "simListArchive"))
      sim$archiveTimes <- archiveTimes(mod$files, start(sim), end(sim))
      sim <- archiveAssign(sim, archiveLoadYear(mod$files, mod$runs, sim$studyArea, start(sim)))
      for (y in sim$archiveTimes[sim$archiveTimes > start(sim)])
        sim <- scheduleEvent(sim, y, "simListArchive", "load", .first())
    },
    load = {
      sim <- archiveAssign(sim, archiveLoadYear(mod$files, mod$runs, sim$studyArea, time(sim)))
    },
    warning(paste("Undefined event type: '", current(sim)[1, "eventType", with = FALSE],
                  "' in module '", current(sim)[1, "moduleName", with = FALSE], "'", sep = ""))
  )
  return(invisible(sim))
}

archiveAssign <- function(sim, objs) {
  for (nam in names(objs)) sim[[nam]] <- objs[[nam]]
  sim
}
