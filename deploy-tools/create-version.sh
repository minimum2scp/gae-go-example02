#! /bin/sh

set -x

app_name=$(basename $(git rev-parse --show-toplevel))
app_root=$(realpath $(dirname $0)/..)
app_yaml=${app_root}/app.yaml

project_id=$(gcloud config get-value project)
bucket=staging.${project_id}.appspot.com
version=$1

if [ "${version}" = "" ]; then
  echo "Usage: $0 version"
  exit 1
fi

# create temporary directory and copy app.yaml, download manifest file from cloud storage
tmpdir=$(mktemp -d)
trap "rm -rfv ${tmpdir}" EXIT
cd ${tmpdir}
cp -a ${app_yaml} ${tmpdir}
manifest=gs://${bucket}/${app_name}/${version}/_manifest
gsutil cp ${manifest} _manifest

# convert app.yaml to app.json
ruby -ryaml -rjson -e '
  conf = YAML.load(File.read(ARGV[0]))
  manifest = File.readlines(ARGV[1])
  bucket = ARGV[2]
  app_name = ARGV[3]
  version = ARGV[4]
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
  service = conf.delete("service")
  File.open("app.json", "w"){|fh|
    fh.puts JSON.pretty_generate(conf)
  }
  File.open("service.txt", "w"){|fh|
    fh.puts service
  }
' app.yaml _manifest ${bucket} ${app_name} ${version}

cat app.json
cat service.txt

# create version
access_token=$(gcloud auth print-access-token)
service=$(cat service.txt)
curl -X POST \
     -T "app.json" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${access_token}" \
     https://appengine.googleapis.com/v1/apps/${project_id}/services/${service}/versions

