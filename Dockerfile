FROM debian:trixie-slim

# Install system dependencies for Rails application
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        # Ruby and build dependencies
        ruby \
        ruby-dev \
        build-essential \
        # Database clients
        libpq-dev \
        libsqlite3-dev \
        # YAML library for psych gem
        libyaml-dev \
        # System utilities
        curl \
        git \
        # Apache and Passenger
        apache2 \
        apache2-dev \
        # FOP and Java dependencies
        fop \
        libsaxonb-java \
        openjdk-21-jre-headless \
        # Node.js for asset compilation
        nodejs \
        npm && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Passenger for Apache using system package
RUN apt-get update -qq && \
    apt-get install -y -qq libapache2-mod-passenger && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure FOP extra jars
ENV FOP_EXTRA_JAR_PATH /usr/local/fop-extra-jars
RUN curl -L -o pdfimages.tgz 'https://archive.apache.org/dist/xmlgraphics/fop-pdf-images/binaries/fop-pdf-images-2.11-bin.tar.gz' && \
    mkdir "$FOP_EXTRA_JAR_PATH" && \
    tar --strip-components=1 -x -f pdfimages.tgz -C "$FOP_EXTRA_JAR_PATH" && \
    rm pdfimages.tgz

# Create application user
RUN useradd -m -u 1000 -s /bin/bash abtuser && \
    mkdir -p /var/www/abt && \
    chown abtuser:abtuser /var/www/abt

# Set working directory
WORKDIR /var/www/abt

# Copy application files
COPY --chown=abtuser:abtuser . .

# Install bundler and gems
USER abtuser
ENV PATH="/home/abtuser/.local/share/gem/ruby/3.3.0/bin:$PATH"
RUN gem install bundler --no-document && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Set production environment
ENV RAILS_ENV=production
ENV RACK_ENV=production

# Precompile assets
RUN bundle exec rails assets:precompile

# Create necessary directories
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log

# Switch back to root for Apache configuration
USER root

# Configure Apache
COPY docker/apache2.conf /etc/apache2/sites-available/abt.conf
RUN a2enmod rewrite && \
    a2enmod passenger && \
    a2ensite abt && \
    a2dissite 000-default

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start Apache
CMD ["apache2ctl", "-D", "FOREGROUND"]

# Metadata
LABEL maintainer="ABT Invoice System"
LABEL description="ABT Rails application with Apache and Passenger"
LABEL version="production"