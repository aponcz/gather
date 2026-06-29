FROM ruby:3.3-slim

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev curl git && rm -rf /var/lib/apt/lists/*
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs postgresql-client
RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      pkg-config \
      libpq-dev \
      libyaml-dev \
      nodejs \
      postgresql-client

WORKDIR /app
COPY Gemfile ./
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["bash", "-lc", "bundle exec rails db:prepare && bundle exec puma -C config/puma.rb"]
