FROM quay.io/keboola/docker-custom-r:1.5.2

WORKDIR /home

# Initialize the transformation runner
COPY . /home/

# Install some commonly used R packages and the R application
RUN Rscript ./init.R

# Run the application
ENTRYPOINT Rscript ./main.R /data/
