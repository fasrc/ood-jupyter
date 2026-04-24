# Open OnDemand Jupyter notebook / Jupyterlab 
<!-- Describe the app from a user's perspective. This is a simplied version of Overview -->
## FASRC users

Jupyter notebook / Jupyterlab is an Open OnDemand app that launches Jupyter notebook or Jupyterlab  as an interactive session on a compute node. 
 
It is designed for researchers who need a web-based interactive development environment for notebooks, code, and data. Its flexible interface allows users to configure and arrange workflows in data science, scientific computing, computational journalism, and machine learning.

<!-- Link any relevant FASRC docs -->
<!-- ### Using [app name] -->

<!-- Link how to create Sandbox -->
### Sandbox app

For how to create a Sandbox app, see the [Developing your own app using Open
OnDemand](https://docs.rc.fas.harvard.edu/kb/developing-apps-on-ood/)
documentation.

## Appverse overview

> [!NOTE]  
> This section is intended for sys-admins, developers, and power users.

Jupyter notebook / Jupyterlab is an Open OnDemand app that launches Jupyter notebook or Jupyterlab  as an interactive session on  HPC clusters. 
 
It is designed for researchers who need a web-based interactive development environment for notebooks, code, and data. Its flexible interface allows users to configure and arrange workflows in data science, scientific computing, computational journalism, and machine learning.

## Prerequisites
This Batch Connect app requires the following software be available on **compute nodes** :

- [Jupyter Notebook](http://jupyter.readthedocs.io/en/latest/) This is installed in the central location as part of Anaconda installation,

It is assumed jupyterlab, notebook and nb_conda_kernels have been installed on the host in a Python virtual environment, e.g.:

```
# python3.12 -mvenv /n/sw/jupyterlab/jupyterlab-4.5.0
# . /n/sw/jupyterlab/jupyterlab-4.5.0
(jupyterlab-4.5.0) # pip install --no-cache-dir jupyterlab==4.5.0 notebook==7.5.0 git+https://github.com/anaconda/nb_conda_kernels@2.5.2
```

The CONDA_EXE environment varible must be set to the path of a conda executable in template/script.sh.erb.
nb_conda_kernels will use the conda executable directly to search for additional kernels installed in the users' conda environments, but otherwise the conda environment containing the conda executable will not be used.

## Install

The master branch of this repo is automatically deployed by puppet to /var/www/ood/apps/sys/ on the ondemand nodes.

If you want to deploy that in your user development environment to make modifications, follow these instructions. 

```sh
# create the development folder if you still not have one
mkdir -pv ~/fasrc/dev/
cd ~/fasrc/dev/

# clone the repository in a subfolder for your version of the app
git clone git@gitlab-int.rc.fas.harvard.edu:openondemand/jupyter-app.git my_jupyter

# Change the working directory to this new directory
cd my_jupyter
```
You can now make your preferred modifications and run your version of the app from the sandbox control panel under the
*dev* menu on the ondemand dashboard

## Contributing

If you intend deploy your modified version as system wide app, you should commit your changes to a branch first.
Please remember that any modification to the master branch goes live **immediately**. 
