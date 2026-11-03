# simListArchive 0.0.0.9000

* Each object starts from its own latest save at or before `start`, read from the run's index. The NRV runs save `vegTypeMap` at 61 years but `cohortData` every 100, and the year taken from the ledger's `saveTimes` could have no `cohortData`.
* First version: finds archived runs by study area and supplies their saved outputs.
