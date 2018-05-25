library('devtools')

# install the transformation application ancestors
devtools::install_github('keboola/r-application', ref = "master", force = TRUE)
devtools::install_github('keboola/r-docker-application', ref = "master", force = TRUE)
devtools::install_github("keboola/sapi-r-client", ref = "master", force = TRUE)
devtools::install_github("cloudyr/aws.signature")

# install really required packages
withCallingHandlers(install.packages("future" , force = TRUE), warning = function(w) stop(w))
withCallingHandlers(devtools::install_github("DavisVaughan/furrr", force = TRUE),warning = function(w) stop(w))
