# Base stage to set up Conda environment
FROM condaforge/miniforge3:24.9.0-0@sha256:44f5a22cb6952aaa9f6ae730c0a815eb4993da1cafc12a80268402f9b966cf0e AS conda-base

# Set environment variables to prevent writing .pyc files and specify the environment file
ENV PYTHONDONTWRITEBYTECODE=1 \
    CONDA_ENV_DEPS=environment.yml

# Set the working directory to /opt
WORKDIR /opt

# Copy the Conda environment file into the image
COPY $CONDA_ENV_DEPS ./

# Initialize Conda, create the Conda environment, clean up, and remove unnecessary files to keep the image small
RUN /opt/conda/bin/conda init bash \ 
    && conda env create --file $CONDA_ENV_DEPS \  
    && conda clean -afy \  
    && rm -rf /opt/conda/pkgs/* /tmp/* /var/tmp/* \  
    && find /opt/conda/ -follow -type f -name '*.pyc' -delete  

# Final image to run the application, starting with a minimal Python image
FROM cgr.dev/chainguard/python@sha256:4e0071d93c68dc02059f220342a75cec135b252970416cb4e4bfd28024c7e2e1 AS final

# Set environment variables for the application
ENV LANG=C.UTF-8 \  
    PYTHONDONTWRITEBYTECODE=1 \  
    PYTHONPATH=/app \  
    PYTHONUNBUFFERED=1 \  
    CONDA_ENV_PATH=/opt/conda/envs/snowexplorer 

ENV PATH="$CONDA_ENV_PATH/bin:$PATH"

# Copy the Conda environment from the conda-base stage, maintaining permissions for non-root user
COPY --from=conda-base --chown=nonroot:nonroot $CONDA_ENV_PATH $CONDA_ENV_PATH

# Expose the port that the application will use
EXPOSE 8080

# Set the user to non-root for security purposes
USER nonroot

# Add a health check to ensure the container is functioning correctly
HEALTHCHECK CMD curl --fail http://localhost:8080/health || exit 1

# Set the entry point to start the application using Conda
ENTRYPOINT ["python", "-m", "panel", "serve", "/snowexplorer.ipynb", "--index=snowexplorer", "--port=8080", "--address=0.0.0.0"]

# Default command-line options for the panel server
CMD ["--num-procs=1", \  
     "--num-threads=10", \  
     "--websocket-max-message-size=100000000", \
     "--allow-websocket-origin=*" \
    ]
