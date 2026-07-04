FROM ruby:3.4.1

WORKDIR /app/api
ADD . /app/api/

EXPOSE 3000
RUN gem install bundler
RUN bundle install

RUN curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.6.1/cloud-sql-proxy.linux.amd64
RUN chmod +x cloud-sql-proxy