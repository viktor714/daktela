# install really required packages
withCallingHandlers(install.packages(
    c('devtools','future','dplyr','data.table','readr','tidyr','digest','stringr','lubridate','purrr','httr'), 
    lib = "/usr/local/lib/R/site-library/"), warning = function(w) stop(w))

# install the R application
devtools::install_github('keboola/r-docker-application', ref = "2.0.2")
devtools::install_github('keboola/r-application', ref = "master", force = TRUE)
devtools::install_github('DavisVaughan/furrr', ref = "master", force = TRUE) 
devtools::install_github('hadley/dplyr', ref = "master", force = TRUE)
devtools::install_github('jeroen/jsonlite', ref = "master", force = TRUE)
