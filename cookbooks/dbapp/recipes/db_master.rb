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

rolling_deploy_orchestrate_db "get and set sync point" do
  app_name 'dbapp'
  db_platform 'mysql'
  action :nothing
  
  retries 2
  retry_delay 5

  subscribes :query_sync_point!, resources('service[mysql]'), :immediately
end

ruby_block "rm db_master from runlist" do
  block do
    Chef::Log.info("Obtained replication info, removing recipe[dbapp::db_master]")
    node.run_list.remove("recipe[dbapp::db_master]")
  end
  action :create

end
