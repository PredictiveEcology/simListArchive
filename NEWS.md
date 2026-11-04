# simListArchive (development version)

* New output `climateYearRecord`: for each run and each simulation year within `start` to `end`, the climate year it used (`runName`, `ELF`, `simYear`, `climateYear`). It is read from the saved simList, one small member, not the large objects. If the runs joined used different climate years for the same simulation year, one warning names them.
* The default `archiveFile` is now `nrvRuns.rds`, the ledger of the current campaign, instead of `nrvRuns_phase5.rds`. See "Campaigns" in the README.

# simListArchive 0.0.0.9000

* Each object starts from its own latest save at or before `start`, read from the run's index. The NRV runs save `vegTypeMap` at 61 years but `cohortData` every 100, and the year taken from the ledger's `saveTimes` could have no `cohortData`.
* First version: finds archived runs by study area and supplies their saved outputs.
