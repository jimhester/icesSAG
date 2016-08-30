#' @importFrom RCurl basicTextGatherer
#' @importFrom RCurl curlPerform
curlSAG <- function(url) {
  # read only XML table and return as txt string
  reader <- basicTextGatherer()
  curlPerform(url = url,
              httpheader = c('Content-Type' = "text/xml; charset=utf-8", SOAPAction=""),
              writefunction = reader$update,
              verbose = FALSE)
  # return
  reader$value()
}

#' @importFrom XML xmlParse
#' @importFrom XML xmlToDataFrame
#' @importFrom utils capture.output
parseSAG <- function(x) {
  # parse the xml text string suppplied by the SAG webservice
  # returning a dataframe
  capture.output(x <- xmlParse(x))
  # capture.output is used to stiffle the output message from xmlns:
  #   "xmlns: URI ices.dk.local/SAG is not absolute"

  # convert xml to data frame
  x <- xmlToDataFrame(x, stringsAsFactors = FALSE)

  # clean trailing white space from text columns
  charcol <- which(sapply(x, is.character))
  x[charcol] <- lapply(x[charcol], function(x) gsub("[[:space:]]*$", "", x))

  ## SAG uses "" and "NA" to indicate NA
  x[x == ""] <- NA
  x[x == "NA"] <- NA
  x
}


checkSAGWebserviceOK <- function() {
  # return TRUE if webservice server is good, FALSE otherwise
  out <- curlSAG(url = "https://datras.ices.dk/WebServices/StandardGraphsWebServices.asmx")

  # Check the server is not down by insepcting the XML response for internal server error message.
  if(grepl("Internal Server Error", out)) {
    warning("Web service failure: the server seems to be down, please try again later.")
    FALSE
  } else {
    TRUE
  }
}

#' @importFrom XML xmlRoot
#' @importFrom XML xmlParse
#' @importFrom XML xmlSApply
#' @importFrom XML xmlParse
#' @importFrom XML xmlValue

parseSummary <- function(x) {
  #
  # Extract data
  summaryNames <- xmlRoot(xmlParse(x))

  # Parse XML data and convert into a data frame
  xmlDat <- xmlSApply(summaryNames[["lines"]],
                      function(x) xmlSApply(x,
                                            xmlValue))
  xmlDat[sapply(xmlDat,
                function(x) length(x) == 0)] <- NA
  colnames(xmlDat) <- NULL
  summaryInfo <- as.data.frame(t(xmlDat))
  #
  stockList <- names(summaryNames[names(summaryNames) != "lines"])
  stockValue <- rbind(lapply(stockList,
                              function(x) xmlSApply(summaryNames[[x]],
                                                    xmlValue)))
  stockValue[sapply(stockValue,
                    function(x) length(x) == 0)] <- NA
  stockValue <- as.data.frame(lapply(stockValue,
                                     function(x) as.character(x)))
  colnames(stockValue) <- stockList
  #
  summaryInfo <- cbind(summaryInfo, stockValue)
  summaryInfo[summaryInfo == ""] <- NA
  summaryInfo[summaryInfo == "NA"] <- NA
  summaryInfo
}


simplify <- function(x) {
  # from Arni's toolbox
  # coerce object to simplest storage mode: factor > character > numeric > integer
  owarn <- options(warn = -1)
  on.exit(options(owarn))
  # list or data.frame
  if (is.list(x)) {
    if (is.data.frame(x)) {
      old.row.names <- attr(x, "row.names")
      x <- lapply(x, simplify)
      attributes(x) <- list(names = names(x), row.names = old.row.names, class = "data.frame")
    }
    else
      x <- lapply(x, simplify)
  }
  # matrix
  else if (is.matrix(x))
  {
    if (is.character(x) && sum(is.na(as.numeric(x))) == sum(is.na(x)))
      mode(x) <- "numeric"
    if (is.numeric(x))
    {
      y <- as.integer(x)
      if (sum(is.na(x)) == sum(is.na(y)) && all(x == y, na.rm = TRUE))
        mode(x) <- "integer"
    }
  }
  # vector
  else
  {
    if (is.factor(x))
      x <- as.character(x)
    if (is.character(x))
    {
      y <- as.numeric(x)
      if (sum(is.na(y)) == sum(is.na(x)))
        x <- y
    }
    if (is.numeric(x))
    {
      y <- as.integer(x)
      if (sum(is.na(x)) == sum(is.na(y)) && all(x == y, na.rm = TRUE))
        x <- y
    }
  }
  x
}