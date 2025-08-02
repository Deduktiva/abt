# ABT Invoice System
# Rails application with FOP PDF generation

FROM ruby:3.3-slim

# Install system dependencies including FOP
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        build-essential \
        libpq-dev \
        fop \
        libsaxon-java \
        openjdk-21-jre-headless \
        git \
        curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Copy application code
COPY . .

# Set environment variables for FOP
ENV JAVA_OPTS="-Djavax.xml.transform.TransformerFactory=net.sf.saxon.TransformerFactoryImpl"
ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true

# Precompile assets
RUN bundle exec rails assets:precompile

# Create non-root user
RUN useradd -m -u 1000 rails && \
    chown -R rails:rails /app
USER rails

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]