# simListArchive

**Retired (2026-11-06).** Use `SpaDES.project::setupProject(alreadyRun = )` instead (SpaDES.project >= 1.2.0.9032, SpaDES.core >= 3.2.1.9058). Give the same `modules` the archived run used plus your own; only your modules are fetched and run, and they get the run's saved objects. For now `alreadyRun` replays one run (one ELF); this module still installs if you need a study area that spans several ELFs.

```r
out <- SpaDES.project::setupProject(
  times = list(start = 2720, end = 2820),
  modules = c(<the run's modules>, "yourAccount/yourModule@development"),
  alreadyRun = list(ledger = "nrvRuns.rds",
                    remote = "https://drive.google.com/drive/folders/188ERmd1k6s6YMv3wHtnHQHD7pgLseBjf",
                    scenario = list(ELF = "6.6.2", GCM = "NRV", SSP = 370, rep = 1))
)
```

Run your module on the saved outputs of a long simulation, without running that simulation and without knowing which run to download. You give a study area; the module finds the runs in a ledger and downloads only the files needed.

List this module instead of `LandR_ClimateSensitiveSimulator`:

```r
out <- SpaDES.project::setupProject(
  times = list(start = 2720, end = 3020),
  modules = c("PredictiveEcology/simListArchive@development",
              "yourAccount/yourModule@development"),
  studyArea = myPolygon,
  params = list(simListArchive = list(scenario = list(GCM = "NRV", SSP = 370, rep = 1)))
)
```

`scenario` is matched against the ledger's columns. If it does not identify exactly one run for each polygon under your study area, the error lists what is available. Run once per `rep`.

At each saved year your module finds `sim$cohortData` and `sim$pixelGroupMap`, cropped to the study area. `sim$archiveTimes` holds those years, so schedule on them. On any other year, the objects stay at the latest saved year. A study area spanning several polygons gets each one's values in its own pixels, with `pixelGroup` ids made unique. Other saved objects can be added with the `objects` parameter.

`sim$climateYearRecord` says which climate year each simulation year used, for each run: columns `runName`, `ELF`, `simYear`, `climateYear`, for `start` to `end`. If the runs under your study area used different climate years for the same simulation year, you get one warning naming them.

Your module should list what it needs with `expectsInput()`, which also makes it run after this module. Downloading needs a Google login with access to the folder.

## Example: a study area across two ELFs

This box near Pembroke, ON, crosses the border between ELFs 6.6.1 and 6.6.2, so it gets rep 1 of each. It downloads only `cohortData` and `pixelGroupMap` for 2720 and 2820: about 500 MB, in under 2 minutes.

```r
studyArea <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
  c(xmin = -78.01, ymin = 45.80, xmax = -77.22, ymax = 46.35), crs = 4326)))

out <- SpaDES.project::setupProject(
  paths = list(projectPath = "~/simListArchiveDemo"),
  times = list(start = 2720, end = 2820),
  modules = "PredictiveEcology/simListArchive@development",
  studyArea = studyArea,
  params = list(simListArchive = list(scenario = list(GCM = "NRV", SSP = 370, rep = 1)))
)
sim <- SpaDES.core::simInitAndSpades2(out)

sim$archiveTimes                                                        # 2720 2820
sim$pixelGroupMap                                                       # both ELFs' pixels
table(sim$cohortData$pixelGroup %in% terra::values(sim$pixelGroupMap))  # all TRUE
```

If you set `options(spades.useRequire = FALSE)`, also give `packagePath` in `paths`: a library that already has SpaDES.core, terra and sf. Otherwise `setupProject` uses a new, empty project library. Warnings that the module code of `Biomass_core` and others cannot be found are expected: they come from the archived simList, which is only read, never run.

## Campaigns

The folder's `nrvRuns.rds` always lists the current runs. When a new campaign of runs is complete it replaces that file, and your local copy refreshes by itself: the ledger is fetched again whenever its checksum on Google Drive differs from your copy. A new campaign is uploaded to its own subfolder with its own ledger file, so old and new runs exist side by side until the switch. To try the new runs early, set `archiveRemote` to the campaign's subfolder and `archiveFile` to its ledger's name. At the switch, the maintainer copies the new ledger over `nrvRuns.rds` and trashes the old campaign's files.
