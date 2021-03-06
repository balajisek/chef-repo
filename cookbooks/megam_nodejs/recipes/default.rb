#
# Author:: Marius Ducea (marius@promethost.com)
# Cookbook Name:: nodejs
# Recipe:: default
#
# Copyright 2010-2012, Promet Solutions
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

#include_recipe 'megam_nodejs::nodejs'


rsyslog_inputs=[]
rsyslog_inputs = node.default['rsyslog']['logs']
rsyslog_inputs.push("/var/log/upstart/nodejs.log", "/var/log/megam/megamgulpd/megamgulpd.log")
node.override['rsyslog']['logs']= rsyslog_inputs

node.set['heka']['logs']["#{node['megam']['deps']['component']['name']}"] = ["/var/log/upstart/nodejs.log", "/var/log/megam/megamgulpd/megamgulpd.log"]



#node.set['megam']['nginx']['port'] = "2368"

include_recipe "git"

scm_ext = File.extname(node['megam']['deps']['scm'])
file_name = File.basename(node['megam']['deps']['scm'])
dir = File.basename(file_name, '.*')
if scm_ext.empty?
  scm_ext = ".git"
end



=begin
execute "Clone Nodejs builder" do
cwd "#{node['megam']['user']['home']}/bin"
  user "root"
  group "root"
  command "git clone https://github.com/megamsys/megam_nodejs_builder.git"
end
=end

case scm_ext
when ".git"

execute "Clone git " do
  cwd node['megam']['user']['home']
  command "git clone #{node['megam']['deps']['scm']}"
end

execute "Change mod cloned git" do
  cwd node['megam']['user']['home']
  command "chown -R #{node['megam']['default']['user']}:#{node['megam']['default']['user']} #{dir}"
end


else
	puts "TEST CASE ELSE"
end #CASE


execute "chmod 755 #{node['megam']['user']['home']}/#{dir}/start"

execute "sudo -s"

execute "npm Install dependencies" do
  cwd "#{node['megam']['user']['home']}/#{dir}" 
  command "npm install --production"
  user "root"
  group "root"
  retries 1
  ignore_failure true
end

execute "npm Install dependencies" do
  cwd "#{node['megam']['user']['home']}/#{dir}" 
  command "npm install"
  user "root"
  group "root"
  retries 1
  ignore_failure true
end

#==================================================================================
#GHOST NEED THESE
#npm install merge-descriptors finalhandler content-disposition depd send etag proxy-addr qs media-typer debug path-to-regexp methods utils-merge parseurl accepts type-is fresh range-parser escape-html on-finished cookie-signature cookie vary serve-static inherits mime generic-pool-redux backbone trigger-then create-error simple-extend inflection 





# use upstart when supported to get nice things like automatic respawns
use_upstart = false
case node['platform_family']
when "debian"  
  if node['platform_version'].to_f >= 12.04
      node.set['megam']['start']['upstart'] = true  
  end
end

execute "sudo -s"

#['megam']['env']['home'] and ['megam']['start']['name'] must be same
node.set['megam']['env']['home'] = "#{node['megam']['lib']['home']}/#{node['megam']['deps']['component']['name']}"
include_recipe "megam_environment"

node.set['megam']['start']['name'] = "nodejs"
node.set['megam']['component']['name'] = "#{node['megam']['deps']['component']['name']}"
node.set['megam']['start']['pwd'] = "#{node['megam']['user']['home']}/#{dir}"
node.set['megam']['start']['cmd'] = "./start"

include_recipe "megam_start"
include_recipe "megam_nginx"


