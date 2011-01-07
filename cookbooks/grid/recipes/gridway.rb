
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
               'GW_LOCATION' => node[:gridway][:location],
               'CONFIG_ARGS' => node[:gridway][:config_args]})
  code <<-EOH
  export GW_LOCATION
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

bash "add_sudo_rules" do
  environment({'GLOBUS_LOCATION' => node[:globus][:location],
               'GW_LOCATION' => node[:gridway][:location],
               'GW_USER' => node[:globus][:user],
               'GRID_GROUP' => node[:globus][:grid_user_group]})
  code <<-EOH
  printf "\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_em_mad_prews *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_em_mad_ws *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_em_mad_ftp *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GW_LOCATION/bin/gw_em_mad_dummy *\n" >> /etc/sudoers
  printf "$GW_USER ALL=(%%$GRID_GROUP) NOPASSWD: $GLOBUS_LOCATION/bin/grid-proxy-info *\n" >> /etc/sudoers
  EOH
  not_if "grep gw_em /etc/sudoers"
end
