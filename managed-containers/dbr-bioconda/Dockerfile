# Stage 1: Base
FROM databricksruntime/python:12.2-LTS@sha256:fbf937745cf9673103a0d50123021be8daa6b744e69426de27148994ccafcfce AS base

RUN apt-get update && apt-get install -y wget=1.20.3-1ubuntu1 bzip2=1.0.8-2 libdigest-sha-perl=6.02-1build2 && rm -rf /var/lib/apt/lists/*

# Conda must be installed at /databricks/conda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-py38_23.3.1-0-Linux-x86_64.sh -O miniconda.sh \
    && /bin/bash miniconda.sh -b -p /databricks/conda \
    && rm miniconda.sh

# Stage 2: Environment Setup
FROM base AS env-setup

COPY env.yml /databricks/.conda-env-def/env.yml

RUN /databricks/conda/bin/conda env create --file /databricks/.conda-env-def/env.yml \
    && ln -s /databricks/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

RUN /databricks/conda/bin/conda config --system --set channel_priority strict \
    && /databricks/conda/bin/conda config --system --set always_yes True

# Stage 3: Final
FROM base AS final

RUN useradd -m appuser
USER appuser

COPY --from=env-setup /databricks/conda /databricks/conda
COPY --from=env-setup /etc/profile.d/conda.sh /etc/profile.d/conda.sh

ENV DEFAULT_DATABRICKS_ROOT_CONDA_ENV=fsdh-bioconda
ENV DATABRICKS_ROOT_CONDA_ENV=fsdh-bioconda

HEALTHCHECK CMD curl --fail http://localhost:3000 || exit 1