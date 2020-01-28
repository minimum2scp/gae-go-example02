#! /bin/sh

set -x

app_name=$(basename -s .git $(git config --get remote.origin.url))
app_root=$(realpath $(dirname $0)/..)

project_id=$(gcloud config get-value project)
bucket=staging.${project_id}.appspot.com

version="$1"

if [ "${version}" = "" ]
then
  echo "Usage: $0 version"
  exit 1
fi

tmpdir=$(mktemp -d)
trap "rm -rfv ${tmpdir}" EXIT

go_app_stager=$(gcloud info --format='value(installation.sdk_root)')/platform/google_appengine/go-app-stager
if [ ! -x "${go_app_stager}" ]; then
  echo "go-app-stager not found. Run \"gcloud components install app-engine-go\" to install go-app-stager."
  exit 1
fi

runtime=$(cat runtime)
case "${runtime}" in
  go111)
    go_version=1.11;;
  go112)
    go_version=1.12;;
  go113)
    go_version=1.13;;
  *)
    echo "Unknown runtime ${runtime} in app.yaml, abort."
    exit 1
    ;;
esac

# create temporary app.yaml
echo "runtime: ${runtime}" > ${app_root}/app.yaml

# copy files into temporary directory using go-app-stager
${go_app_stager} -go-version=${go_version} ${app_root}/app.yaml ${app_root} ${tmpdir}

# upload files to Cloud Storage and generate manifest
cd ${tmpdir}
files=$(gcloud meta list-files-for-upload | sort)
for f in ${files}; do
  gsutil cp ${f} gs://${bucket}/${app_name}/${version}/${f}
done
sha1sum ${files} > _manifest
gsutil cp _manifest gs://${bucket}/${app_name}/${version}/_manifest

# list uploaded objects and show manifest
gsutil ls -l -r gs://${bucket}/${app_name}/${version}/
gsutil cat gs://${bucket}/${app_name}/${version}/_manifest

