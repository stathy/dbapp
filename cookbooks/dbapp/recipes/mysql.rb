#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: dbapp
# Recipe:: mysql
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

node.default['apps']['dbapp']['tier'] << 'db'

app = node['apps']['dbapp']

service "mysql" do
  retries 5
  retry_delay 3
end

rolling_deploy_integrate_db "configure slave to master" do
  app_name 'dbapp'
  db_platform 'mysql'

  action :configure_slave

  only_if { node['mysql'].has_key?('replication') && node['mysql']['replication']['type'].match('slave') }
end

rolling_deploy_integrate_db "get and set sync point" do
  app_name 'dbapp'
  db_platform 'mysql'
  action :nothing
  
  retries 2
  retry_delay 5

  subscribes :query_sync_point!, resources('service[mysql]'), :immediately

  only_if { node['mysql'].has_key?('replication') && node['mysql']['replication']['type'].match('master') }
end

template "#{node['mysql']['conf_dir']}/my.cnf" do
  cookbook 'dbapp'
  source "my.cnf.erb"
end

%w{ root repl debian }.each do |user|
  user_pw = node['mysql']["server_#{user}_password"]

  if user_pw.nil?
    log "A password for MySQL user #{user} was not found in attribute node['mysql']['server_#{user}_password']" do
      level :warn
    end
    log "A random password will be generated by the mysql cookbook and added as node['mysql']['server_#{user}_password']." do
      level :warn
    end
  end
end

include_recipe 'mysql::server'

grants_path = value_for_platform(
  ["centos", "redhat", "suse", "fedora" ] => {
    "default" => "/etc/mysql_app_grants.sql"
  },
  "default" => "/etc/mysql/app_grants.sql"
)

template "/etc/mysql/app_grants.sql" do
  path grants_path
  source "app_grants.sql.erb"
  owner "root"
  group "root"
  mode "0600"
  action :create
  variables :db => node['apps']['dbapp']['db']
end

execute "mysql install dbapp privileges" do
  command %Q(/usr/bin/mysql -u root -p"#{node['mysql']['server_root_password']}" < #{grants_path})
  action :nothing

  subscribes :run, resources(:template => "/etc/mysql/app_grants.sql"), :immediately
end

remote_file 'dbapp sql artifact' do
  path "/tmp/#{app['db_checksum']}.sql"
  source app['db_source']
  mode "0644"
  checksum app['db_checksum']

  action :nothing
end

#This needs to be converted to LWRP's and have the db driver driven through attributes
execute "init database" do
  command %Q(/usr/bin/mysql -u root -p#{node['mysql']['server_root_password']} -e "CREATE DATABASE IF NOT EXISTS #{node['apps']['dbapp']['db']['name']};")
  action :run
end

execute "load schema '/tmp/#{app['db_checksum']}.sql'" do
  command %Q(/usr/bin/mysql -u #{node['apps']['dbapp']['db']['username']} -p#{node['apps']['dbapp']['db']['password']} #{node['apps']['dbapp']['db']['name']} < /tmp/#{app['db_checksum']}.sql)

  action :nothing
  
  subscribes :run, resources('remote_file[dbapp sql artifact]')
end
