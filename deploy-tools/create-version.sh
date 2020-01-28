#! /bin/bash

set -x
set -eo pipefail

app_name=$(basename -s .git $(git config --get remote.origin.url))
project_id=$(gcloud config get-value project)

bucket=$1
version=$2

if [ "${bucket}" = "" -o "${version}" = "" ]; then
  echo "Usage: $0 bucket version"
  exit 1
fi

# create temporary directory and clean up on exit
tmpdir=$(mktemp -d)
trap "rm -rfv ${tmpdir}" EXIT

# copy file(s) to temporary directory
cp runtime ${tmpdir}/runtime

# download manifest file from cloud storage
cd ${tmpdir}
manifest=gs://${bucket}/${app_name}/${version}/_manifest
gsutil -q cp ${manifest} _manifest

cat _manifest

# create app.json (app.yaml)
# https://cloud.google.com/appengine/docs/standard/go111/config/appref?hl=en
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
access_token=$(gcloud auth print-access-token)
service=${app_name}
curl -X POST \
     -T "app.json" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${access_token}" \
     https://appengine.googleapis.com/v1/apps/${project_id}/services/${service}/versions

