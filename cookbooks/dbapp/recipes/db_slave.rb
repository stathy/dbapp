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

include_recipe "mysql::ruby"

Gem.clear_paths
require 'mysql'

db_search = ruby_block "search for master" do
  block do
    dbm = search("node", "mysql_replication_type:master AND chef_environment:#{node.chef_environment} NOT name:#{node.name}").first

    if dbm.nil?
      node.save
      raise( %Q(Unable to find database host where attribute node['mysql']['replication']['type'] is 'master') )

    else
      server_ip = begin
        if dbm.has_key?('ipaddress_internal')
          dbm['ipaddress_internal']
        elsif dbm.has_key?('ec2')
          dbm['ec2']['public_ipv4']
        elsif ! dbm['ipaddress'].nil?
          dbm['ipaddress']
        else
          dbm['fqdn']
        end
      end
      Chef::Log.info( %Q(Database server ip is "#{server_ip}") )
      node.run_state['master_node'] = [
        server_ip,
        'repl',
        dbm['mysql']['server_repl_password'],
        dbm['mysql']['replication']['log_file'],
        dbm['mysql']['replication']['position']
      ]
      
    end
  end

  action :nothing

  retries node['mysql']['search']['retries']
  retry_delay node['mysql']['search']['retry_delay']

end
db_search.run_action(:create)

ruby_block "assign master to slave" do
  block do
    bind_vars = node.run_state['master_node']

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

    set_master_sql = <<SQL
      STOP SLAVE ;

      CHANGE MASTER TO
        MASTER_HOST = '#{bind_vars[0]}',
        MASTER_USER = '#{bind_vars[1]}',
        MASTER_PASSWORD = '#{bind_vars[2]}',
        MASTER_LOG_FILE = '#{bind_vars[3]}',
        MASTER_LOG_POS = #{bind_vars[4]} ;

      START SLAVE ;
SQL
  
    Chef::Log.debug("Performing query [#{set_master_sql}]")

    dbh_of_root.query( set_master_sql )
    dbh_of_root.close

    Chef::Log.warn( %Q(Set sync info for slave '#{bind_vars[0,1].to_s}, <password>, #{bind_vars[3,4].to_s}') )
  end

  action :create
  
  not_if { node.run_state['master_node'].nil? }
end

ruby_block "rm db_slave from runlist" do
  block do
    Chef::Log.info("Obtained replication info, removing recipe[dbapp::db_slave]")
    node.run_list.remove("recipe[dbapp::db_slave]")
  end
  action :create

#  subscribes :create, resources('ruby_block[assign master to slave]')
end
