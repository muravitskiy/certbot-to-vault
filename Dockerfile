FROM certbot/certbot:v0.23.0

RUN apk add --no-cache curl

ENTRYPOINT ["/bin/sh"]

COPY script.sh .

CMD ["script.sh"]
