#! /bin/bash

set -eo pipefail

app_name=$(basename -s .git $(git config --get remote.origin.url))
app_root=$(git rev-parse --show-toplevel)
project_id=$(gcloud config get-value project)

bucket=$1
version=$2

if [ "${bucket}" = "" -o "${version}" = "" ]; then
  echo "Usage: $0 bucket version"
  exit 1
fi

gcs_version_path=gs://${bucket}/${app_name}/${version}

echo ">>> app_name: ${app_name}"
echo ">>> app_root: ${app_root}"
echo ">>> project_id: ${project_id}"
echo ">>> bucket: ${bucket}"
echo ">>> version: ${version}"
echo ">>> gcs_version_path: ${gcs_version_path}"

# create temporary directory and clean up on exit
tmpdir=$(mktemp -d)
trap "echo '>>> Cleanup'; rm -rfv ${tmpdir}" EXIT
echo ">>> tmpdir: ${tmpdir}"

cd ${tmpdir}

# copy file(s) to temporary directory
echo ">>> Copy file(s) to tmpdir"
echo ">>> * ${app_root}/runtime -> ${tmpdir}/runtime"
cp ${app_root}/runtime ${tmpdir}/runtime

# download manifest file from cloud storage
echo ">>> Download manifest file from cloud storage"
echo ">>> * ${gcs_version_path}/_manifest -> ${tmpdir}/_manifest"
gsutil -q cp ${gcs_version_path}/_manifest ${tmpdir}/_manifest

# create app.json (app.yaml)
# https://cloud.google.com/appengine/docs/standard/go111/config/appref?hl=en
echo ">>> Create app.json from _manifest"
ruby -rjson -e '
  bucket = ARGV.shift
  app_name = ARGV.shift
  version = ARGV.shift

  runtime = File.read("runtime").strip
  manifest = File.read("_manifest").strip

  fileinfo = manifest.split("\n").each_with_object({}) do |l, o|
    sha1sum, path = l.split(/\s+/, 2)
    o[path] = {
      "sourceUrl" => "https://storage.googleapis.com/#{bucket}/#{app_name}/#{version}/#{path}",
      "sha1Sum" => sha1sum
    }
  end

  app = {
    "runtime"    => runtime,
    "id"         => Time.now.strftime("%Y%m%dt%H%M%S"),
    "deployment" => {
      "files" => fileinfo
    }
  }

  puts JSON.pretty_generate(app)
' ${bucket} ${app_name} ${version} | tee app.json

# create version
echo ">>> Create version by AppEngine Admin API"
access_token=$(gcloud auth print-access-token)
service=${app_name}
curl -X POST \
     -T "app.json" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${access_token}" \
     https://appengine.googleapis.com/v1/apps/${project_id}/services/${service}/versions

