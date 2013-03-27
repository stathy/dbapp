#!/bin/bash

watch --differences "knife search node 'apps_dbapp:* AND apps_dbapp_rolling_deploy:* AND apps_dbapp_rolling_deploy_leg:*' --format json | ruby deploy_monitor.rb"

