#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "ruby"
default_version "2.1.3"

dependency "zlib"
dependency "ncurses"
dependency "libedit"
dependency "openssl"
dependency "libyaml"
dependency "libiconv"
dependency "libffi"
dependency "gdbm" #if (platform == "mac_os_x" or platform == "freebsd" or platform == "aix")
dependency "libgcc" if (platform == "solaris2" and Omnibus.config.solaris_compiler == "gcc")

version "1.9.3-p484" do
  source :url => "http://cache.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p484.tar.gz",
         :md5 => '8ac0dee72fe12d75c8b2d0ef5d0c2968'
end

version "1.9.3-p545" do
  source :url => "http://cache.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p545.tar.gz",
         :md5 => '8e8f6e4d7d0bb54e0edf8d9c4120f40c'
end

version "2.1.3" do
  source :url => "http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.3.tar.gz",
         :md5 => '74a37b9ad90e4ea63c0eed32b9d5b18f'
end

relative_path "ruby-#{version}"

env =
  case platform
  when "mac_os_x"
    {
      "CFLAGS" => "-arch x86_64 -m64 -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include -I#{install_dir}/embedded/include/ncurses -O3 -g -pipe",
      "LDFLAGS" => "-arch x86_64 -R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include -I#{install_dir}/embedded/include/ncurses"
    }
  when "solaris2"
    if Omnibus.config.solaris_compiler == "studio"
    {
      "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
    }
    elsif Omnibus.config.solaris_compiler == "gcc"
    {
      "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include -O3 -g -pipe",
      "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include -static-libgcc",
      "LD_OPTIONS" => "-R#{install_dir}/embedded/lib"
    }
    else
      raise "Sorry, #{Omnibus.config.solaris_compiler} is not a valid compiler selection."
    end
  when "aix"
    {
      # see http://www.ibm.com/developerworks/aix/library/au-gnu.html
      #
      # specifically:
      #
      # "To use AIX run-time linking, you should create the shared object
      # using gcc -shared -Wl,-G and create executables using the library
      # by adding the -Wl,-brtl option to the link line. Technically, you
      # can leave off the -shared option, but it does no harm and reduces
      # confusion."
      #
      # AIX also uses -Wl,-blibpath instead of -R or LD_RUN_PATH, but the
      # option is not additive, so requires /usr/lib and /lib as well (there
      # is a -bsvr4 option to allow ld to take an -R flag in addition
      # to turning on -brtl, but it had other side effects I couldn't fix).
      #
      # If libraries linked with gcc -shared have symbol resolution failures
      # then it may be useful to add -bexpfull to export all symbols.
      #
      # -O2 optimized away some configure test which caused ext libs to fail
      #
      # We also need prezl's M4 instead of picking up /usr/bin/m4 which
      # barfs on ruby.
      #
      "CC" => "xlc -q64",
      "CXX" => "xlC -q64",
      "LD" => "ld -b64",
      "CFLAGS" => "-q64 -O -qhot -I#{install_dir}/embedded/include",
      "CXXFLAGS" => "-q64 -O -qhot -I#{install_dir}/embedded/include",
      "LDFLAGS" => "-q64  -L#{install_dir}/embedded/lib -Wl,-brtl -Wl,-blibpath:#{install_dir}/embedded/lib:/usr/lib:/lib",
      "OBJECT_MODE" => "64",
      "ARFLAGS" => "-X64 cru",
      "M4" => "/opt/freeware/bin/m4",
      "warnflags" => "-qinfo=por"
    }
  else
    {
      "CFLAGS" => "-I#{install_dir}/embedded/include -O3 -g -pipe",
      "LDFLAGS" => "-Wl,-rpath,#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib"
    }
  end

build do
  configure_command = ["./configure",
                       "--prefix=#{install_dir}/embedded",
                       "--enable-shared",
                       "--enable-libedit",
                       "--with-ext=psych",
                       "--disable-install-doc",
                       "--without-gmp",
                       "--with-out-ext=dbm"]

  case platform
  when "aix"
    patch :source => "ruby-aix-configure.patch", :plevel => 1
    patch :source => "ruby_aix_1_9_3_448_ssl_EAGAIN.patch", :plevel => 1
    # --with-opt-dir causes ruby to send bogus commands to the AIX linker
  when "freebsd"
    configure_command << "--without-execinfo"
    configure_command << "--with-opt-dir=#{install_dir}/embedded"
  when "smartos"
    # Opscode patch - someara@opscode.com
    # GCC 4.7.0 chokes on mismatched function types between OpenSSL 1.0.1c and Ruby 1.9.3-p286
    patch :source => "ruby-openssl-1.0.1c.patch", :plevel => 1

    # Patches taken from RVM.
    # http://bugs.ruby-lang.org/issues/5384
    # https://www.illumos.org/issues/1587
    # https://github.com/wayneeseguin/rvm/issues/719
    patch :source => "rvm-cflags.patch", :plevel => 1

    # From RVM forum
    # https://github.com/wayneeseguin/rvm/commit/86766534fcc26f4582f23842a4d3789707ce6b96
    configure_command << "ac_cv_func_dl_iterate_phdr=no"
    configure_command << "--with-opt-dir=#{install_dir}/embedded"
  else
    configure_command << "--with-opt-dir=#{install_dir}/embedded"
  end

  # @todo expose bundle_bust() in the DSL
  env.merge!({
    "RUBYOPT"         => nil,
    "BUNDLE_BIN_PATH" => nil,
    "BUNDLE_GEMFILE"  => nil,
    "GEM_PATH"        => nil,
    "GEM_HOME"        => nil
  })

  # @todo: move into omnibus-ruby
  has_gmake = system("gmake --version")

  if has_gmake
    env.merge!({'MAKE' => 'gmake'})
    make_binary = 'gmake'
  else
    make_binary = 'make'
  end

  command configure_command.join(" "), :env => env
  command "#{make_binary} -j #{max_build_jobs}", :env => env
  command "#{make_binary} -j #{max_build_jobs} install", :env => env
end
