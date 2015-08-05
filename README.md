# XLT-Packer
Packer files to build cloud machine images for Xceptance LoadTest.

Currently you can find skriptsfor the following cloud vendors:
 - DigitalOcean
 - Amazon EC2
 
NOTE: Please note that this is not for cloud managing, but only for image creation.
 
## Preparation

The installation routines are based on packer.io, so you'll need to download it from [here](https://packer.io/downloads.html).

## Create an Image

To create an image you have to build the provided .json file by calling packer. E.g. to create a new EC2 AMI, you would run:

`$ <PATH_TO_PACKER>/packer build packer/amazon.json`

## Confiuration 

To create images you need to build the according .json file for your cloud vendor. To do so, you'll need to provide some additional information, like the authentification for your vendor.
You could either edit the according json file (e.g. the packer/digitalOcean.json) and fill out the missing values or you could provide the information in the commandline by passing `-var 'variable_name=value'`. So e.g. to pass XLT version 4.5.2 to your EC2 AMI and set the region to eu-central-1 you would run:

`$ <PATH_TO_PACKER>/packer build -var 'region=eu-central-1' -var 'xlt-version=4.5.2' packer/amazon.json`

You can also put all variables you need into a file, let's say variables.json:

`{
  "aws_access_key": "foo",
  "aws_secret_key": "bar"
}`

This file could be passed to a build like this:

`$ packer build -var-file=variables.json packer/amazon.json`
 

### Amazon EC-2 Configuration

To create a AWS EC-2 AMI you'll need to pass:
 - the region yo want to create the image
 - the XLT version you want to use (default is: LATEST)
 - the name of the AMI (default is: XLT-Image-<TIMESTAMP>)
 - your AWS secret key
 - your AWS acces key
 - the name of a ssh key-pair stored in your AWS account 
 - the path to the according private key file
 - the base AMI on which the XLT should be build
 
NOTE: The XLT images are based on Ubuntu 14.04 (trusty), so using another base OS (even another Ubuntu) may not work. We preconfigured AMIs for all regions in the `packer/amazon_allRegions.json` file. You can also find a list of base images [here](https://cloud-images.ubuntu.com/locator/ec2/).
 
Please be remindet, that the AMI names have some special think of clean AMI names: AMI names must be between 3 and 128 characters long, and may contain letters, numbers, '(', ')', '.', '-', '/' and '_'


### DigitalOcean Configuration

To create a DigitalOcean image you'll need to pass:
 - the region you want to create the image
 - the XLT version you want to use (default is: LATEST)
 - the name of the AMI (default is: XLT-Image-<TIMESTAMP>)
 - your DigitalOcean API token
 
### All Region Files

Packer allows parallel image creation, which give a significant speedup if you need to create more than one image. So if you need to create images in multiple regions use the `_allRegions.json` files.

You can also use a subset of the provided regions by whitelisting or excluding some regions:

`$ <PATH_TO_PACKER>/packer build -except=us-east-1 packer/amazon_allRegions.json`
`$ <PATH_TO_PACKER>/packer build -only=us-east-1,us-west-1 packer/amazon_allRegions.json`

Of course you also need to pass the region vendor and region specific variables, which can be found on top of each `.json` file.