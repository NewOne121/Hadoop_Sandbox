#!/usr/bin/python

import yum
import subprocess
import os
import sys
import urllib
import tarfile
import argparse

parser=argparse.ArgumentParser()
parser.add_argument('--role', action='store', help='Node role. Valid roles are: namenode, resource-manager, datanode')
args=parser.parse_args()

if not args.role:
  parser.print_help(sys.stderr)
  sys.exit(1)

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


#Shell communicator
def exec_shell(command):
  return os.popen(command).read().strip('\n')

homeDir = exec_shell('echo $HOME')
bashProfile = homeDir + '/.bash_profile'
etcProfile = '/etc/profile'
javaHome = os.readlink('/etc/alternatives/java')
javaVar = 'export JAVA_HOME=\'' + javaHome + '\'\n'
bashrcVar = 'source ' + homeDir + '/.bashrc'

def setjava():
  with open(bashProfile, "a+") as bashpr:
    bashpr.write(javaVar)
    print 'Java home has been set.'

#Check if JAVA_HOME is already set
isvar='0'
files = [ bashProfile, etcProfile ]
for file in files:
  with open(file, 'r') as bashfile:
    for line in bashfile:
      if javaVar in line:
        isvar = '1'
        print 'JAVA_HOME already set'

def getHadoop():
  global destinationFile
  global hadoopVersion
  hadoopVersion = '3.1.2'
  packageUrl = 'http://apache-mirror.rbc.ru/pub/apache/hadoop/common/hadoop-' + hadoopVersion + '/hadoop-' + hadoopVersion + '.tar.gz'
  destinationFile = '/tmp/hadoop' + hadoopVersion + '.tar.gz'
  url_comm = urllib.URLopener()
  url_comm.retrieve(packageUrl, destinationFile)

def extractHadoop():
  tar = tarfile.open(destinationFile)
  tar.extractall(path='/opt')
  tar.close()

def deployHadoopConfig(role): #from args
  hadoopConfDir = '/opt/hadoop-' + hadoopVersion + '/etc/hadoop'
  commConfDir = './config/common/'
  roleConfDir = './config/' + role + '/'
  for item in commConfDir,roleConfDir:
    for root, dirs, files in os.walk(item):
      if 'hosts' in files:
        files.remove('hosts')
        HadoopConf = files
    for conf in HadoopConf:
      subprocess.Popen(['cp', commConfDir + conf, hadoopConfDir])
  subprocess.Popen(['cp', './config/common/hosts', '/etc/hosts'])
    

install_packages()
if isvar == '0': setjava()
getHadoop()
extractHadoop()
deployHadoopConfig(args.role)

print 'Dont forget to:\nsource ~/.bash_profile'
