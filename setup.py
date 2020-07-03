from setuptools import setup, find_namespace_packages
from distutils.extension import Extension
from Cython.Build import cythonize

setup(
  name = 'cyADS1256',
  version = '0.3.0',
  package_dir = {"": "src"},
  dependencies = ["cython"],
  install_requires = ["asgiref"],
  packages=find_namespace_packages(where="src"),
  ext_modules = cythonize([Extension("_bcm2835", ["src/cyads1256/_bcm2835.pyx"], libraries=['bcm2835', 'cap'])])
)
