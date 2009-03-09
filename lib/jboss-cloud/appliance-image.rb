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

require 'rake/tasklib'
require 'jboss-cloud/appliance-vmx-image'
require 'progressbar/progressbar'
require 'yaml'
require 'thread'

module JBossCloud
  class ApplianceImage < Rake::TaskLib
    
    def initialize( config, appliance_config )
      @config           = config
      @appliance_config = appliance_config
      
      define
    end
    
    def define
      @appliance_build_dir     = "#{@build_dir}/appliances/#{@config.arch}/#{@config.name}"
      kickstart_file          = "#{@appliance_build_dir}/#{@config.name}.ks"
      xml_file                = "#{@appliance_build_dir}/#{@config.name}.xml"
      super_simple_name       = File.basename( @config.name, '-appliance' )

      desc "Build #{super_simple_name} appliance."
      task "appliance:#{@config.name}"=>[ xml_file ]

      tmp_dir = "#{Dir.pwd}/#{@build_dir}/tmp"

      directory tmp_dir
      
      for appliance_name in @appliance_config.appliances
        task "appliance:#{@appliance_config.name}:rpms" => [ "rpm:#{appliance_name}" ]  
      end
      
      file xml_file => [ kickstart_file, "appliance:#{@appliance_config.name}:rpms", tmp_dir ] do
        Rake::Task[ 'rpm:repodata:force' ].invoke
        show_progressbar
        
        command = "sudo PYTHONUNBUFFERED=1 appliance-creator -d -v -t #{tmp_dir} --cache=#{@config.dir_rpms_cache}/#{@appliance_config.main_path} --config #{kickstart_file} -o #{@config.dir_build}/appliances/#{@appliance_config.main_path} --name #{@appliance_config.name} --vmem #{@appliance_config.mem_size} --vcpu #{@appliance_config.vcpu}"

        execute_command( command )
        
      end
      
      ApplianceVMXImage.new( @config, @appliance_config )
      
    end

    def show_progressbar
      t = Thread.new do
        disk_file = "#{@appliance_build_dir}/#{@config.name}-sda.raw"
        sleep_time = 0.05
        
        #while !File.exists?( disk_file )
        #  sleep( 1 )
        #end

        pbar = ProgressBar.new("#{@config.name}-sda.raw", @config.disk_size)

        200.times {
          sleep( sleep_time )
          pbar.inc #( File.size( disk_file ) / ( 1024 * 1024) )
        }

        pbar.finish
      end
    end
  end
end
