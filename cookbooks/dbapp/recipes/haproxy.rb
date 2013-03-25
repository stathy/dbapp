#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: dbapp
# Recipe:: haproxy
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

node.default['apps']['dbapp']['tier'] << 'lb'

app = node['apps']['dbapp']

include_recipe 'haproxy::default'

rolling_deploy_integrate_app "search for tomcat" do
  app_name 'dbapp'
  action :nothing

  retries node['haproxy']['search']['retries']
  retry_delay node['haproxy']['search']['retry_delay']

#  only_if { node.run_state['dbapp_integrate_app::members'].nil? }
end.run_action(:search_set_lb!)

template "/etc/haproxy/haproxy.cfg" do
  pool_members = node.run_state['dbapp_integrate_app::members'] || []

  cookbook 'haproxy'
  source "haproxy-app_lb.cfg.erb"
  variables(
    :pool_members => pool_members,
    :defaults_options => defaults_options,
    :defaults_timeouts => defaults_timeouts
  )

  notifies :stop, "service[haproxy]"
  notifies :start, "service[haproxy]"
end

