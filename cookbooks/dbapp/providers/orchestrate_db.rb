#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: dbapp
# Provider:: orchestrate_db
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

action :search do
  dbm = nil
  name = @new_resource.app_name

  if @new_resource.single == true && node['apps'][ name ]['tier'].include?('db') && node['apps'][ name ]['tier'].include?('app')
    dbm = node
    node.save

  else
    solr_qry = <<SOLR.gsub(/\s+/,' ').strip
      chef_environment:#{node.chef_environment}
        AND apps:*
        AND apps_#{name}:*
        AND apps_#{name}_db:*
        AND apps_#{name}_tier:db
        AND apps_#{name}_db_type:master
SOLR
    Chef::Log.info( %Q(DB solr query '#{solr_qry}') )

    dbm = search("node", solr_qry ).last
#    dbm = search("node", @new_resource.solr_query).last

  end

  if dbm.nil?
    raise( %Q(Unable to find database host where attribute node['apps']['#{@new_resource.app_name}']['tier'] contains 'db') )

  else
    server_ip = begin
      if dbm['mysql'].has_key?('bind_address') && dbm['mysql']['bind_address'] !~  /^0\.0\.0\.0$/ then
        dbm['mysql']['bind_address']

      elsif dbm.has_key?('ipaddress_internal')
        dbm['ipaddress_internal']

      elsif dbm.has_key?('ec2')
        dbm['ec2']['public_ipv4']

      elsif ! dbm['ipaddress'].nil?
        dbm['ipaddress']

      else
        dbm['fqdn']
      end
    end

    dbm_info = {
      'fqdn'      => dbm['fqdn'],
      'server_ip' => server_ip,
    }
    if dbm['mysql'].include?('replication') then
      dbm_info['log_file'] = dbm['mysql']['replication']['log_file']
      dbm_info['position'] = dbm['mysql']['replication']['position']
    end
    node.run_state['dbapp_orchestrate_db::dbm'] = dbm_info

    @new_resource.updated_by_last_action(true)

  end

end

action :configure_slave do
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

  dbapp_orchestrate_db "dbapp_orchestrate_db - search for master" do
    app_name new_resource.app_name
    action :nothing
  
    retries node['mysql']['search']['retries']
    retry_delay node['mysql']['search']['retry_delay']
  
    only_if { node.run_state['dbapp_orchestrate_db::dbm'].nil? }
  end.run_action(:search)

  bind_vars = node.run_state['dbapp_orchestrate_db::dbm']
  Chef::Log.warn( %Q(Set sync info for slave '#{bind_vars.to_s}') )

  set_master_sql = <<SQL
    STOP SLAVE ;

    CHANGE MASTER TO
      MASTER_HOST = '#{bind_vars["server_ip"]}',
      MASTER_USER = 'repl',
      MASTER_PASSWORD = '#{node["mysql"]["server_repl_password"]}',
      MASTER_LOG_FILE = '#{bind_vars["log_file"]}',
      MASTER_LOG_POS = #{bind_vars["position"]} ;

    START SLAVE ;
SQL

  Chef::Log.debug("Performing query [#{set_master_sql}]")

  dbh_of_root.query( set_master_sql )
  dbh_of_root.close
end

action :configure_sync_point do
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
  data = rslt.fetch_row || raise( %Q(Not configured for replication, please see database docs) )
  dbh_of_root.close

  Chef::Log.warn("Obtained sync info for slaves [#{data[0,1].to_s}]")
  node.normal['mysql']['replication']['log_file'] = data[0]
  node.normal['mysql']['replication']['position'] = data[1]

  @new_resource.updated_by_last_action(true)
end


def load_current_resource
  Gem.clear_paths
  require 'mysql'

  @current_resource = Chef::Resource::DbappOrchestrateDb.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  @current_resource
end


__END__

