# lz-test-stand

#### Checkout the GIT reposotiry from github 
$ git clone --recursive git@github.com:slaclab/lz-test-stand

# How to load the driver
```
# Clone the repo
$ git clone --recursive git@github.com:slaclab/aes-stream-drivers

# Check out the dev branch (currently a pull request)
$ cd axi-pcie-dev
$ git checkout kcu1500-dev

# Make the source code
$ cd data_dev/driver/
$ make

# Copy my load script 
cp ~ruckman/projects/aes-stream-drivers/data_dev/driver/load .

# Run my load script 
$ sudo ./load

# Check if driver was loaded
$ cat /proc/datadev_0
```
