#!/bin/bash
sudo apt-get install -ym bison libasound2-dev

cd ~
wget  http://downloads.sourceforge.net/project/cmusphinx/sphinxbase/0.8/sphinxbase-0.8.tar.gz
tar -xvf sphinxbase-0.8.tar.gz
cd sphinxbase-0.8
./configure
make
sudo make install


cd ~
wget http://sourceforge.net/projects/cmusphinx/files/pocketsphinx/0.8/pocketsphinx-0.8.tar.gz
tar -xvf pocketsphinx-0.8.tar.gz
cd pocketsphinx-0.8
./configure
make
