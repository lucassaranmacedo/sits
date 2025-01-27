#' @title Format tile parameter provided by users
#' @name .usgs_format_tiles
#' @keywords internal
#'
#' @param tiles     a \code{character} vector with the tiles provided by users.
#'
#' @return          a \code{tibble} with attributes of wrs path and row.
.usgs_format_tiles <- function(tiles) {

    # regex pattern of wrs_path and wrs_row
    pattern_l8 <- "[0-9]{6}"

    # verify tile pattern
    if (!any(grepl(pattern_l8, tiles, perl = TRUE)))
        stop(paste("The specified tiles do not match the Landsat-8 grid",
                   "pattern. See the user guide for more information."))

    # list to store the info about the tiles to provide the query in STAC
    list_tiles <- purrr::map(tiles, function(tile) {

        c(wrs_path = substring(tile, 1, 3),
          wrs_row = substring(tile, 4, 6))
    })

    # bind into a tibble all tiles
    tiles_tbl <- dplyr::bind_rows(list_tiles)

    return(tiles_tbl)
}

#' @title Filter datetime in STAC items
#' @name .usgs_filter_datetime
#' @keywords internal
#'
#' @param items      a \code{STACItemCollection} object returned by rstac
#' package.
#' @param datetime  a \code{character} ...
#'
#' @return  a \code{STACItemCollection} object with datetime filtered.
.usgs_filter_datetime <- function(items, datetime) {

    split_datetime <- strsplit(x = datetime, split = "/")

    start_date <- split_datetime[[1]][[1]]
    end_date <- split_datetime[[1]][[2]]

    # checks if the supplied tiles are in the searched items
    index_features <- purrr::map_lgl(items$features, function(feature) {
        datetime <- lubridate::date(feature[["properties"]][["datetime"]])

        if (datetime >= start_date && datetime <= end_date)
            return(TRUE)
        return(FALSE)
    })

    # select the tiles found in the search
    items$features <- items$features[index_features]

    items
}

.source_collection_access_test.usgs_cube <- function(source, ..., collection, bands) {

    # require package
    if (!requireNamespace("rstac", quietly = TRUE)) {
        stop("Please install package rstac", call. = FALSE)
    }

    items_query <- .stac_items_query(source = source,
                                     collection = collection,
                                     limit = 1)


    items_query$version <- .config_get(key = c("sources", source,
                                               "rstac_version"))

    items_query <- rstac::ext_query(q = items_query,
                                    "landsat:correction" %in% "L2SR",
                                    "platform" %in% "LANDSAT_8",
                                    "landsat:collection_number" %in% "02")

    # assert that service is online
    tryCatch({
        items <- rstac::post_request(items_query)
    }, error = function(e) {
        stop(paste(".source_collection_access_test.usgs_cube: service is",
                   "unreachable\n", e$message), call. = FALSE)
    })

    items <- .source_items_bands_select(source = source, ...,
                                        collection = collection,
                                        items = items,
                                        bands = bands[[1]])

    href <- .source_item_get_hrefs(source = source, ...,
                                   item = items$feature[[1]],
                                   collection = collection)

    # assert that token and/or href is valid
    tryCatch({
        .raster_open_rast(href)
    }, error = function(e) {
        stop(paste(".source_collection_access_test.usgs_cube: cannot open url\n",
                   href, "\n", e$message), call. = FALSE)
    })

    return(invisible(NULL))
}

#' @keywords internal
#' @export
.source_item_get_hrefs.usgs_cube <- function(source, ...,
                                             item,
                                             collection = NULL) {


    href <- purrr::map_chr(item[["assets"]], function(x) {
        x[["alternate"]][[c("s3", "href")]]
    })

    # add gdal vsi in href urls
    return(.stac_add_gdal_vsi(href))
}

#' @keywords internal
#' @export
.source_items_new.usgs_cube <- function(source, ...,
                                        collection,
                                        stac_query,
                                        tiles = NULL) {

    # set caller to show in errors
    .check_set_caller(".source_items_new.usgs_cube")

    # forcing version
    stac_query$version <- "0.9.0"

    # get start and end date
    datetime <- strsplit(x = stac_query$params$datetime, split = "/")[[1]]

    # request with more than searched items throws 502 error
    stac_query$params$limit <- 300

    # adding search filter in query
    stac_query <- rstac::ext_query(
        q = stac_query,
        "landsat:correction" %in% c("L2SR", "L2SP"),
        "landsat:collection_category" %in% c("T1", "T2"),
        "landsat:collection_number" %in% "02",
        "platform" %in% "LANDSAT_8",
        "datetime" >= datetime[[1]],
        "datetime" <= datetime[[2]]
    )

    # if specified, a filter per tile is added to the query
    if (!is.null(tiles)) {

        # format tile parameter provided by users
        sep_tile <- .usgs_format_tiles(tiles)

        # add filter by wrs path and row
        stac_query <- rstac::ext_query(
            q = stac_query,
            "landsat:wrs_path" %in% sep_tile$wrs_path,
            "landsat:wrs_row" %in% sep_tile$wrs_row
        )
    }

    # making the request
    items <- rstac::post_request(q = stac_query, ...)

    items$features <- items$features[grepl("_SR$",
                                           rstac::items_reap(items, "id"))]

    # checks if the collection returned zero items
    .check_that(
        x = !(rstac::items_length(items) == 0),
        msg = "the provided search returned zero items."
    )

    # if more than 2 times items pagination are found the progress bar
    # is displayed
    matched_items  <- rstac::items_matched(items = items,
                                           matched_field = c("meta", "found"))

    pgr_fetch <- matched_items > 2 * .config_rstac_limit()


    # fetching all the metadata and updating to upper case instruments
    items_info <- rstac::items_fetch(items = items,
                                     progress = pgr_fetch,
                                     matched_field = c("meta", "found"))
    return(items_info)
}

#' @keywords internal
#' @export
.source_items_tiles_group.usgs_cube <- function(source, ...,
                                                items,
                                                collection = NULL) {

    # store tile info in items object
    items$features <- purrr::map(items$features, function(feature) {
        feature$properties$tile <- paste0(
            feature$properties[["landsat:wrs_path"]],
            feature$properties[["landsat:wrs_row"]]
        )

        feature
    })

    rstac::items_group(items, field = c("properties", "tile"))
}

#' @keywords internal
#' @export
.source_items_tile_get_crs.usgs_cube <- function(source,
                                                 tile_items, ...,
                                                 collection = NULL) {

    epsg_code <- tile_items[["features"]][[1]][[c("properties", "proj:epsg")]]
    # format collection crs
    crs <- .sits_proj_format_crs(epsg_code)

    return(crs)
}
