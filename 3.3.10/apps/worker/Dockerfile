# Multi-stage: compile the Go worker inside the build image, so the lab box
# needs only Docker (no host Go toolchain).
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
# tidy resolves every OTel/Pyroscope dependency from the imports, then build.
RUN go mod tidy && CGO_ENABLED=0 go build -trimpath -o /worker .

FROM gcr.io/distroless/static-debian12
COPY --from=build /worker /worker
EXPOSE 8080
ENTRYPOINT ["/worker"]
