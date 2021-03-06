#
# Cookbook Name:: omeka
# Recipe:: default
#
# Copyright (c) 2016 Harvard ATG, All Rights Reserved.
#
user node['omeka']['owner'] do
  action :create
  comment 'Omeka User'
end

directory node['omeka']['directory'] do
  owner node['omeka']['owner']
  group node['apache']['owner']
  mode '0755'
  recursive true
  action :create
end

omeka_zip = "#{Chef::Config['file_cache_path'] || '/tmp'}/omeka-#{node['omeka']['version']}.zip"
remote_file omeka_zip do
  owner node['omeka']['owner']
  mode '0644'
  source "#{node['omeka']['location'] + node['omeka']['version']}.zip"
end

package 'unzip'

omeka_unzip_folder = "omeka-#{node['omeka']['version']}"

bash 'unzip omeka' do
  cwd ::File.dirname(omeka_zip)
  code <<-EOH
    unzip -qo #{omeka_zip};
    rm -rf #{omeka_unzip_folder}/db.ini;
    chown -R #{node['omeka']['owner']} #{omeka_unzip_folder}
  EOH
  not_if { ::File.directory?(omeka_zip) }
end

bash 'copy files' do
  user node['omeka']['owner']
  cwd ::File.dirname(omeka_zip)
  code <<-EOH
    shopt -s dotglob;
    cp -r #{omeka_unzip_folder}/* #{node['omeka']['directory']};
  EOH
end

template "#{node['omeka']['directory']}db.ini" do
  source 'db.ini.erb'
  owner node['omeka']['owner']
  mode '0444'
  action :create
end

directory "#{node['omeka']['directory']}files" do
  owner node['apache']['user']
  group node['omeka']['owner']
  mode '0755'
  action :create
end

omeka_dirs = %w(fullsize original square_thumbnails theme_uploads thumbnails)
omeka_dirs.each do |omeka_dir|
  directory "#{node['omeka']['directory']}files/#{omeka_dir}" do
    owner node['apache']['user']
    group node['omeka']['owner']
    mode '0755'
    action :create
  end
end

# Install php support for mysql
# APC and dependacies
#

case node['platform_family']
when 'rhel', 'fedora'
  %w( zlib-devel httpd-devel pcre pcre-devel php-mysql php-gd ).each do |pkg|
    package pkg do
      action :install
    end
  end
when 'debian'
  %w( php5-memcache php5-gd php5-mysql ).each do |pkg|
    package pkg do
      action :upgrade
    end
  end
end

# APC and dependacies
=begin
php_pear 'apc' do
  action :install
  directives(
#    shm_segments: node['omeka']['apc']['shm_segments'],
    shm_size: node['omeka']['apc']['shm_size '],
    ttl: node['omeka']['apc']['ttl'],
    user_ttl: node['omeka']['apc']['user_ttl'],
    enable_cli: node['omeka']['apc']['enable_cli'],
    stat: node['omeka']['apc']['stat'],
    stat_ctime: node['omeka']['apc']['stat_ctime'],
    lazy_classes: node['omeka']['apc']['lazy_classes'],
    lazy_functions: node['omeka']['apc']['lazy_functions'],
    write_lock: node['omeka']['apc']['write_lock'],
    rfc1867: node['omeka']['apc']['rfc1867']
  )
  only_if node['php']['version'].to_f > 5.5
end

=end

# Install the mysql client.
#

include_recipe 'omeka::mysql_server' if node['omeka']['install_local_mysql_server']

mysql_client 'default' do
  action :create
end

include_recipe 'omeka::database' if node['omeka']['create_db']

web_app 'omeka' do
  server_name node['hostname']
  docroot node['omeka']['directory']
  allow_override 'All'
  directory_index 'false'
  notifies :reload, 'service[apache2]', :delayed
end
