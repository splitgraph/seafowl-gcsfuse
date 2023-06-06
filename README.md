### Scale to zero Seafowl via gcsfuse

Because [Seafowl](https://seafowl.io/) was architected with the cloud in mind it's a good candidate for serverless/'scale to zero' hosting e.g. Cloud Run and similar.

Database objects can be stored in [S3 buckets](https://seafowl.io/docs/reference/seafowl-toml-configuration#type--s3), which avoids depending on a persistent volume. Meanwhile Seafowl's catalog can be [backed by SQLite](https://seafowl.io/docs/reference/seafowl-toml-configuration#type--sqlite), also good for the scale to zero story because it avoids the usual persistent Postgres process.

Platforms like Lambda and Cloud Run will forward incoming HTTP requests to the waiting Seafowl service, which is the ideal time for it to load the up-to-date SQLite catalog so the request can be handled with fresh data.

By adding [gcsfuse](https://github.com/GoogleCloudPlatform/gcsfuse) to the Seafowl container, the SQLite file is mounted from the bucket into the Seafowl container. While there is a performance penalty in doing so, the catalog is only metadata, not the raw database objects, so the penalty (at least observed so far) is negligible. Plus, so long as traffic is within the same region, GCP doesn't charge for bucket <-> Cloud Run traffic, an additional bonus for hosting costs.

### How to use
Please check out [blog post](https://www.splitgraph.com/blog/deploying-serverless-seafowl) for the step by step details on how to set this up.

In the end you'll have a bucket like this:

<img src="https://github.com/splitgraph/seafowl-gcsfuse/assets/182515/e9c1a8d2-8c5c-4bf8-a217-f78e56ad1300" width="500" />

and some endpoint similar to

`https://seafowl-gcsfuse-YourEndpointHere.a.run.app/q`

you can query from a browser, or your backend.

### Steps
- Build the Docker image (or if you want, use the prebuilt image [splitgraph/seafowl-gcsfuse](https://hub.docker.com/r/splitgraph/seafowl-gcsfuse))
- Make it avaialble to Cloud Run (e.g. push to `hub.docker.com` or your own repo)
- [Deploy](https://www.splitgraph.com/blog/deploying-serverless-seafowl) a new Cloud Run instance using this image, including the secrets
- Test the endpoint using e.g. curl
  ```shell
  curl -i -H "Content-Type: application/json" \
  -X POST "https://your-endpoint-goes-here.a.run.app/q" -d@- <<EOF
  {"query": "
  SELECT now()
  "}
  EOF
  ```

### What's in the repo

This repo provides a [Dockerfile](./Dockerfile) which runs the [gcsfuse_run.sh](./gcsfuse_run.sh) file at init time.

If you want to try separate endpoints for readonly and read/write, two example config files ([read-only](./configs/seafowl-ro.toml) and [write-enabled](./configs/seafowl.toml)) are provided. You could upload them as [secrets](https://cloud.google.com/secret-manager) which lets them be mounted into your Cloud Run instance's filesystem, similarly to FUSE. Or if you prefer to mount these configs some other way, or use env vars to avoid depending on Secret Manager, that's possible too.
