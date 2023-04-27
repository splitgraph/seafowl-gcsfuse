# This Dockerfile combines Seafowl and gcsfuse to enable
# scale to zero, via "local" SQLite catalog

# Seafowl https://github.com/splitgraph/seafowl/blob/main/Dockerfile
# gcsfuse https://github.com/GoogleCloudPlatform/python-docs-samples/blob/main/run/filesystem/Dockerfile

# While this Dockerfile builds a working default container, 
# it's intended for you to mount a different `seafowl.toml` 
# at /app/config/seafowl.toml to make a deployment actually useful.

# WARNING: Not including `[frontend.http]` in your seafowl.toml 
# means Seafowl will not listen for HTTP (and quit). 
# Unless you're intending to do a one-off task  e.g. creating 
# the SQLite db, you probably want Seafowl to listen.
# Please edit your config accordingly.

FROM debian:bullseye-slim

# Install gcsfuse + dependencies
RUN set -e; \
    apt-get update -qq && apt-get install -y \
    tini \
    lsb-release \
    gnupg \
    curl; \
    gcsFuseRepo=gcsfuse-`lsb_release -c -s`; \
    echo "deb http://packages.cloud.google.com/apt $gcsFuseRepo main" | \
    tee /etc/apt/sources.list.d/gcsfuse.list; \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key add -; \
    apt-get update; \
    apt-get install -y gcsfuse \
    && apt-get clean

# Set fallback mount directory
ENV MNT_DIR /app/seafowl-data

# Use /app to contain seafowl + config
ENV APP_HOME /app
WORKDIR $APP_HOME

# Fetch and decompress Seafowl binary
RUN set -e; \
    curl -L https://github.com/splitgraph/seafowl/releases/download/v0.3.3/seafowl-v0.3.3-x86_64-unknown-linux-gnu.tar.gz \
    | tar -xz

# Copy seafowl + gcsfuse_run.sh to the container
COPY . ./

# NOTE: we add a dummy default config so `seafowl` will start, but 
# for actual deployments we want to mount our custom 
# seafowl.toml to /app/seafowl.toml
# IMPORTANT: make sure to set bind_host to 0.0.0.0 because containers
RUN \
    mkdir /app/config; \
    mv seafowl.toml /app/config/seafowl.toml

# Ensure the script is executable
RUN chmod +x gcsfuse_run.sh

# Use tini to manage zombie processes and signal forwarding
# https://github.com/krallin/tini
ENTRYPOINT ["/usr/bin/tini", "--"] 

# Pass the startup script as arguments to Tini
CMD ["/app/gcsfuse_run.sh"]