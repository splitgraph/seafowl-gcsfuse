### Scale to zero Seafowl via gcsfuse

[Seafowl](https://seafowl.io/) was architected with the cloud in mind, and is a good candidate for 'scale to zero' hosting like Cloud Run and similar.

Seafowl's database objects can be stored in [S3 buckets](https://seafowl.io/docs/reference/seafowl-toml-configuration#type--s3), which lets us avoid depending on a persistent volume. Meanwhile, Seafowl's catalog can be [backed by SQLite](https://seafowl.io/docs/reference/seafowl-toml-configuration#type--sqlite), which is also good for the scale to zero story, since it lets us avoid the usual persistent Postgres process.

Cloud Run will forward incoming HTTP requests to our waiting Seafowl service, which is the ideal time for it to load the up-to-date SQLite catalog so the request can be handled with fresh data.

By adding [gcsfuse](https://github.com/GoogleCloudPlatform/gcsfuse) to the Seafowl container, we can map the S3 bucket containing SQLite into the Seafowl container. While there is a performance penalty in doing so, the catalog is only metadata, not the raw database objects, so the penalty (at least observed so far) is negligible. Plus, so long as traffic is within the same region, GCP doesn't charge for bucket to Cloud Run traffic which is an additional bonus for our hosting costs.

### How to use
This repo provides a [Dockerfile](./Dockerfile) which runs the [gcsfuse_run.sh](./gcsfuse_run.sh) file at init time. You shouldn't have to edit these files. 

There are two example config files ([read-only](./configs/seafowl-ro.toml) and [write-enabled](./configs/seafowl.toml)) that you _should_ customize with your own values. You could upload them as [secrets](https://cloud.google.com/secret-manager) which lets them be mounted into your Cloud Run instance's filesystem, similarly to FUSE. (If you prefer to mount these configs some other way to avoid depending on Secret Manager, that's OK too.)

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
