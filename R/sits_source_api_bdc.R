#' @keywords internal
#' @export
.source_item_get_hrefs.bdc_cube <- function(source, ...,
                                            item,
                                            collection = NULL) {

    access_key <- Sys.getenv("BDC_ACCESS_KEY")

    href <- paste0(unname(purrr::map_chr(item[["assets"]], `[[`, "href")),
           "?access_token=", access_key)

    # add gdal vsi in href urls
    return(.stac_add_gdal_vsi(href))
}



#' @keywords internal
#' @export
.source_items_new.bdc_cube <- function(source, ...,
                                       collection,
                                       stac_query,
                                       tiles = NULL) {

    # set caller to show in errors
    .check_set_caller(".source_items_new.bdc_cube")

    # if specified, a filter per tile is added to the query
    if (!is.null(tiles))
        stac_query <- rstac::ext_query(q = stac_query, "bdc:tile" %in% tiles)

    # making the request
    items_info <- rstac::post_request(q = stac_query, ...)

    # check if matched items
    .check_that(
        x = rstac::items_matched(items_info) > 0,
        msg = "no items matched the query criteria."
    )

    # if more than 2 times items pagination are found the progress bar
    # is displayed
    pgr_fetch <- rstac::items_matched(items_info) > 2 * .config_rstac_limit()

    # fetching all the metadata
    items_info <- rstac::items_fetch(items = items_info, progress = pgr_fetch)

    return(items_info)
}

#' @keywords internal
#' @export
.source_items_tiles_group.bdc_cube <- function(source, ...,
                                               items,
                                               collection = NULL) {

    rstac::items_group(items, field = c("properties", "bdc:tiles"))
}

#' @keywords internal
#' @export
.source_items_tile_get_crs.bdc_cube <- function(source, ...,
                                                tile_items,
                                                collection = NULL) {

    # making request to collection endpoint to get crs info
    url <- .source_url(source = source)
    query_search <- rstac::collections(q = rstac::stac(url),
                                       collection_id = collection)

    col <- rstac::get_request(q = query_search)

    return(col[["bdc:crs"]])
}

#' @keywords internal
#' @export
.source_items_tile_get_name.bdc_cube <- function(source, ...,
                                                 collection,
                                                 tile_items) {

    tile_items[["features"]][[1]][[c("properties", "bdc:tiles")]]
}
