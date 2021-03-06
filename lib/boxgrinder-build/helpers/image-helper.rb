#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
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

require 'fileutils'
require 'boxgrinder-build/helpers/guestfs-helper'

module BoxGrinder
  class ImageHelper
    def initialize(options = {})
      @log          = options[:log] || Logger.new(STDOUT)
      @exec_helper  = options[:exec_helper] || ExecHelper.new(:log => @log)
    end

    def mount_image(disk, mount_dir)
      offsets      = calculate_disk_offsets(disk)

      @log.debug "Mounting image #{File.basename(disk)} in #{mount_dir}..."
      FileUtils.mkdir_p(mount_dir)

      mounts       = {}

      offsets.each do |offset|
        loop_device   = get_loop_device
        @exec_helper.execute("losetup -o #{offset.to_s} #{loop_device} #{disk}")
        label         = @exec_helper.execute("e2label #{loop_device}").strip.chomp.gsub('_', '')
        label = '/' if label == ''
        mounts[label] = loop_device
      end

      @exec_helper.execute("mount #{mounts['/']} -t #{get_filesystem_type(mounts['/'])} #{mount_dir}")

      mounts.reject { |key, value| key == '/' }.each do |mount_point, loop_device|
        @exec_helper.execute("mount #{loop_device} -t #{get_filesystem_type(loop_device)} #{mount_dir}#{mount_point}")
      end

      @log.trace "Mounts:\n#{mounts}"

      mounts
    end

    def get_filesystem_type(device, default_type = 'ext3')
      fs_type = @exec_helper.execute("df -T #{device} | tail -1 | awk '{print $2}'")
      return default_type if fs_type.empty? or fs_type == '-'
      fs_type
    end

    def umount_image(disk, mount_dir, mounts)
      @log.debug "Unmounting image '#{File.basename(disk)}'..."

      mounts.each { |mount_point, loop_device| @exec_helper.execute("umount -d #{loop_device}") unless mount_point == '/' }

      @exec_helper.execute("umount -d #{mounts['/']}")

      FileUtils.rm_rf(mount_dir)
    end

    def get_loop_device
      begin
        loop_device = @exec_helper.execute("losetup -f 2>&1").strip
      rescue
        raise "No free loop devices available, please free at least one. See 'losetup -d' command."
      end

      loop_device
    end

    def calculate_disk_offsets(disk)
      @log.debug "Calculating offsets for '#{File.basename(disk)}' disk..."
      loop_device = get_loop_device

      @exec_helper.execute("losetup #{loop_device} #{disk}")
      offsets     = @exec_helper.execute("parted #{loop_device} 'unit B print' | grep -e '^ [0-9]' | awk '{ print $2 }'").scan(/\d+/)
      @exec_helper.execute("losetup -d #{loop_device}")

      @log.trace "Offsets:\n#{offsets}"

      offsets
    end

    def create_disk(disk, size)
      @log.trace "Preparing disk..."
      @exec_helper.execute "dd if=/dev/zero of=#{disk} bs=1 count=0 seek=#{size * 1024}M"
      @log.trace "Disk prepared"
    end

    def create_filesystem(disk, options = {})
      options = {:type => 'ext3', :label => '/'}.merge(options)

      @log.trace "Creating filesystem..."
      @exec_helper.execute "mke2fs -T #{options[:type]} -L '#{options[:label]}' -F #{disk}"
      @log.trace "Filesystem created"
    end

    def sync_files(from_dir, to_dir)
      @log.debug "Syncing files between #{from_dir} and #{to_dir}..."
      @exec_helper.execute "rsync -u -r -a #{from_dir}/* #{to_dir}"
      @log.debug "Sync finished."
    end

    def customize(disk_path)
      GuestFSHelper.new(disk_path, :log => @log).customize do |guestfs, guestfs_helper|
        yield guestfs, guestfs_helper
      end
    end
  end
end
