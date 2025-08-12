# syntax=docker/dockerfile:1.6
FROM golang:1.24 as builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/k8s-addon ./cmd/addon

FROM gcr.io/distroless/base-debian12:nonroot
USER nonroot:nonroot
COPY --from=builder /out/k8s-addon /k8s-addon
ENTRYPOINT ["/k8s-addon"]
