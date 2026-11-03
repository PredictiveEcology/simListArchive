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
