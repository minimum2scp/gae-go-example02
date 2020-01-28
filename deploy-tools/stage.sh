#! /bin/bash

set -x
set -eo pipefail

app_name=$(basename -s .git $(git config --get remote.origin.url))
app_root=$(git rev-parse --show-toplevel)
project_id=$(gcloud config get-value project)

bucket="$1"
version="$2"

if [ -z "${bucket}" -o -z "${version}" ]; then
  echo "Usage: $0 bucket version"
  exit 1
fi

# create temporary directory and clean up on exit
tmpdir=$(mktemp -d)
stagedir=$tmpdir/stage
mkdir $stagedir
trap "rm -rfv ${tmpdir}" EXIT

# check if go-app-stager is installed
go_app_stager=$(gcloud info --format='value(installation.sdk_root)')/platform/google_appengine/go-app-stager
if [ ! -x "${go_app_stager}" ]; then
  echo "go-app-stager not found. Run \"gcloud components install app-engine-go\" to install go-app-stager."
  exit 1
fi

# create app.yaml in temporary directory
runtime=$(cat runtime)
echo "runtime: ${runtime}" > ${tmpdir}/app.yaml

# "goNNN" -> "N.NN"
go_version=${runtime#go}
go_version=${go_version::1}.${go_version:1}

# copy files into stage directory using go-app-stager
${go_app_stager} -go-version=${go_version} ${tmpdir}/app.yaml ${app_root} ${stagedir}

# upload files to Cloud Storage and generate manifest
cd ${stagedir}
gcloud meta list-files-for-upload | sort | tee ${tmpdir}/files-for-upload
cat ${tmpdir}/files-for-upload | while read f; do
  gsutil -q cp ${f} gs://${bucket}/${app_name}/${version}/${f}
done

# upload manifest
sha1sum $(cat ${tmpdir}/files-for-upload) | tee ${tmpdir}/_manifest
gsutil -q cp ${tmpdir}/_manifest gs://${bucket}/${app_name}/${version}/_manifest

# list uploaded objects and show manifest
gsutil ls -l -r gs://${bucket}/${app_name}/${version}/
gsutil cat gs://${bucket}/${app_name}/${version}/_manifest

