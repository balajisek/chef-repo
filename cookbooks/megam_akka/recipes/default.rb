#
# Cookbook Name:: megam_akka
# Recipe:: default
#
# Copyright 2013, Megam Systems
#
# All rights reserved - Do Not Redistribute
#


include_recipe "megam_sandbox"

package "zip unzip" do
        action :install
end

package "tar" do
        action :install
end

include_recipe "megam_sandbox"
include_recipe "apt"
include_recipe "nginx"
#ONLY FOR THIS COOKBOOK JDK
#USES JAVA IMAGE
#=begin
package "openjdk-7-jdk" do
        action :install
end
#=end

=begin
execute "SET JAVA_HOME" do
  cwd "/home/ubuntu/"  
  user "ubuntu"
  group "ubuntu"
  command "echo \"export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64\" >> /home/ubuntu/.bashrc"
end
=end


node.set["myroute53"]["name"] = "#{node.name}"
include_recipe "megam_route53"

#node.set[:ganglia][:server_gmond] = "162.248.165.65"
include_recipe "megam_ganglia"

node.set["deps"]["node_key"] = "#{node.name}"
include_recipe "megam_deps"


node.set['logstash']['key'] = "#{node.name}"
node.set['logstash']['redis_url'] = "redis1.megam.co.in"
node.set['logstash']['beaver']['inputs'] = [ "/var/log/upstart/akka.log", "/var/log/upstart/gulpd.log" ]
include_recipe "megam_logstash::beaver"


node.set['rsyslog']['index'] = "#{node.name}"
node.set['rsyslog']['elastic_ip'] = "monitor.megam.co"
node.set['rsyslog']['input']['files'] = [ "/var/log/upstart/akka.log", "/var/log/upstart/gulpd.log" ]
include_recipe "megam_logstash::rsyslog"




=begin
gem_package "knife-ec2" do
  action :install
end
=end

scm_ext = File.extname(node["megam_deps"]["predefs"]["scm"])
file_name = File.basename(node["megam_deps"]["predefs"]["scm"])
dir = File.basename(file_name, '.*')

if scm_ext.empty?
  scm_ext = ".git"
end


node.set["gulp"]["remote_repo"] = node["megam_deps"]["predefs"]["scm"]
node.set["gulp"]["project_name"] = "#{dir}"


directory "/usr/local/share/#{dir}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

case scm_ext
when ".git"
include_recipe "git"
execute "Clone git " do
  cwd node["sandbox"]["home"]  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "git clone #{node["megam_deps"]["predefs"]["scm"]}"
end


directory "#{node["sandbox"]["home"]}/bin" do
  owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
  mode "0755"
  action :create
end

execute "add PATH for bin sbt" do
  cwd node["sandbox"]["home"]  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "echo \"PATH=$PATH:$HOME/bin\" >> #{node["sandbox"]["home"]}/.bashrc"
end

execute "Refresh bashrc" do
  cwd node["sandbox"]["home"]  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "source .bashrc"
end

remote_file "#{node["sandbox"]["home"]}/bin/sbt-launch.jar" do
  source node["akka"]["sbt"]["jar"]
  mode "0755"
   owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
  checksum "08da002l" 
end

template "#{node["sandbox"]["home"]}/bin/sbt" do
  source "sbt.erb"
  owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
  mode "0755"
end


execute "Stage play project" do
  cwd "#{node["sandbox"]["home"]}/#{dir}"  
  user node["sandbox"]["user"]
  group node["sandbox"]["user"]
  command "sbt clean compile stage dist"
end


execute "Copy zip to /usr/local/share" do
  cwd "#{node["sandbox"]["home"]}/#{dir}"  
  user "root"
  group "root"
  command "cp #{node["sandbox"]["home"]}/#{dir}/dist/*.zip /usr/local/share/#{dir} "
end

execute "Unzip dist content " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "unzip *.zip"
end

execute "Chmod for start script " do
  cwd "/usr/local/share/#{dir}/*" #DONT KNOW THE DIR NAME 
  user "root"
  group "root"
  command "chmod 755 start"
end


when ".zip"

remote_file "/usr/local/share/#{dir}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner "root"
  group "root"
end

execute "Unzip dist content " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "unzip *.zip"
end

node.set["akka"]["dir"]["script"] = "/usr/local/share/#{dir}/*"
node.set["akka"]["file"]["script"] = "start"

execute "Chmod for start script " do
  cwd "/usr/local/share/#{dir}/#{dir}" #DONT KNOW THE DIR NAME 
  user "root"
  group "root"
  command "chmod 755 start"
end

when ".tar"

remote_file "/usr/local/share/#{dir}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner "root"
  group "root"
end

execute "Untar tar file " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "tar -xvzf #{file_name}"
end

node.set['akka']['script']['cmd'] = "/usr/local/share/#{dir}/#{dir}/bin/start org.megam.akka.CloApp"

when ".gz"

file_name = File.basename(file_name, '.*')
dir = File.basename(file_name, '.*')

directory "/usr/local/share/#{dir}" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

remote_file "/usr/local/share/#{dir}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner "root"
  group "root"
end

execute "Untar tar file " do
  cwd "/usr/local/share/#{dir}"  
  user "root"
  group "root"
  command "tar -xvzf #{file_name}"
end

node.set['akka']['script']['cmd'] = "/usr/local/share/#{dir}/#{dir}/bin/start org.megam.akka.CloApp"


when ".deb"

remote_file "#{node["sandbox"]["home"]}/#{file_name}" do
  source node["megam_deps"]["predefs"]["scm"]
  mode "0755"
  owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
end

execute "Depackage deb file" do
  cwd node["sandbox"]["home"]  
  user "root"
  group "root"
  command "dpkg -i #{file_name}"
end

else
remote_file "#{node["sandbox"]["home"]}/megamherk.deb" do
  source node['akka']['deb']
  owner node["sandbox"]["user"]
  group node["sandbox"]["user"]
  mode node['akka']['mode']
end

execute "Depackage megam akka" do
  cwd node["sandbox"]["home"]  
  user "root"
  group "root"
  command node['akka']['dpkg']
end
end #case

template node['akka']['init']['conf'] do
  source node['akka']['template']['conf']
  owner "root"
  group "root"
  mode node['akka']['mode']
end

include_recipe "megam_gulp"

execute "Start Akka" do
  user "root"
  group "root"
  command node['akka']['start']
end

