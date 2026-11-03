# simListArchive

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
