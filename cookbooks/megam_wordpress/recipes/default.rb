#
# Cookbook Name:: wordpress
# Recipe:: default
#
# Copyright 2009-2010, Opscode, Inc.
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
include_recipe "apt"
include_recipe "php"



rsyslog_inputs=[]
rsyslog_inputs = node.default['rsyslog']['logs']
rsyslog_inputs.push("/var/log/apache2/access.log", "/var/log/apache2/error.log", "/var/log/megam/megamgulpd/megamgulpd.log")
node.override['rsyslog']['logs']= rsyslog_inputs

node.set['heka']['logs']["#{node['megam']['deps']['component']['name']}"] = ["/var/log/apache2/access.log", "/var/log/apache2/error.log", "/var/log/megam/megamgulpd/megamgulpd.log"]


scm_ext = File.extname(node['megam']['deps']['scm'])
file_name = File.basename(node['megam']['deps']['scm'])
dir = File.basename(file_name, '.*')
if scm_ext.empty?
  scm_ext = ".git"
end
node.set["gulp"]["project_name"] = "#{dir}"
node.set["gulp"]["email"] = "#{node['megam']['deps']['account']['email']}"
node.set["gulp"]["api_key"] = "#{node['megam']['deps']['account']['api_key']}"

node.set['megam']['env']['home'] = "#{node['megam']['user']['home']}/#{dir}"
include_recipe "megam_environment"



# On Windows PHP comes with the MySQL Module and we use IIS on Windows
unless platform? "windows"
  include_recipe "php::module_mysql"
  include_recipe "apache2"
  include_recipe "apache2::mod_php5"
end

include_recipe "megam_wordpress::database"

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
node.set_unless['wordpress']['keys']['auth'] = secure_password
node.set_unless['wordpress']['keys']['secure_auth'] = secure_password
node.set_unless['wordpress']['keys']['logged_in'] = secure_password
node.set_unless['wordpress']['keys']['nonce'] = secure_password
node.set_unless['wordpress']['salt']['auth'] = secure_password
node.set_unless['wordpress']['salt']['secure_auth'] = secure_password
node.set_unless['wordpress']['salt']['logged_in'] = secure_password
node.set_unless['wordpress']['salt']['nonce'] = secure_password
node.save unless Chef::Config[:solo]

directory node['wordpress']['dir'] do
  action :create
  if platform_family?('windows')
    rights :read, 'Everyone'
  else
    owner 'root'
    group 'root'
    mode  '00755'
  end
end

archive = platform_family?('windows') ? 'wordpress.zip' : 'wordpress.tar.gz'

if platform_family?('windows')
  windows_zipfile node['wordpress']['parent_dir'] do
    source node['wordpress']['url']
    action :unzip
    not_if {::File.exists?("#{node['wordpress']['dir']}\\index.php")}
  end
else
  remote_file "#{Chef::Config[:file_cache_path]}/#{archive}" do
    source node['wordpress']['url']
    action :create
  end

  execute "extract-wordpress" do
    command "tar xf #{Chef::Config[:file_cache_path]}/#{archive} -C #{node['wordpress']['dir']}"
    creates "#{node['wordpress']['dir']}/index.php"
  end
end

template "#{node['wordpress']['dir']}/wp-config.php" do
  source 'wp-config.php.erb'
  variables(
    :db_name          => node['wordpress']['db']['name'],
    :db_user          => node['wordpress']['db']['user'],
    :db_password      => node['wordpress']['db']['pass'],
    :db_host          => node['wordpress']['db']['host'],
    :auth_key         => node['wordpress']['keys']['auth'],
    :secure_auth_key  => node['wordpress']['keys']['secure_auth'],
    :logged_in_key    => node['wordpress']['keys']['logged_in'],
    :nonce_key        => node['wordpress']['keys']['nonce'],
    :auth_salt        => node['wordpress']['salt']['auth'],
    :secure_auth_salt => node['wordpress']['salt']['secure_auth'],
    :logged_in_salt   => node['wordpress']['salt']['logged_in'],
    :nonce_salt       => node['wordpress']['salt']['nonce'],
    :lang             => node['wordpress']['languages']['lang']
  )
  action :create
end

if platform?('windows')

  include_recipe 'iis::remove_default_site'

  iis_pool 'WordpressPool' do
    runtime_version "2.0" # TODO: Change to Unmanaged after COOK-3634 is merged
    action :add
  end

  iis_site 'Wordpress' do
    protocol :http
    port 80
    path node['wordpress']['dir']
    application_pool 'WordpressPool'
    action [:add,:start]
  end
else
  web_app "wordpress" do
    template "wordpress.conf.erb"
    docroot node['wordpress']['dir']
    server_name node['fqdn']
    server_aliases node['wordpress']['server_aliases']
    enable true
  end
end

bash "Apache log permissions change" do
cwd "/var/log/"
  user "root"
  group "root"
   code <<-EOH
  chown -R root:root apache2
  chmod 755 apache2
  EOH
end

