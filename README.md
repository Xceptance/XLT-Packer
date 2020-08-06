# XLT-Packer #

Build cloud machine images running [Xceptance LoadTest](https://xceptance.com/xlt) with ease using [Packer](https://packer.io).

Up to now, you can find scripts for the following cloud vendors or platforms:
 - DigitalOcean
 - Amazon EC2
 - Google Compute Engine
 - Docker

NOTE: Please note that this is not for cloud managing, but only for image creation.

All XLT images are based on Ubuntu 18.04 (bionic), so using another base OS (even another Ubuntu) may not work.

## Preparation ##

Most of the work (and magic) is done by an open-source tool named [Packer](https://packer.io) built by HashiCorp. So, you will need to [download and install](https://packer.io/downloads.html) it first.

## Create an Image ##

Now that you have installed packer, you can use it to build XLT images for any supported cloud vendor listed above.
To do so, invoke packer with the `build` command followed by the JSON file that corresponds to your cloud vendor.

For example, to create a new Amazon EC2 AMI, you would run:

```sh
  $ <PATH_TO_PACKER>/packer build packer/amazon.json
```

## Configuration ##

Before you create an image, you need to provide some additional information, such as the authentication data for your clould vendor.

This can be done in several ways:

  1. Edit the respective json file (e.g. _packer/digitalOcean.json_) and fill out the missing values.
  1. Provide the missing information on the command line by invoking Packer with the `-var` flag: `-var 'variable_name=value'`.
  1. Last but not least, you can also put all your variable definitions in a separate JSON file and pass it to Packer with the `-var-file` flag: `-var-file=myVars.json`

Lets take a look at the following sample: Imagine, you want to create an Amazon EC2 image running XLT _4.9.1_ for region _eu-central-1_ (all variables are in italics).
This is done by invoking Packer as follows:

```sh
  $ <PATH_TO_PACKER>/packer build -var 'region=eu-central-1' -var 'xlt_version=4.9.1' packer/amazon.json
```

You can also put all variables you need into a file, let's say _variables.json_:

```json
  {
    "region": "eu-central-1",
    "xlt_version": "4.9.1"
  }
```

This file could then be passed to Packer like this:

```sh
  $ packer build -var-file=variables.json packer/amazon.json
```


All templates require you to pass/edit the following configuration parameters:
 - the region/zone you want the new image to be built in
 - the XLT version that should run in your new image (defaults to _LATEST_)
 - the name of new image

Besides those, there are several additional parameters specific to the cloud vendor of your choice. Please see below for details.

### Amazon EC2 Configuration ###

To create an **A**mazon **M**achine **I**mage you'll need to pass:
 - the region you want the new image to be built in
 - the XLT version that should run in your new image (defaults to _LATEST_)
 - the name of the AMI (defaults to _XLT-Image-&lt;TIMESTAMP&gt;_)
 - your AWS secret key
 - your AWS access key
 - the name of a ssh key-pair stored in your AWS account
 - the path to the corresponding private key file

We also offer a template to build and publish an AMI for _multiple regions at once_: `packer/amazon_allRegions.json`.
The image will then be built in the region specified by the variable `region` and is then copied to the regions specified by the key `ami_regions` in the builder configuration.

Please be reminded that AMI names must obey the following rules:
 - at least 3 characters
 - at most 128 characters
 - only letters, numbers, '(', ')', '.', '-', '/' and '_' are allowed

Also note, that you need to allow incoming network traffic on TCP port *8500* for all of your instances so that you can connect to the agent controllers.
You can do this by adding an appropriate security group when launching the instance(s).

### DigitalOcean Configuration ###

To create a DigitalOcean image you'll need to pass:
 - the region you want the new image to be built in
 - the XLT version that should run in your new image (defaults to _LATEST_)
 - the name of new image (defaults to _XLT-Image-&lt;TIMESTAMP&gt;_)
 - your DigitalOcean API token

In case you want to build an image for multiple regions at once, you can use the template `packer/digitalOcean_allRegions.json`.

### Google Compute Engine Configuration ###

To create a **G**oogle **C**ompute **E**ngine image you'll need to pass:
 - the zone you want the new image to be built in
 - the XLT version that should run in your new image (defaults to _LATEST_)
 - the name of the new image (defaults to _xlt-&lt;XLT_VERSION&gt;-&lt;YYMMDD&gt;_)
 - your Google Compute account file (Instructions on how to get this can be found [here](https://www.packer.io/docs/builders/googlecompute.html))
 - your Google project ID

Please be reminded that image names must obey the following rules:
 - must start with a lower-case letter
 - only numbers, lower-case letters and '-' are allowed.

Also note, that you need to allow incoming network traffic on TCP port *8500* for all of your instances so that you can connect to the agent controllers.
You can do this by adding an appropriate firewall rule in your network settings at: `https://console.developers.google.com/project/<YOUR_PROJECT>/networks/list`


### Docker Configuration ###

When creating a Docker image you'll need to pass:

 - the XLT version that should run in your new image
 - the repository to store the docker image to
 - the tags to apply to the docker image (as a comma-separated list)
 - the URL of the docker image registry to which the image is to be pushed (defaults to docker.io if empty)
 - the username to use when logging into the registry
 - the password to use when logging into the registry

See below for a corresponding variables file template:

```json
  {
    "xlt_version": "5.1.2",
    "image_repository": "myorganization/xlt",
    "image_tags": "5.1.2,greatest",
    "registry_url": "https://docker.io/",
    "registry_username": "myusername",
    "registry_password": "mypassword"
  }
```

## XLT at Full Throttle ##

The following optimizations have been applied to the underlying OS to allow for high-scale and resource-efficient load-testing:
 - increased OS limit of number of open files
 - enlarged range of local ports per IP
 - enabled reuse of sockets that are in timed-waiting state

Note that these optimizations are not effective when using the Docker image as they would actually have to be applied to the OS of the host machine.