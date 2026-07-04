FROM ruby:3.4.1

# Install system dependencies and nano
RUN apt-get update -qq && apt-get install -y build-essential nano
# Install dependencies
RUN apt-get update -qq && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/api
ADD . /app/api/

EXPOSE 3000
RUN gem install bundler
RUN bundle install

RUN ["irb"]
