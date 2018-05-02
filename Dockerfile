FROM certbot/certbot:v0.23.0

RUN apk update && apk add --no-cache bash curl

ENTRYPOINT ["/bin/bash"]

COPY script.sh .

CMD ["script.sh"]
