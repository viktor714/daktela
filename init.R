# install really required packages
withCallingHandlers(install.packages(
    c('furr', 'devtools'), 
    lib = "/usr/local/lib/R/site-library/",
    dependencies = c("Depends", "Imports", "LinkingTo")), warning = function(w) stop(w))

# install the R application
devtools::install_github('keboola/r-docker-application', ref = "2.0.2")
devtools::install_github('keboola/r-application', ref = "master", force = TRUE)
devtools::install_github('DavisVaughan/furrr', ref = "master", force = TRUE) 

