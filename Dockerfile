# Credit to https://github.com/rockstorm101/jekyll-docker/tree/master

FROM ruby:3.3.6

ENV SETUPDIR=/setup
WORKDIR ${SETUPDIR}
ARG GEMFILE_DIR=.
COPY $GEMFILE_DIR/Gemfile* $GEMFILE_DIR/packages* ./

# Install build dependencies and ImageMagick JPEG/WebP support.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        imagemagick \
        libjpeg62-turbo \
        libwebp7 \
        zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*

# Install Bundler
RUN set -eux; gem install bundler

# Install extra Debian packages if needed
RUN set -eux; \
    if [ -e packages ]; then \
        apt-get update; \
        xargs -r apt-get install -y --no-install-recommends < packages; \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Install gems from `Gemfile` via Bundler
RUN set -eux; bundler install

# Remove build dependencies
RUN set -eux; \
    apt-get purge -y --auto-remove build-essential zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*

# Clean up
WORKDIR /srv/jekyll
RUN set -eux; \
    rm -rf \
        ${SETUPDIR} \
        /usr/gem/cache \
        /root/.bundle/cache \
    ;

# EXPOSE 4000
ENTRYPOINT ["bundler", "exec", "jekyll"]
CMD ["--version"]
