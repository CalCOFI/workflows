# source: https://bookdown.org/yihui/rmarkdown-cookbook/time-chunk.html
knitr::knit_hooks$set(time_chunk = local({
  now <- NULL
  function(before, options) {
    if (before) {
      # record the current time before each chunk
      now <<- Sys.time()
    } else {
      # calculate the time difference after a chunk
      res <- difftime(Sys.time(), now, units = "secs") %>% as.numeric()
      # return a character string to show the time
      paste("Time for the chunk `", options$label, "` to run:", signif(res, 4), " seconds")
    }
  }
}))