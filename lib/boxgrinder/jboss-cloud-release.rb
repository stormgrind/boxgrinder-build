# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'rake'
require 'rake/tasklib'
require 'boxgrinder/exec'

module BoxGrinder
  class BoxGrinderRelease < Rake::TaskLib
    def initialize( config )
      @config = config

      @file_name                    = "boxgrinder-release"
      @file_name_with_extension     = "#{@file_name}.tar.gz"
      @release_source               = "#{@config.dir.top}/#{@config.os_path}/SOURCES/#{@file_name_with_extension}"
      @jboss_cloud_spec_base_file   = "#{@config.dir.base}/specs/gsub/boxgrinder-release.spec"
      @jboss_cloud_spec_file        = "#{@config.dir.top}/#{@config.os_path}/SPECS/boxgrinder-release.spec"

      define_tasks
    end

    def define_tasks
      task 'rpm:boxgrinder-release' => [ @release_source ]

      file @release_source => [ 'rpm:topdir' ] do
        create_source_for_jboss_cloud_release_rpm
      end
    end

    def create_source_for_jboss_cloud_release_rpm
      root_tmp_directory = "#{@config.dir.tmp}/#{@file_name}"
      tmp_directory = "#{root_tmp_directory}/#{@file_name}"

      FileUtils.rm_rf( root_tmp_directory )
      FileUtils.mkdir_p( tmp_directory )

      FileUtils.cp_r( "#{@config.dir.base}/src/#{@config.os_path}/boxgrinder-release/.", tmp_directory ) if ( File.exists?(File.dirname( "#{@config.dir.base}/src/#{@config.os_path}/boxgrinder-release" )) && File.directory?(File.dirname( "#{@config.dir.base}/src/#{@config.os_path}/boxgrinder-release" )) )
      FileUtils.cp_r( "#{@config.dir.base}/src/#{@config.os_name}/boxgrinder-release/.", tmp_directory ) if ( File.exists?(File.dirname( "#{@config.dir.base}/src/#{@config.os_name}/boxgrinder-release" )) && File.directory?(File.dirname( "#{@config.dir.base}/src/#{@config.os_name}/boxgrinder-release" )) )
      FileUtils.cp_r( "#{@config.dir.base}/src/boxgrinder-release/.", tmp_directory ) if ( File.exists?(File.dirname( "#{@config.dir.base}/src/boxgrinder-release" )) && File.directory?(File.dirname( "#{@config.dir.base}/src/boxgrinder-release" )) )

      Dir[ "#{tmp_directory}/*.repo" ].each do |repo_file|
        repo_definition = File.read( repo_file )

        repo_definition.gsub!( /#OS_NAME#/, @config.os_name )
        repo_definition.gsub!( /#OS_VERSION#/, @config.os_version )

        File.open( repo_file, "w") {|f| f.write( repo_definition ) }
      end

      Dir.chdir( root_tmp_directory ) do
        execute_command( "tar -czSpf #{@file_name_with_extension} #{@file_name}/*" )
      end

      FileUtils.cp( "#{root_tmp_directory}/#{@file_name_with_extension}", @release_source )
      FileUtils.rm_rf( root_tmp_directory )
    end
  end
end