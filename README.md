# Open.HD-Image-Builder
Short version: This project takes a Raspbian-lite base image and modifies it into a Open.HD compatible image.
For the long version, read on.

## Using
In order to be able to run this you need a Debian or Ubuntu Linux machine with 30 Gb free space on the main partition, and with the following packages:

```
sudo apt-get install unzip curl git qemu qemu-user-static binfmt-support build-essential gcc-arm*
```

Then git clone this repository to a suitable folder 

```
git clone https://github.com/HD-Fpv/Open.HD_Image_Builder.git
cd Open.HD_Image_Builder
```

and run:

```
sudo -s
./build.sh
```


## More information (what's going on?)
The earlier version of this builder did all of the work from a single script, while that is basically fine, there were some issues with the approach taken:

- After every modification, the entire process needed to be re-run. (Which takes ~2 hours on a decent machine)
- It was hard for new users to find the different steps and where to make additions

The main issue offcourse being the first one.
So, on to this, the new and improved 'staged' image builder.

### STAGES
The core concept (and some code) was taken from [pi-gen](https://github.com/RPi-Distro/pi-gen), the Raspbian image generator.
Whenever we make a OpenHd image, we basically perform several steps in order:

- Download the Raspbian lite image
- Increase the size of the partition
- Download, patch and compile the Linux kernel
- Update the image with the patched kernel
- Update the image with several apt-get packages
- Copy the OpenHD code onto the image and compile
- Copy several configuration files
- Cleanup

*Remember, this was all done in a single script, and an error in the cleanup step basically meant running it all again.*

So after thinking about the problem and looking for projects who had tackled this i looked at the actual Raspbian image generator, who's output serves as our input (the basic Raspbian lite image). The concept used in the Raspbian image generator is dividing the entire creation process in `stages`, where the output of the previous stage serves as the input of the next. Stages that have been completed can be skipped in a next build.

This concept applies to the OpenHD image creation as well. So i modified the core logic into this system:

![flow](https://github.com/HD-Fpv/Open.HD_Image_Builder/raw/master/Builder%20flow.png "Flow")

This allows us to run the build process once, and when we want to make a change in stage 3, we only run stage 3 and 4 again by removing the `SKIP` file from the `stages/03-Packages` and the `stages/04-Wifibroadcast` folders. The build system will copy the kernel `IMAGE.img` from stage 2 to stage 3 and re-run all the scripts in stage 3. The resulting image is copied to stage 4 and all those scripts are run. Finally, when there are no more stages, the `IMAGE.img` from the last stage is copied to the `deploy/ezwfb-{date}.img` file.

#### Skipping
By placing a `SKIP` file in the stage folder, the entire stage will be skipped by the build system. Please be aware there is no sanity check in place, removing the `SKIP` file from stage 3 while leaving the `SKIP` file in stage 4 will produce an image based on the previous run, ignoring the modifications done in step 3.

It is also possible to put a `SKIP-IMAGE` file into a stage, this will disable any attempt to copy the image from the previous stage. This is mainly used to prevent image copying in stage `00` and `01` where no image is yet available.

#### Scripts
Every stage comprises one or more scripts. Scripts need to be named in the format `XX-run.sh` or `XX-run-chroot.sh`. The order is determined by the XX part, where any `-chroot` script is run **AFTER** the non-chroot script.

**chroot**? What's that? Well, it's a little complex, but basically it allows you to run statements within the image as if you were running the image on an actual Raspberry Pi. This is used to download and install the `apt-get` packages and several scripts to make the image ready for use with the OpenHD system. Please remember to use `sudo` in the `-chroot` scripts where approperiate.

#### Branches
You can define which Open.HD branch gets pulled from the script repo. define `OPENHD_BRANCH=` in config
