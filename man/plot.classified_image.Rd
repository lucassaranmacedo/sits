% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_plot.R
\name{plot.classified_image}
\alias{plot.classified_image}
\title{Generic interface for ploting classified images}
\usage{
\method{plot}{classified_image}(
  x,
  y,
  ...,
  time = 1,
  title = "Classified Image",
  legend = NULL,
  palette = "default"
)
}
\arguments{
\item{x}{object of class "classified_image"}

\item{y}{ignored}

\item{...}{further specifications for \link{plot}.}

\item{time}{temporal reference for plot.}

\item{title}{Title of the plot}

\item{legend}{named vector that associates labels to colors}

\item{palette}{palette provided in the configuration file}
}
\description{
plots a classified raster using ggplot.
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
