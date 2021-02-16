module.exports = {
    uploadUrlFile :  uploadUrlFile
}

function uploadUrlFile (data){
  data = JSON.parse(data);
  const storage = require("@google-cloud/storage");
  const fs = require("fs");
  const gcs = storage({
    projectId: data.project_id,
    keyFilename: data.key_file_name
  });
  return gcs.bucket(data.bucket_name).upload(data.file, {
    gzip: true,
    destination: data.destination
  }).then((r) => {
    const options = {
      action: 'read',
      expires: Date.now() + 1000 * 60 * data.expires,
    };
    const file = gcs.bucket(data.bucket_name).file(data.destination);
    return file.getSignedUrl(options).then(url => {
      return {"url": url[0]}
    })
  })
}
