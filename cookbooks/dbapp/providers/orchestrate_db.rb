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
  if node['apps'][ @new_resource.app_name ]['tier'].include?('db')
    dbm = node
    node.save

  else
    dbm = search("node", %Q(apps_#{@new_resource.app_name}_tier:db AND apps_#{@new_resource.app_name}_db_type:master AND chef_environment:#{node.chef_environment}) ).last
#    dbm = search("node", @new_resource.solr_query).last

  end

  if dbm.nil?
    raise( %Q(Unable to find database host where attribute node['apps']['#{@new_resource.app_name}']['tier'] contains 'db') )

  else
    server_ip = begin
      if @new_resource.return_val.downcase == 'ip' then
        if dbm.has_key?('ipaddress_internal')
          dbm['ipaddress_internal']
        elsif dbm.has_key?('ec2')
          dbm['ec2']['public_ipv4']
        elsif ! dbm['ipaddress'].nil?
          dbm['ipaddress']
        else
          dbm['fqdn']
        end
      else
        dbm['fqdn']
      end
    end

    Chef::Log.info( %Q(Database server is '#{server_ip}') )
    node.run_state['dbapp_orchestrate_db::dbm'] = server_ip
    @new_resource.updated_by_last_action(true)

  end

end


def load_current_resource
  @current_resource = Chef::Resource::DbappOrchestrateDb.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource
end


__END__

