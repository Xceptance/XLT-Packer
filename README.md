# XLT Packer #

Build cloud machine images running [Xceptance LoadTest](https://xceptance.com/xlt) with ease using [Packer](https://packer.io).

Up to now, you can find scripts for the following cloud vendors or platforms:

- Amazon
- DigitalOcean
- Google
- Hetzner
- Docker

All XLT images are based on **Debian 11 (bullseye)**, so using another base OS (even another Debian version) may not work.

During image creation, the following main packages will be installed:

- Chromium
- Chromedriver
- Firefox ESR
- Geckodriver
- JDK 11
- XLT

Furthermore, the following optimizations will be applied to the underlying OS to allow for high-scale and resource-efficient load testing:

- increased OS limit of number of open files
- enlarged range of local ports per IP
- enabled reuse of sockets that are in timed-waiting state

Note that these optimizations are not done for Docker as they would actually have to be applied to the OS of the host machine.

When running an instance with one of these images later on, the XLT agent controller and also an SSH server (except Docker) are started automatcially. Ensure that the following ports are opened in the firewall settings of your instance:

- 8500 for the XLT agent controller (required)
- 22 for the SSH server (optional)

Please consult the documentation of your cloud vendor for details on how to do that.

When you want to log in via SSH, use `admin` as the user name. This is the default user in Debian.


## Preparation ##

Most of the work (and magic) is done by an open-source tool named [Packer](https://packer.io) built by HashiCorp. So you will need to [download and install](https://packer.io/downloads.html) it first. Note that Packer v1.6.0 or later is required.


## Create an Image ##

Now that you have installed packer, you can use it to build XLT images for any supported cloud vendor listed above. To do so, invoke packer with the `build` command followed by the JSON file that corresponds to your cloud vendor.

For example, to create a new Amazon EC2 AMI, you would run:

```sh
$ <PATH_TO_PACKER>/packer build packer/amazon.json
```

## Configuration ##

Before you create an image, you need to provide some additional information, such as the authentication data for your cloud vendor.

This can be done in several ways:

1. Edit the respective JSON file (e.g. _packer/digitalOcean.json_) and fill out the missing values.
1. Provide the missing information on the command line by invoking Packer with the `-var` flag: `-var 'variable_name=value'`.
1. Put all your variable definitions in a separate JSON file and pass it to Packer with the `-var-file` flag: `-var-file=myVars.json` (recommended).

Imagine you want to create an Amazon EC2 image running XLT *6.2.5* for region *eu-central-1*. This is done by invoking Packer as follows:

```sh
$ <PATH_TO_PACKER>/packer build -var 'region=eu-central-1' -var 'xlt_version=6.2.5' packer/amazon.json
```

You can also put all variables you need into a file, let's say *variables.json*:

```json
{
  "region": "eu-central-1",
  "xlt_version": "6.2.5"
}
```

This file could then be passed to Packer like this:

```sh
$ packer build -var-file=variables.json packer/amazon.json
```

All templates require you to pass/edit the following configuration parameters:

- the region/zone you want the new image to be built in
- the XLT version that should run in your new image
- the name of the new image

Besides those, there are several additional parameters specific to the cloud vendor of your choice. Please see below for details.


### Amazon EC2 Configuration ###

To create an **A**mazon **M**achine **I**mage you'll need to pass:

- **region** *(required)*: the region you want the new image to be built in
- **xlt_version** *(required)*: the XLT version that should run in your new image
- **root_volume_size** *(optional)*: the size of the root volume (defaults to 200 GB)
- **image_name** *(required)*: the name of the AMI (defaults to *XLT-Image-&lt;TIMESTAMP&gt;*)
- **launch_permission** *(optional)*: who can launch your image (defaults to private access)
- **aws_access_key** *(required)*: your AWS access key
- **aws_secret_key** *(required)*: your AWS secret key
- **ssh_keypair_name** *(optional)*: the name of an SSH key-pair stored in your AWS account (if empty, a temporary key-pair is used)
- **ssh_private_key_file** *(optional)*: the path to the corresponding private key file (if empty, a temporary key-pair is used)

We also offer a template to build and publish an AMI for _multiple regions at once_: `packer/amazon_allRegions.json`. The image will be built in the region specified by the variable `region` and is then copied to the regions specified by the variable `dest_regions`.

- **dest_regions** *(required)*: a comma-separated list of target region names

Please be reminded that AMI names must obey the following rules:

- at least 3 characters
- at most 128 characters
- only letters, numbers, '(', ')', '.', '-', '/' and '_' are allowed

Example variables file:

```json
{
  "region": "eu-central-1",
  "xlt_version": "6.2.5",
  "root_volume_size": "10",
  "launch_permission": "public",
  "aws_access_key": "<YOUR_ACCESS_KEY>",
  "aws_secret_key": "<YOUR_SECRET_KEY>"
}
```

Also note that you need to allow incoming network traffic on TCP port *8500* for all of your instances so that you can connect to the agent controllers.
You can do this by adding an appropriate security group when launching the instance(s).


### DigitalOcean Configuration ###

To create a DigitalOcean image you'll need to pass:

- **region** *(required)*: the region you want the new image to be built in
- **xlt_version** *(required)*: the XLT version that should run in your new image
- **image_name** *(optional)*: the name of new image (defaults to *XLT-Image-&lt;TIMESTAMP&gt;*)
- **api_token** *(required)*: your DigitalOcean API token

In case you want to build an image for multiple regions at once, you can use the template `packer/digitalOcean_allRegions.json`.

Example variables file:

```json
{
  "region": "nyc1",
  "xlt_version": "6.2.5",
  "api_token": "<YOUR_API_TOKEN>"
}
```


### Google Compute Engine Configuration ###

To create a **G**oogle **C**ompute **E**ngine image you'll need to pass:

- **zone** *(required)*: the zone you want the new image to be built in
- **account_file** *(required)*: your Google Compute account file (instructions on how to get this can be found [here](https://www.packer.io/docs/builders/googlecompute.html))
- **project** *(required)*: your Google project ID
- **xlt_version** *(required)*: the XLT version that should run in your new image
- **image_version** *(required)*: the version displayed in the image name, produces images named `xlt-{image_version}-{timestamp}`
- **image_family** *(required)*: the family displayed in image family tags, produces image family tags named `xlt-{image_family}`

Please be reminded that image version and family must obey the following rules:

- must start with a lower-case letter
- only numbers, lower-case letters and '-' are allowed.

Example variables file:

```json
{
  "zone": "us-central1-a",
  "account_file": "<PATH_TO_YOUR_ACCOUNT_JSON_FILE>",
  "project": "<YOUR_PROJECT_ID>",
  "xlt_version": "6.2.5",
  "image_version": "6-2-5",
  "image_family": "6-x"
}
```

Also note that you need to allow incoming network traffic on TCP port *8500* for all of your instances so that you can connect to the agent controllers.
You can do this by adding an appropriate firewall rule in your network settings at: `https://console.developers.google.com/project/<YOUR_PROJECT_ID>/networks/list`


### Hetzner Cloud Configuration ###

To create a Hetzner image you can pass the following variables to packer:

- **location** *(optional)*: The location where the image build server is started
- **api_token** *(required)*: Your Hetzner Cloud API token. Create one for your project at `https://console.hetzner.cloud/projects/<YOUR_PROJECT_ID>/security/tokens`
- **xlt_version** *(required)*: The XLT version to create the image for
- **image_version** *(required)*: The version displayed in the image name, produces images named `xlt-{image_version}-{timestamp}`
- **label_xlt_version** *(required)*: Set the label `xlt-version` to the given value

Example variables file:

```json
{
  "location": "nbg1",
  "api_token": "<YOUR_API_TOKEN>",
  "xlt_version": "6.2.5",
  "image_version": "6-2-5",
  "label_xlt_version": "6-x"
}
```

Also note that you should create firewall rules when creating servers with this XLT Hetzner image to allow incoming network traffic on TCP port *8500* for all of your instances so that you can connect to the agent controllers.
You can do this by adding an appropriate firewall rule in your network settings at: `https://console.hetzner.cloud/projects/<YOUR_PROJECT_ID>/firewalls`


### Docker Configuration ###

When creating a Docker image you'll need to pass:

- **xlt_version** *(required)*: the XLT version that should run in your new image
- **image_repository** *(required)*: the repository to store the docker image to
- **image_tags** *(optional)*: the tags to apply to the docker image as a comma-separated list (defaults to `xlt_version`)
- **registry_url** *(optional)*: the URL of the docker image registry to which the image is to be pushed (defaults to empty which means Docker Hub)
- **registry_username** *(required)*: the username to use when logging into the registry
- **registry_password** *(required)*: the password to use when logging into the registry

Example variables file:

```json
{
  "xlt_version": "6.2.5",
  "image_repository": "<YOUR_ORG>/xlt",
  "image_tags": "6.2.5,greatest",
  "registry_url": "",
  "registry_username": "<YOUR_USER_NAME>",
  "registry_password": "<YOUR_PASSWORD>"
}
```
