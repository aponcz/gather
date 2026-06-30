FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
            curl \
            git \
      pkg-config \
      libpq-dev \
      libyaml-dev \
      nodejs \
            postgresql-client && \
        rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["bash", "-lc", "bundle exec rails db:prepare && bundle exec puma -C config/puma.rb"]
