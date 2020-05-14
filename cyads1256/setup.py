from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

setup(
  name = 'lowlevel',
  ext_modules = cythonize([Extension("lowlevel", ["lowlevel.pyx"], libraries=['bcm2835'])])
)
