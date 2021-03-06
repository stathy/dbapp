#
# Author:: Stathy Touloumis <stathy@opscode.com>
# CreatedBy:: Stathy Touloumis <stathy@opscode.com>
#
# Cookbook Name:: dbapp
# Attributes:: dbapp
#
# Copyright 2012, Opscode, Inc.
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

require 'date'

normal['haproxy']['admin']['address_bind'] = "0.0.0.0"
normal['haproxy']['member_port'] = "8080"
default['haproxy']['search']['retries'] = 3
default['haproxy']['search']['retry_delay'] = 5

normal['mysql']['bind_address'] = node['ipaddress_internal']
normal['mysql']['server_root_password'] = "mysql_root"
normal['mysql']['server_repl_password'] = "mysql_repl"
normal['mysql']['server_debian_password'] = "mysql_debian"
default['mysql']['search']['retries'] = 3
default['mysql']['search']['retry_delay'] = 5

default['apps']['dbapp']['search']['retries'] = 3
default['apps']['dbapp']['search']['retry_delay'] = 5
default['apps']['dbapp']['tier'] = []

default["apps"]['dbapp']['desired'] = '7d93e08aa3f8cccbd95baaf719256b1cbf0401e274281316143631d6669729a1'
default['apps']['dbapp']['source'] = 'http://chef.localdomain:10080/artifacts/dbapp.war'
default['apps']['dbapp']['checksum'] = '7d93e08aa3f8cccbd95baaf719256b1cbf0401e274281316143631d6669729a1'
default['apps']['dbapp']['db_source'] = 'http://chef.localdomain:10080/artifacts/dbapp.sql'
default['apps']['dbapp']['db_checksum'] = 'e58440eb202309218aab43402f7d6c98204ab5a62e60e4de5fed909d9524d13e'
default["apps"]['dbapp']['rolling_deploy']['andon_cord'] = false


default['apps']['dbapp']['deploy_to'] = "/srv/dbapp"
default['apps']['dbapp']['owner'] = "nobody"
default['apps']['dbapp']['group'] = "nogroup"

default['apps']['dbapp']['db']['type'] = 'master'
default['apps']['dbapp']['db']['adapter'] = "mysql"
default['apps']['dbapp']['db']['driver'] = "com.mysql.jdbc.Driver"
default['apps']['dbapp']['db']['name'] = "dbapp_production"
default['apps']['dbapp']['db']['max_active'] = 50
default['apps']['dbapp']['db']['max_idle'] = 50
default['apps']['dbapp']['db']['max_wait'] = 10000
default['apps']['dbapp']['db']['port'] = 3306
default['apps']['dbapp']['db']['username'] = "dbapp"
default['apps']['dbapp']['db']['password'] = "awesome_password"

yesterday = Date.today - 2
default['expiration'] = yesterday
