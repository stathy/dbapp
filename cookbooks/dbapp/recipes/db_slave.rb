#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: dbapp
# Recipe:: db_slave
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

template "#{node['mysql']['conf_dir']}/my.cnf" do
  source "my.cnf.erb"
end

dbapp_orchestrate_db "configure slave to master" do
  app_name 'dbapp'
  db_platform 'mysql'

  action :configure_slave
end

ruby_block "rm db_slave from runlist" do
  block do
    Chef::Log.info("Obtained replication info, removing recipe[dbapp::db_slave]")
    node.run_list.remove("recipe[dbapp::db_slave]")
  end
  action :create
end
