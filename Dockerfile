FROM rocker/r-ver:3.4.3

ENV PATH /usr/local/lib/R/bin/:$PATH
ENV R_HOME /usr/local/lib/R

WORKDIR /tmp

# Install dependencies for packages
RUN     RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*
    
# Initialize the transformation runner
COPY . /tmp/

# Install some commonly used R packages and the R application
RUN Rscript ./init.R

# Run the application
ENTRYPOINT Rscript ./main.R /data/
