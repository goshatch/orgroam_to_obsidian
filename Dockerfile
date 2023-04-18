FROM pandoc/alpine:latest

RUN apk update
RUN apk add ruby ruby-etc
RUN gem install bundler

RUN mkdir -p /opt/orgroam-to-obsidian
WORKDIR /opt/orgroam-to-obsidian
ADD . /opt/orgroam-to-obsidian
RUN bundle install

ENTRYPOINT ["/opt/orgroam-to-obsidian/convert.rb"]
