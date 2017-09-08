# XLT-Packer
Packer files to build cloud machine images for [Xceptance LoadTest](https://xceptance.com/xlt).

Currently you can find scripts for the following cloud vendors:
 - DigitalOcean
 - Amazon EC2
 - Google Compute Engine

NOTE: Please note that this is not for cloud managing, but only for image creation.

## Preparation

The installation routines are based on packer.io, so you'll need to download it from [here](https://packer.io/downloads.html).

## Create an Image

Now that you have installed packer, you can use it to build XLT images for any supported Cloud vendor listed above.
To do so, invoke packer with the `build` command followed by the JSON file that corresponds to your cloud vendor.

For example, to create a new Amazon EC2 AMI, you would run:

```sh
  $ <PATH_TO_PACKER>/packer build packer/amazon.json
```

## Configuration 

Before you create an image, you need to provide some additional information, such as the authentication data for your clould vendor.

This can be done in several ways:

  1. Edit the respective json file (e.g. the packer/digitalOcean.json) and fill out the missing values.
  1. Provide the missing information on the command line by invoking Packer with the `-var` flag: `-var 'variable_name=value'`.
  3. Last but not least, you can also put all your variable definitions in a JSON file and pass it to Packer with the `-var-file` flag: `-var-file=myVars.json`

Lets take a look at the following sample: Imagine, you want to create an Amazon EC2 image running XLT _4.9.1_ for region _eu-central-1_ (all variables are in italics).
This is done by invoking Packer as follows:

```sh
  $ <PATH_TO_PACKER>/packer build -var 'region=eu-central-1' -var 'xlt-version=4.9.1' packer/amazon.json
```

You can also put all variables you need into a file, let's say _variables.json_:

```json
  {
    "region": "eu-central-1",
    "xlt-version": "4.9.1"
  }
```

This file could then be passed to Packer like this:

```sh
  $ packer build -var-file=variables.json packer/amazon.json
```

### Amazon EC2 Configuration

To create an **A**mazon **M**achine **I**mage you'll need to pass:
 - the region you want the image to be available in
 - the XLT version you want to use (default is: LATEST)
 - the name of the AMI (default is: XLT-Image-TIMESTAMP)
 - your AWS secret key
 - your AWS access key
 - the name of a ssh key-pair stored in your AWS account
 - the path to the corresponding private key file
 - the base image on which the new XLT image should be build

NOTE: The XLT images are based on Ubuntu 16.04 (xenial), so using another base OS (even another Ubuntu) may not work. We preconfigured AMIs for all regions in the `packer/amazon_allRegions.json` file. You can also find a list of base images [here](https://cloud-images.ubuntu.com/locator/ec2/).

Please be reminded that AMI names must obey the following rules:
 - at least 3 characters
 - at most 128 characters
 - only letters, numbers, '(', ')', '.', '-', '/' and '_' are allowed

Also note, that you need to allow incoming network traffic on TCP port *8500* for all of your instances so that you can connect to the agent controllers.
You can do this by adding an appropriate security group when launching the instance(s).

### DigitalOcean Configuration

To create a DigitalOcean image you'll need to pass:
 - the region you want to create the image
 - the XLT version you want to use (default is: LATEST)
 - the name of the image (default is: XLT-Image-TIMESTAMP)
 - your DigitalOcean API token

### Google Compute Engine Configuration

To create a GCE image you'll need to pass:
 - the region you want to create the image
 - the XLT version you want to use (default is: LATEST)
 - the name of the image (default is: xlt-image-TIMESTAMP)
 - your Google Compute account file (How to get this see [here](https://www.packer.io/docs/builders/googlecompute.html))
 - your Google project ID

Please be reminded that the image names must obey the following rules:
 - must start with a lower-case letter
 - only numbers, lower-case letters and '-' are allowed.

Also note, that you need to allow incoming network traffic on TCP port *8500* for all of your instances so that you can connect to the agent controllers.
You can do this by adding an appropriate firewall rule in your network settings at: `https://console.developers.google.com/project/<YOUR_PROJECT>/networks/list`

### All Region Files

Packer allows parallel image creation which give a significant speedup if you need to create more than one image. So, if you need to create images in multiple regions use the `_allRegions.json` files.

You can also use a subset of the provided regions by whitelisting

```sh
  $ <PATH_TO_PACKER>/packer build -only=us-east-1,us-west-1 packer/amazon_allRegions.json
```

or excluding one or more regions:

```sh
$ <PATH_TO_PACKER>/packer build -except=us-east-1 packer/amazon_allRegions.json
```

Of course you also need to pass the vendor and region specific variables, which can be found on top of each `.json` file.
