#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: dbapp
# Recipe:: tomcat
#
# Copyright 2009-2013, Opscode, Inc.
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
# This is potentially destructive to the nodes mysql password attributes, since
# we iterate over all the app databags. If this database server provides
# databases for multiple applications, the last app found in the databags
# will win out, so make sure the databags have the same passwords set for
# the root, repl, and debian-sys-maint users.
#

include_recipe "tomcat"

node.default['apps']['dbapp']['tier'] << 'app'

app = node['apps']['dbapp']

# remove ROOT application
# TODO create a LWRP to enable/disable tomcat apps
directory "#{node['tomcat']['webapp_dir']}/ROOT" do
  recursive true
  action :delete

  not_if "test -L #{node['tomcat']['context_dir']}/ROOT.xml"
end

link "#{node['tomcat']['context_dir']}/ROOT.xml" do
  to "#{app['deploy_to']}/shared/dbapp.xml"

  notifies :stop, resources('service[tomcat]')
  notifies :start, resources('service[tomcat]')
end

directory app['deploy_to'] do
  owner app['owner']
  group app['group']
  mode '0755'
  recursive true
end

directory "#{app['deploy_to']}/releases" do
  owner app['owner']
  group app['group']
  mode '0755'
  recursive true
end

directory "#{app['deploy_to']}/shared" do
  owner app['owner']
  group app['group']
  mode '0755'
  recursive true
end

%w{ log pids system }.each do |dir|

  directory "#{app['deploy_to']}/shared/#{dir}" do
    owner app['owner']
    group app['group']
    mode '0755'
    recursive true
  end

end

rolling_deploy_orchestrate_db "search for db" do
  app_name 'dbapp'
  action :nothing

  retries app['search']['retries']
  retry_delay app['search']['retry_delay']

  only_if { node.run_state['dbapp_orchestrate_db::dbm'].nil? }
end.run_action(:search_set_db!)

template "#{app['deploy_to']}/shared/dbapp.xml" do
  dbm = node.run_state['dbapp_orchestrate_db::dbm']

  source "context.xml.erb"
  owner app['owner']
  group app['group']
  mode "644"
  variables(
    :host => dbm['server_ip'],
    :app => 'dbapp',
    :database => app['db'],
    :war => "#{app['deploy_to']}/releases/#{app['checksum']}.war"
  )
  
  action :create
  
  notifies :stop, resources('service[tomcat]')
  notifies :start, resources('service[tomcat]')
end

directory "#{node['tomcat']['webapp_dir']}/ROOT" do
  recursive true
  action :nothing
end

remote_file 'dbapp artifacts' do
  path "#{app['deploy_to']}/releases/#{app['checksum']}.war"
  source app['source']
  mode "0644"
  checksum app['checksum']

  notifies :delete, resources("directory[#{node['tomcat']['webapp_dir']}/ROOT]")
end


