
set[:globus][:redhat][:dependencies] = ["gcc", "gcc-c++", "libstdc++-devel", "ant", "ant-apache-regexp", "ant-trax", "ant-nodeps", "postgresql-server", "xinetd", "xml-commons-apis", "perl-XML-Parser"]
set[:globus][:user] = "globus"
set[:globus][:group] = "globus"
set[:globus][:source_dir] = "/home/#{globus[:user]}/gt4.0.8-all-source-installer"
set[:globus][:tarball] = "gt4.0.8-all-source-installer.tar.bz2"
set[:globus][:tarball_source] = "http://www-unix.globus.org/ftppub/gt4/4.0/4.0.8/installers/src/#{globus[:tarball]}"
set[:globus][:tarball_checksum] = "d304ac45bd6f2be4fa3f7f7f5d561e782d716d9b7c84bb23b95c3856b7d3bca4"
set[:globus][:location] = "/usr/local/globus-4.0.8"
set[:globus][:config_args] = "--disable-wstests --disable-tests --disable-rendezvous --disable-rls --disable-drs"
set[:globus][:rft_password] = "globus"
set[:globus][:grid_users] = ["griduser0", "griduser1", "griduser2", "griduser3"]
set[:globus][:grid_user_group] = "grid"

set[:grid_canada][:tarball] = "globus_simple_ca_bffbd7d0_setup-0.18.tar.gz"
set[:grid_canada][:tarball_source] = "http://www.gridcanada.ca/ca/#{grid_canada[:tarball]}"
set[:grid_canada][:tarball_checksum] = "d304ac45bd6f2be4fa3f7f7f5d561e782d716d9b7c84bb23b95c3856b7d3bca4"

set[:gridway][:source_dir] = "/home/#{globus[:user]}/oldpatricka-Gridway-7d45b01"
set[:gridway][:tarball] = "oldpatricka-Gridway-7d45b01.tar.gz"
set[:gridway][:tarball_source] = "https://download.github.com/oldpatricka-Gridway-7d45b01.tar.gz"
set[:gridway][:tarball_checksum] = "d304ac45bd6f2be4fa3f7f7f5d561e782d716d9b7c84bb23b95c3856b7d3bca4"
set[:gridway][:location] = "/usr/local/gridway"
set[:gridway][:config_args] = "--enable-prews"
