# Changelog

## 2.0.8 - 2026-10-30

### Changes

- [FEATURE] Add make release to tag releases including their changelog
- [FEATURE] Generate the changelog from git tags and commits

## 2.0.7 - 2026-10-30

### Breaking changes

- The environment variable `VERSION` in the image was renamed to `POSTGRES_VERSION`, in line with all other PostgreSQL related variables. Scripts or healthchecks reading `$VERSION` inside the container have to use `$POSTGRES_VERSION` instead.
- The per version Dockerfiles in `Versions/<version>.x/` were replaced by a single `Dockerfile`. Custom builds have to pass the client version as build argument, e.g. `docker buildx build --build-arg POSTGRES_VERSION=18 .`

The published image tags and the platforms (`linux/amd64`, `linux/arm64`, `linux/arm/v7`) are unchanged.

### Changes

- [FEATURE] Publish the Docker Hub description from the repository
- [BUGFIX] Correct wrong paths, defaults and examples in the README
- [BUGFIX] Show a proper name for the skipped publish job
- [TASK] Write the build cache only for release tags
- [TASK] Cross-compile dockerize instead of building it under emulation
- [TASK] Test all platforms and publish only on tags
- [TASK] Build all PostgreSQL versions from a single Dockerfile

## 2.0.6 - 2026-10-17

### Changes

- [BUGFIX] Detect failed backups and never rotate out good ones

## 2.0.5 - 2026-10-17

### Changes

- [FEATURE] Add PostgreSQL 18 image
- [TASK] Remove some build parameters
- [TASK] Put output of build into outputs of step

## 2.0.4 - 2025-09-20

### Changes

- [TASK] Remove some build parameters

## 2.0.3 - 2025-09-20

### Changes

- [TASK] Put output of build into outputs of step
- [TASK] Put output of build into outputs of step
- [TASK] Put output of build into outputs of step
- [TASK] Put output of build into outputs of step
- [TASK] Put output of build into outputs of step
- [TASK] Put output of build into outputs of step
- [TASK] Make docker run not interactive
- [TASK] Lower run time
- [TASK] Change file mode

## 2.0.2 - 2025-09-20

### Changes

- [TASK] Remove labels from build
- [TASK] Change build step

## 2.0.1 - 2025-09-20

### Changes

- [TASK] Add qemu to build multiplatform

## 2.0.0 - 2025-09-20

### Changes

- [TASK] Limit tags for test build
- [TASK] Change version
- [TASK] Try remove platform in test
- [TASK] Add environment variables
- [TASK] Implement backup for postgresql 16 & 17

## 1.0.0 - 2025-02-27

### Changes

- [TASK] Improve dockerimage.yml
- [TASK] Cleanup Dockerfile
- [TASK] Improve configuration
- [TASK] Cleanup scripts
- Change example
- Fix github action uses call
- Fix github action test
- Implement backup and restore for postgres databases
