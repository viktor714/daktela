library('devtools')

# install the transformation application ancestors
devtools::install_github('keboola/r-application', ref = "master", force = TRUE)
devtools::install_github('keboola/r-docker-application', ref = "master", force = TRUE)
devtools::install_github("keboola/sapi-r-client", ref = "master", force = TRUE)
install.packages("aws.ec2metadata", repos = c(cloudyr = "http://cloudyr.github.io/drat", getOption("repos")))
install.packages("aws.signature", repos = c(cloudyr = "http://cloudyr.github.io/drat", getOption("repos")))

# install really required packages
withCallingHandlers(install.packages("future"), warning = function(w) stop(w))
withCallingHandlers(devtools::install_github("DavisVaughan/furrr"),warning = function(w) stop(w))
