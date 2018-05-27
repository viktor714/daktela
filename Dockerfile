FROM rocker/r-ver:3.4.3

ENV PATH /usr/local/lib/R/bin/:$PATH
ENV R_HOME /usr/local/lib/R

WORKDIR /tmp

# Install dependencies for packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        default-jdk \
        ed \
        git \
        libbz2-dev \
        libcairo2-dev \
        libgdal-dev \
        libcgal-dev \
        libglu1-mesa-dev \
        libgsl0-dev \
        libproj-dev \
        libssl-dev \
        libx11-dev \
        libxt-dev \
        xfonts-base \
        unzip \
        x11proto-core-dev \
    && rm -rf /var/lib/apt/lists/*
    
# Initialize the transformation runner
COPY . /tmp/
COPY main.R /tmp/main.R

# Install some commonly used R packages and the R application
RUN Rscript ./init.R

# Run the application
ENTRYPOINT /usr/local/lib/R/bin/Rscript /tmp/main.R 
