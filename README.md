# XLT-Packer
Packer files to build cloud machine images for Xceptance LoadTest.

Currently you can find skripts for the following cloud vendors:
 - DigitalOcean
 - Amazon EC2
 - Google Compute Engine
 
NOTE: Please note that this is not for cloud managing, but only for image creation.
 
## Preparation

The installation routines are based on packer.io, so you'll need to download it from [here](https://packer.io/downloads.html).

## Create an Image

To create images you need to build the according .json file for your cloud vendor by calling packer. E.g. to create a new EC2 AMI, you would run:

`$ <PATH_TO_PACKER>/packer build packer/amazon.json`

## Confiuration 

Before you create an image, you need to provide some additional information, like the authentification for your vendor.
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
 - the name of the AMI (default is: XLT-Image-TIMESTAMP)
 - your AWS secret key
 - your AWS acces key
 - the name of a ssh key-pair stored in your AWS account 
 - the path to the according private key file
 - the base AMI on which the XLT should be build
 
NOTE: The XLT images are based on Ubuntu 14.04 (trusty), so using another base OS (even another Ubuntu) may not work. We preconfigured AMIs for all regions in the `packer/amazon_allRegions.json` file. You can also find a list of base images [here](https://cloud-images.ubuntu.com/locator/ec2/).
 
Please be reminded, that the AMI names need to apply to naming rules: AMI names must be between 3 and 128 characters long, and may contain letters, numbers, '(', ')', '.', '-', '/' and '_'

Also note, that you need to allow your instances to use port 8500 to connect to the agent controllers. You can do this by adding an adapted security group when launching an instance.

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
 - your google copmute account file (How to get this see [here](https://www.packer.io/docs/builders/googlecompute.html)
 - your google project ID
 
Please be reminded, that the image names need to apply to naming rules: must start with an lower case letter, and only have hyphens, numbers and lower letters. In Other words it must be a match of regex `(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)`

Also note, that you need to allow your instances to use port 8500 to connect to the agent controllers. You can do this by adding a firewall rule to a network at your network settings at: https://console.developers.google.com/project/<YOUR_PROJECT>/networks/list
 
### All Region Files

Packer allows parallel image creation, which give a significant speedup if you need to create more than one image. So if you need to create images in multiple regions use the `_allRegions.json` files.

You can also use a subset of the provided regions by whitelisting or excluding some regions:

`$ <PATH_TO_PACKER>/packer build -except=us-east-1 packer/amazon_allRegions.json`
`$ <PATH_TO_PACKER>/packer build -only=us-east-1,us-west-1 packer/amazon_allRegions.json`

Of course you also need to pass the vendor and region specific variables, which can be found on top of each `.json` file.