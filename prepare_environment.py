#!/usr/bin/python

import yum
import subprocess
import os

def install_packages():
  to_install = ['java-1.8.0-openjdk']
  yum_communicate = yum.YumBase()
  installed = [package.name for package in yum_communicate.rpmdb.returnPackages()]

  for package in to_install:
    if package in installed:
      print('{0} is already installed'.format(package))
    else:
      print('Installing {0}'.format(package))
      kwarg = { 'name':package }
      yum_communicate.install(**kwarg)
      yum_communicate.resolveDeps()
      yum_communicate.buildTransaction()
      yum_communicate.processTransaction()

def exec_shell(command):
  return os.popen(command).read().strip('\n')


#Set java homedir in bash_profile
homeDir = exec_shell('echo $HOME')
profileFile = homeDir + '/.bash_profile'
javaHome = os.readlink('/etc/alternatives/java')
javaVar = 'export JAVA_HOME = \'' + javaHome + '\'\n'
isvar='0'
with open(profileFile, "a+") as bashpr:
  for line in bashpr:
    if javaVar in line:
      isvar = '1'
  if isvar == '0':
    bashpr.write(javaVar)




install_packages()
print 'Dont forget to:\nsource ~/.bash_profile'
