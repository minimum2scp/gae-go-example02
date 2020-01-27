#! /bin/sh

set -x

app_name=$(basename -s .git $(git config --get remote.origin.url))

project_id=$(gcloud config get-value project)
bucket=staging.${project_id}.appspot.com
version=$1

if [ "${version}" = "" ]; then
  echo "Usage: $0 version"
  exit 1
fi

# create temporary directory
tmpdir=$(mktemp -d)
trap "rm -rfv ${tmpdir}" EXIT
cp runtime ${tmpdir}/runtime
cd ${tmpdir}

# download manifest file from cloud storage
manifest=gs://${bucket}/${app_name}/${version}/_manifest
gsutil cp ${manifest} _manifest

# create app.json (app.yaml)
# https://cloud.google.com/appengine/docs/standard/go111/config/appref?hl=en
ruby -ryaml -rjson -e '
  runtime = File.read("runtime").strip
  manifest = File.readlines("_manifest")
  bucket = ARGV.shift
  app_name = ARGV.shift
  version = ARGV.shift
  conf = {}
  conf["runtime"] = runtime
  conf["id"] = Time.now.strftime("%Y%m%dt%H%M%S")
  conf["deployment"] = {
    "files" => manifest.map{|line| line.split }.map{|(sha1sum, filename)|
      [
        filename,
        {
          "sourceUrl" => "https://storage.googleapis.com/#{bucket}/#{app_name}/#{version}/#{filename}",
          "sha1Sum" => sha1sum,
        }
      ]
    }.to_h
  }
  puts JSON.pretty_generate(conf)
' ${bucket} ${app_name} ${version} | tee app.json

# create version
access_token=$(gcloud auth print-access-token)
service=${app_name}
curl -X POST \
     -T "app.json" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${access_token}" \
     https://appengine.googleapis.com/v1/apps/${project_id}/services/${service}/versions

