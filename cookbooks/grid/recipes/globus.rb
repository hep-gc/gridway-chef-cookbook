
#TODO: Add logic here for other platforms
dependencies = node[:globus][:redhat][:dependencies]

dependencies.each do |dependency|
  package dependency do
    action :install
  end
end

group node[:globus][:group] do
end

user node[:globus][:user] do
  gid node[:globus][:group]
  home "/home/" + node[:globus][:user]
end

group node[:globus][:grid_user_group] do
end

node[:globus][:grid_users].each do |grid_user|
  user grid_user do
    gid node[:globus][:grid_user_group]
    home "/home/" + grid_user
  end
end

directory "/etc/grid-security" do
  action :create
end

template "/etc/grid-security/grid-mapfile" do
  mode "644"
  source "grid-mapfile.erb" 
  not_if "test -f /etc/grid-security/grid-mapfile"
end

local_tarball = "/tmp/#{node[:globus][:tarball]}"
remote_file local_tarball do
  source node[:globus][:tarball_source]
  checksum = node[:globus][:tarball_checksum]
  mode "0644"
  action :create_if_missing
end

execute "tar" do
  user node[:globus][:user]
  group node[:globus][:group]
  
  installation_dir = "/home/#{node[:globus][:user]}"
  cwd installation_dir
  command "tar xjf #{local_tarball}"
  creates node[:globus][:source_dir]
  action :run
end

directory node[:globus][:location] do
  owner node[:globus][:user]
  group node[:globus][:group]
  mode "755"
  action :create
end

bash "build_globus" do
user node[:globus][:user]
  cwd node[:globus][:source_dir]
  environment({'JAVA_HOME' => "/usr/java/latest/",
               'GLOBUS_LOCATION' => node[:globus][:location],
               'CONFIG_ARGS' => node[:globus][:config_args]})
  code <<-EOH
  ./configure --prefix=$GLOBUS_LOCATION $CONFIG_ARGS
  make
  make install
  EOH
  not_if {File.exists?("#{node[:globus][:location]}/bin/globus-version")}
end

bash "add_globus_to_path" do
  environment({'JAVA_HOME' => "/usr/java/latest/",
               'GLOBUS_LOCATION' => node[:globus][:location]})
  code <<-EOH
  printf "export GLOBUS_LOCATION=$GLOBUS_LOCATION\n" >> /etc/profile
  printf "source $GLOBUS_LOCATION/etc/globus-user-env.sh\n" >> /etc/profile
  printf "export JAVA_HOME=$JAVA_HOME\n" >> /etc/profile
  EOH
  not_if "grep GLOBUS_LOCATION /etc/profile"
end

template "#{node[:globus][:location]}/bin/globus-start-stop" do
  owner node[:globus][:user]
  group node[:globus][:group]
  mode "755"
  source "globus-start-stop.erb"
end

template "/etc/init.d/globus" do
  owner node[:globus][:user]
  group node[:globus][:group]
  mode "755"
  source "globus-init.erb"
end

service "globus" do
   action [:enable]
end

service "xinetd" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
end

# Crappy hack becuase xinetd returns 0 when stopped:
bash "force_start_xinetd" do
  code "service xinetd start"
  not_if "service xinetd status | grep running"
end


template "/etc/xinetd.d/gsiftp" do
  source "gsiftp.erb"
end

bash "enable_gsiftp" do
  code <<-EOH
  printf "\ngsiftp       2811/tcp\n" >> /etc/services
  EOH
  not_if "grep gsiftp /etc/services"
end

service "xinetd" do
  supports :reload => true
  action [:reload]
  not_if "netstat -an | grep 2811"
end


# Start postgresql to init database
service "postgresql" do
  action [:enable, :start]
  not_if "service postgresql status"
end

bash "give_globus_postgres_access" do
  environment({'IPADDRESS' => node[:ipaddress],
               'GLOBUS_USER' => node[:globus][:user],
               'RFT_PASSWORD' => node[:globus][:rft_password]})
  code <<-EOH
  printf "\n" >> /var/lib/pgsql/data/pg_hba.conf
  printf "host rftDatabase \\"$GLOBUS_USER\\" \\"$IPADDRESS\\" 255.255.255.255 md5" >> /var/lib/pgsql/data/pg_hba.conf
  printf "\nlisten_addresses = '$IPADDRESS'\n" >> /var/lib/pgsql/data/postgresql.conf
  su postgres -c "printf '$RFT_PASSWORD\\n$RFT_PASSWORD\\nn\\ny\\nn\\n' | createuser -P globus"
  service postgresql restart
  EOH
  not_if "grep rftDatabase /var/lib/pgsql/data/pg_hba.conf"
end

service "postgresql" do
  action [:restart]
end

bash "setup_rft_db" do
user node[:globus][:user]
  environment({'GLOBUS_USER' => node[:globus][:user],
               'GLOBUS_GROUP' => node[:globus][:group],
               'GLOBUS_LOCATION' => node[:globus][:location]})
  code <<-EOH
  createdb rftDatabase
  psql -d rftDatabase -f $GLOBUS_LOCATION/share/globus_wsrf_rft/rft_schema.sql
  EOH
  not_if "su postgres -c 'psql -l | grep rftDatabase'"
end

bash "set_rft_password" do
user node[:globus][:user]
  environment({'GLOBUS_LOCATION' => node[:globus][:location],
               'RFT_USER' => node[:globus][:user],
               'RFT_PASSWORD' => node[:globus][:rft_password]})
  code <<-EOH
  sed -i s/foo/$RFT_PASSWORD/ $GLOBUS_LOCATION/etc/globus_wsrf_rft/jndi-config.xml
  sed -i s/root/$RFT_USER/ $GLOBUS_LOCATION/etc/globus_wsrf_rft/jndi-config.xml
  EOH
  only_if "grep foo #{node[:globus][:location]}/etc/globus_wsrf_rft/jndi-config.xml"
end

bash "set_sudo_rules" do
  environment({'GLOBUS_USER' => node[:globus][:user],
               'GRID_GROUP' => node[:globus][:grid_user_group],
               'GLOBUS_LOCATION' => node[:globus][:location]})
  code <<-EOH
  printf "\n" >> /etc/sudoers
  printf "$GLOBUS_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GLOBUS_LOCATION/libexec/globus-gridmap-and-execute -g /etc/grid-security/grid-mapfile $GLOBUS_LOCATION/libexec/globus-job-manager-script.pl *\n" >> /etc/sudoers
  printf "$GLOBUS_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GLOBUS_LOCATION/libexec/globus-gridmap-and-execute -g /etc/grid-security/grid-mapfile $GLOBUS_LOCATION/libexec/globus-gram-local-proxy-tool *\n" >> /etc/sudoers
  EOH
  not_if "grep globus-gridmap-and-execute /etc/sudoers"
end

bash "disable_sudo_requiretty" do
  code <<-EOH
  sed -i 's/Defaults.*requiretty//' /etc/sudoers
  EOH
  only_if "grep requiretty /etc/sudoers"
end

bash "add_firewall_rules" do
  code <<-EOH
  iptables -D RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited
  iptables -A RH-Firewall-1-INPUT -p tcp -m state --state NEW -m tcp --dport 8443 -j ACCEPT
  iptables -A RH-Firewall-1-INPUT -p tcp -m state --state NEW -m tcp --dport 2811 -j ACCEPT
  iptables -A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 2119 -j ACCEPT
  iptables -A RH-Firewall-1-INPUT -p tcp -m state --state NEW -m tcp --dport 50000:53199 -j ACCEPT
  iptables -A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited
  service iptables save
  EOH
  not_if "grep 8443 /etc/sysconfig/iptables"
end


local_gc_tarball = "/tmp/#{node[:grid_canada][:tarball]}"
remote_file local_gc_tarball do
  source node[:grid_canada][:tarball_source]
  checksum = node[:grid_canada][:tarball_checksum]
  mode "0644"
  action :create_if_missing
end

bash "install_grid_canada" do
  environment({'JAVA_HOME' => "/usr/java/latest/",
               'GLOBUS_LOCATION' => node[:globus][:location],
               'GC_TARBALL' => local_gc_tarball})
  code <<-EOH
  export GLOBUS_LOCATION
  source $GLOBUS_LOCATION/etc/globus-user-env.sh
  source $GLOBUS_LOCATION/etc/globus-devel-env.sh
  gpt-build $GC_TARBALL
  gpt-postinstall
  $GLOBUS_LOCATION/setup/globus_simple_ca_bffbd7d0_setup/setup-gsi -default
  EOH
  not_if {File.exists?("/etc/grid-security/certificates/bffbd7d0.0")}
end

if not File.exists?("/etc/grid-security/hostcert.pem")
  log "You still need to put your host and container certs in /etc/grid-security"
end
log "Your grid users are: " + node[:globus][:grid_users].join(", ")
