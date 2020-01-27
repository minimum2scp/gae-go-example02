# gae-go-example02
Hello world app on AppEngine Go / Deploy with AppEngine Admin API

## Build / Run (local) / Test

### Prerequisites

- Go 1.11.x
- Set environment variable `GO111MODULE=on`

### Commands

Run local web server without build:

```shell
go run server.go
```

or, build and run:

```shell
go build
./gae-go-example02
```

Test:

```
go test
```

## Deploy to Google AppEngine by AppEngine Admin API

### Stage source files to Cloud Storage

#### Prerequisites

- Set environment variable `GO111MODULE=on`
- Google Cloud SDK is installed
  * `app-engine-go` component is installed
  * Project ID is set by `gcloud config set project [YOUR-PROJECT-ID]` or `export CLOUDSDK_CORE_PROJECT=[YOUR-PROJECT-ID]`

#### Command

```shell
./deploy-tools/stage.sh v1
```

### Create AppEngine version by AppEngine Admin API

#### Prerequisites

- Google Cloud SDK is installed
  * Project ID is set by `gcloud config set project [YOUR-PROJECT-ID]` or `export CLOUDSDK_CORE_PROJECT=[YOUR-PROJECT-ID]`
- Ruby is installed

#### Command

```shell
./deploy-tools/create-version.sh v1
```

