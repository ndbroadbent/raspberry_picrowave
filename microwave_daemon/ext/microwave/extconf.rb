# Loads mkmf which is used to make makefiles for Ruby extensions
require 'mkmf'

dir_config('microwave/microwave')
have_library('wiringPi')
create_makefile('microwave/microwave')
