### Scale to zero Seafowl via gcsfuse

[Seafowl](https://seafowl.io/) was architected with the cloud in mind, and is a good candidate for 'scale to zero' hosting like Cloud Run and similar.

Seafowl's database objects can be stored in [S3 buckets](https://seafowl.io/docs/reference/seafowl-toml-configuration#type--s3), which lets us avoid depending on a persistent volume.
Meanwhile, Seafowl's catalog can be [backed by SQLite](https://seafowl.io/docs/reference/seafowl-toml-configuration#type--sqlite), which is also good for the scale to zero story, since it lets us avoid the usual persistent Postgres process.

Cloud Run will forward incoming HTTP requests to our waiting Seafowl service, which is the ideal time for it to load the up-to-date SQLite catalog so the request can be handled with fresh data.

By adding [gcsfuse](https://github.com/GoogleCloudPlatform/gcsfuse) to the Seafowl container, we can map the S3 bucket containing SQLite available to Seafowl. While there is a performance penalty, the catalog is only metadata, not the raw database objects, so the penalty (so far) is negligible. Plus, so long as traffic is within the same region, GCP doesn't charge for bucket to Cloud Run traffic, which is an additional bonus for our hosting costs.

### How to use
This repo provides a [Dockerfile](./Dockerfile) which runs the [gcsfuse_run.sh](./gcsfuse_run.sh) file at init time. You shouldn't have to edit these files. 

There are also two example config files ([read-only](./configs/seafowl-ro.toml) and [write-enabled](./configs/seafowl.toml)) that you _should_ customize with your own values. Ideally you upload them as [secrets](https://cloud.google.com/secret-manager) which lets them be mounted into your Cloud Run instance. (Though if you prefer to mount these configs some other way to avoid depending on Secret Manager, that's OK too.)

### Steps
- build the Docker image
- store it somewhere accessible to Cloud Run (e.g. hub.docker.com or your own repo)
- [Deploy](#deploy) a new Cloud Run instance using this image
- Deploy the [secrets](#secrets)
- Test the endpoint using e.g.
  ```shell
  curl -i -H "Content-Type: application/json" \
  -X POST "https://your-endpoint-goes-here.a.run.app/q" -d@- <<EOF
  {"query": "
  SELECT now()
  "}
  EOF
  ```

### Create a GCS bucket for DataFusion storage

`gsutil mb -l us-east1 gs://seafowl-gcsfuse`

### Generate [object_store]'s' access_key_id and secret_access_key

`gsutil hmac create seafowl-gcsfuse-identity@seafowl-gcsfuse.iam.gserviceaccount.com`
Access ID: GOOG...
Secret: hwl...

### Enable the Secret Manager API (might be necessary)

`gcloud services enable secretmanager.googleapis.com`

### Create the seafowl.toml file as a Secret
<a name="#secrets"></a>
Because we are separating read + write, we need to create two secrets for each endpoint.

```
gcloud secrets create seafowl_toml --data-file=seafowl.toml
Created version [1] of the secret [seafowl_toml].
```

```
gcloud secrets create seafowl-ro_toml --data-file=seafowl-ro.toml
Created version [1] of the secret [seafowl-ro_toml].
```

### Create a dedicated service account

`gcloud iam service-accounts create seafowl-gcsfuse-identity`

### Add policy bindings for both Object Storage + Secret access

```
gcloud projects add-iam-policy-binding seafowl-gcsfuse \
 --member "serviceAccount:seafowl-gcsfuse-identity@seafowl-gcsfuse.iam.gserviceaccount.com" \
 --role "roles/storage.objectAdmin"
```


### Deploy to Cloud Run
<a name="#deploy"></a>

#### Write-enabled instance (deploy 1)
```shell
gcloud run deploy seafowl-gcsfuse \
 --image pskinner/seafowl-gcsfuse \
 --execution-environment gen2 \
 --allow-unauthenticated \
 --service-account seafowl-gcsfuse-identity \
 --update-secrets=/app/config/seafowl.toml=projects/<projectID>/secrets/seafowl_toml:latest \
 --update-env-vars BUCKET=seafowl-gcsfuse
```

#### Read-only instance (deploy as many as you like)
gcloud run deploy seafowl-gcsfuse-ro \
 --image pskinner/seafowl-gcsfuse \
 --execution-environment gen2 \
 --allow-unauthenticated \
 --service-account seafowl-gcsfuse-identity \
 --update-secrets=/app/config/seafowl.toml=projects/<projectID>/secrets/seafowl-ro_toml:latest \
 --update-env-vars BUCKET=seafowl-gcsfuse \
 --update-env-vars RUN_SEAFOWL_READ_ONLY=true