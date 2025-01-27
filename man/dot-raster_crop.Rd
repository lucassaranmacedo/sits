% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_raster_api.R
\name{.raster_crop}
\alias{.raster_crop}
\title{Raster package internal crop raster function}
\usage{
.raster_crop(r_obj, block, ...)
}
\arguments{
\item{r_obj}{raster package object to be written}

\item{block}{numeric vector with names "first_col", "ncols", "first_row", "nrows".}

\item{...}{additional parameters to be passed to raster package}
}
\value{
numeric matrix
}
\description{
Raster package internal crop raster function
}
\note{
block starts at (0,0)
}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}
}
\keyword{internal}
