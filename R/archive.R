## A sliver is an overlap narrower than 10 km. The ledger's tolerance shrinks inward, so it is half that.
.archiveTolerance <- 5000
.archiveNotScenario <- c("runName", "driveId", "saveTimes", "uploaded", "outputPath")

## Exactly one ledger row for each polygon under `area`. Selection is spatial first; `scenario` then
## chooses among the runs of each polygon. Anything but exactly one run per polygon is an error.
archiveSelectRuns <- function(ledger, area, scenario = list()) {
  rows <- reproducible::CacheGeoRead(ledger, area, match = "covers", tolerance = .archiveTolerance)
  if (!NROW(rows)) {
    some <- reproducible::CacheGeoRead(ledger, area, match = "intersects", tolerance = .archiveTolerance, verbose = 0)
    stop("The archive ", ledger$file, " does not cover the study area. ",
         if (NROW(some)) paste0("It covers only part of it, with:\n", .archiveAvailable(some))
         else "No run overlaps it.", call. = FALSE)
  }
  polygon <- vapply(sf::st_equals(rows), min, integer(1))
  absent <- setdiff(names(scenario), names(rows))
  if (length(absent))
    stop("`scenario` names column(s) the archive does not have: ", paste(absent, collapse = ", "),
         "\nAvailable for this study area:\n", .archiveAvailable(rows), call. = FALSE)
  keep <- rep(TRUE, NROW(rows))
  for (nam in names(scenario)) keep <- keep & as.character(rows[[nam]]) %in% as.character(scenario[[nam]])
  counts <- tabulate(match(polygon[keep], unique(polygon)), nbins = length(unique(polygon)))
  if (any(counts != 1L))
    stop("`scenario` must identify one run for each polygon of the study area; it gives ",
         paste(counts, collapse = ", "), ".\nAvailable for this study area:\n", .archiveAvailable(rows), call. = FALSE)
  rows[keep, ]
}

.archiveAvailable <- function(rows) {
  tab <- unique(sf::st_drop_geometry(rows)[, setdiff(names(rows), c(.archiveNotScenario, attr(rows, "sf_column"))), drop = FALSE])
  paste(utils::capture.output(print(tab, row.names = FALSE)), collapse = "\n")
}

## A run's saved files as a table: run, object, year, file. They are told by name, `<object>_year<year>.<ext>`,
## as modules that register their own outputs leave objectName empty in outputs(sim).
.archiveFileTable <- function(files, objects, run) {
  pat <- paste0("^(", paste(objects, collapse = "|"), ")_year0*([0-9]+)\\.[A-Za-z0-9]+$")
  files <- files[grepl(pat, basename(files))]
  data.table::data.table(run = run, object = sub(pat, "\\1", basename(files)),
                         year = as.numeric(sub(pat, "\\2", basename(files))), file = files)
}

## Download the files needed, for `start` (or each object's latest save before it) to `end`, and nothing else.
## Objects are saved at different years, so the years are chosen per object, from the run's index.
archiveFetch <- function(runs, objects, start, end, destDir) {
  out <- lapply(seq_len(NROW(runs)), function(i) {
    saved <- .archiveFileTable(SpaDES.project::reIndex(runs$driveId[i], destDir)$name, objects, run = i)
    wanted <- unlist(lapply(objects, function(obj) {
      st <- sort(unique(saved$year[saved$object == obj]))
      if (!length(st)) return(NULL)
      before <- st[st <= start]
      if (!length(before))
        stop("The archive has no ", obj, " saved at or before year ", start, "; its first is ", min(st), call. = FALSE)
      paste0(obj, "_year0*", st[st >= max(before) & st <= end])
    }))
    pattern <- paste0("^(", paste(wanted, collapse = "|"), ")\\.")
    remap <- c(old = runs$outputPath[i], new = file.path(destDir, runs$runName[i]))
    sim <- SpaDES.project::reGetUntarLoad(runs$driveId[i], destDir = destDir, pathRemap = remap, remote = TRUE,
                                          outputsPattern = pattern)[[1]]
    .archiveFileTable(SpaDES.core::outputs(sim)$file, objects, run = i)
  })
  files <- data.table::rbindlist(out)
  missed <- setdiff(objects, files$object)
  if (length(missed))
    stop("The archived runs have no saved files for: ", paste(missed, collapse = ", "), call. = FALSE)
  files
}

## The saved years, within start to end, that every run has
archiveTimes <- function(files, start, end) {
  years <- Reduce(intersect, split(files$year, files$run))
  sort(unique(years[years >= start & years <= end]))
}

.archiveRead <- function(file) {
  switch(tolower(tools::file_ext(file)),
         qs2 = qs2::qs_read(file),
         rds = readRDS(file),
         tif = terra::rast(file),
         stop("simListArchive cannot read ", basename(file), call. = FALSE))
}

## Each run's own values in its own polygon, cropped to `area`, joined into one object per name.
## pixelGroup ids restart in each run, so each run's are moved past those of the runs before it.
archiveLoadYear <- function(files, runs, area, atYear) {
  sel <- as.data.frame(files)
  sel <- sel[sel$year <= atYear, ]
  sel <- sel[sel$year == stats::ave(sel$year, sel$object, FUN = max), ]
  late <- unique(sel$year[sel$year < atYear])
  if (length(late) && !any(files$year == atYear))
    warning("simListArchive: no save for year ", atYear, "; using year ", paste(late, collapse = ", "), call. = FALSE)
  polygons <- sf::st_geometry(runs)
  out <- list()
  offset <- 0L
  for (i in seq_len(NROW(runs))) {
    thisRun <- sel[sel$run == i, ]
    objs <- stats::setNames(lapply(thisRun$file, .archiveRead), thisRun$object)
    isRast <- vapply(objs, inherits, logical(1), "SpatRaster")
    objs[isRast] <- lapply(objs[isRast], .archiveClip, polygon = polygons[i], area = area)
    if (!is.null(objs$pixelGroupMap)) {
      groups <- setdiff(stats::na.omit(unique(terra::values(objs$pixelGroupMap, mat = FALSE))), 0)
      ## group 0 (a pixel with no cohorts) stays 0 in every run
      objs$pixelGroupMap <- terra::ifel(objs$pixelGroupMap > 0, objs$pixelGroupMap + offset, 0L)
      if (!is.null(objs$cohortData)) {
        cd <- as.data.frame(objs$cohortData)
        cd <- cd[cd$pixelGroup %in% groups, ]
        cd$pixelGroup <- cd$pixelGroup + offset
        objs$cohortData <- data.table::as.data.table(cd)
      }
      if (length(groups)) offset <- offset + as.integer(max(groups))
    }
    for (nam in names(objs)) out[[nam]] <- c(out[[nam]], objs[nam])
  }
  lapply(out, .archiveJoin)
}

.archiveClip <- function(r, polygon, area) {
  v <- terra::project(terra::vect(sf::st_as_sf(polygon)), terra::crs(r))
  a <- terra::project(terra::vect(sf::st_as_sf(sf::st_geometry(area))), terra::crs(r))
  terra::mask(terra::mask(terra::crop(r, a, snap = "out"), v), a)
}

.archiveJoin <- function(pieces) {
  pieces <- unname(pieces)
  if (length(pieces) == 1L) return(pieces[[1]])
  if (!inherits(pieces[[1]], "SpatRaster")) return(data.table::rbindlist(pieces, use.names = TRUE, fill = TRUE))
  ref <- pieces[[1]]
  aligned <- vapply(pieces[-1], function(p)
    terra::same.crs(ref, p) && isTRUE(all.equal(terra::res(ref), terra::res(p))) &&
      isTRUE(all.equal(terra::origin(ref), terra::origin(p))), logical(1))
  if (!all(aligned)) stop("The archived runs are on different grids, so they cannot be joined", call. = FALSE)
  terra::merge(terra::sprc(pieces))
}
