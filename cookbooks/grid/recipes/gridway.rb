
local_tarball = "/tmp/#{node[:gridway][:tarball]}"
remote_file local_tarball do
  source node[:gridway][:tarball_source]
  checksum = node[:gridway][:tarball_checksum]
  mode "0644"
  action :create_if_missing
end

execute "tar" do
  user node[:globus][:user]
  group node[:globus][:group]
  
  installation_dir = "/home/#{node[:globus][:user]}"
  cwd installation_dir
  command "tar xzf #{local_tarball}"
  creates node[:gridway][:source_dir]
  action :run
end

directory node[:gridway][:location] do
  owner node[:globus][:user]
  group node[:globus][:group]
  mode "755"
  action :create
end

bash "build_gridway" do
user node[:globus][:user]
  cwd node[:gridway][:source_dir]
  environment({'JAVA_HOME' => "/usr/java/latest/",
               'GLOBUS_LOCATION' => node[:globus][:location],
               'GW_LOCATION' => node[:gridway][:location],
               'CONFIG_ARGS' => node[:gridway][:config_args]})
  code <<-EOH
  export GW_LOCATION
  export GLOBUS_LOCATION
  . $GLOBUS_LOCATION/etc/globus-devel-env.sh
  env
  ./configure --prefix=$GW_LOCATION $CONFIG_ARGS
  make
  make install
  EOH
  not_if {File.exists?("#{node[:gridway][:location]}/bin/gwps")}
end

bash "add_gridway_to_path" do
  environment({'JAVA_HOME' => "/usr/java/latest/",
               'GW_LOCATION' => node[:gridway][:location]})
  code <<-EOH
  printf "export GW_LOCATION=$GW_LOCATION\n" >> /etc/profile
  printf "export PATH=\\$PATH:\\$GW_LOCATION/bin/\n" >> /etc/profile
  EOH
  not_if "grep GW_LOCATION /etc/profile"
end

ggw_tarball = "/tmp/#{node[:gridgateway][:tarball]}"
remote_file ggw_tarball do
  source node[:gridgateway][:tarball_source]
  checksum = node[:gridgateway][:tarball_checksum]
  mode "0644"
  action :create_if_missing
end

execute "tar" do
  user node[:globus][:user]
  group node[:globus][:group]
  
  installation_dir = "/home/#{node[:globus][:user]}"
  cwd installation_dir
  command "tar xzf #{ggw_tarball}"
  creates node[:gridgateway][:source_dir]
  action :run
end

bash "build_gridgateway" do
user node[:globus][:user]
  cwd node[:gridgateway][:source_dir] + "/components"
  environment({'JAVA_HOME' => "/usr/java/latest/",
               'GLOBUS_LOCATION' => node[:globus][:location],
               'GW_LOCATION' => node[:gridway][:location]})
  code <<-EOH
  export GW_LOCATION
  export GLOBUS_LOCATION
  . $GLOBUS_LOCATION/etc/globus-devel-env.sh
  gpt-build -force gcc32dbg globus_gram_job_manager_setup_gw.tar.gz globus_scheduler_event_generator_gw.tar.gz globus_scheduler_provider_setup_gw.tar.gz globus_wsrf_gram_service_java_setup.tar.gz
  gpt-postinstall -force
  EOH
  #not_if {File.exists?("#{node[:gridway][:location]}/bin/gwps")}
end

template node[:gridway][:location] + "/etc/gwd.conf" do
  mode "644"
  source "gwd.conf.erb"
end

template node[:gridway][:location] + "/etc/example.com.attr" do
  mode "644"
  source "example.com.attr.erb"
end

template node[:gridway][:location] + "/etc/host.list" do
  mode "644"
  source "host.list.erb"
end

template node[:gridway][:location] + "/etc/wshost.list" do
  mode "644"
  source "host.list.erb"
end

bash "add_sudo_rules" do
  environment({'GLOBUS_LOCATION' => node[:globus][:location],
               'GW_LOCATION' => node[:gridway][:location],
               'GW_USER' => node[:globus][:user],
               'GRID_GROUP' => node[:globus][:grid_user_group]})
  code <<-EOH
  printf "\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_em_mad_prews *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_em_mad_ws *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_tm_mad_ftp *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_em_mad_dummy *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GLOBUS_LOCATION/bin/grid-proxy-info *\n" >> /etc/sudoers
  printf 'Defaults>%%$GRID_GROUP env_keep=\"GW_LOCATION GLOBUS_LOCATION GLOBUS_TCP_PORT_RANGE X509_USER_PROXY X509_USER_KEY X509_USER_CERT\" >> /etc/sudoers 
  EOH
  not_if "grep gw_em /etc/sudoers"
end
