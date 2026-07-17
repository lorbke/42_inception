FROM alpine:3.23

RUN apk add --no-cache glances py3-fastapi uvicorn py3-dateutil

EXPOSE 61208

CMD ["glances", "-w"]