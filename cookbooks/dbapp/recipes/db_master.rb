#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: dbapp
# Recipe:: db_master
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

include_recipe "mysql::ruby"

Gem.clear_paths
require 'mysql'

ruby_block "get master replication file and pos" do
  block do
    dbh_of_root = begin
      connection = ::Mysql.new(
        'localhost',
        'root',
        node['mysql']['server_root_password'],
        nil,
        node['mysql']['port']
      )
      connection.set_server_option ::Mysql::OPTION_MULTI_STATEMENTS_ON
      connection
    end

    dbh_of_root.query("FLUSH TABLES WITH READ LOCK")

    obtain_sync_sql = <<SQL
      SHOW MASTER STATUS
SQL

    Chef::Log.warn("Performing query [#{obtain_sync_sql}]")
  
    rslt = dbh_of_root.query( obtain_sync_sql )
    data = rslt.fetch_row
    rslt.free
    dbh_of_root.close

    Chef::Log.warn("Obtained sync info for slaves [#{data[0,1].to_s}]")
    node.normal['mysql']['replication']['log_file'] = data[0]
    node.normal['mysql']['replication']['position'] = data[1]
  end

  action :create
end

ruby_block "rm db_master from runlist" do
  block do
    Chef::Log.info("Obtained replication info, removing recipe[dbapp::db_master]")
    node.run_list.remove("recipe[dbapp::db_master]")
  end
  action :create

#  subscribes :create, resources('ruby_block[get master replication file and pos]')
end
