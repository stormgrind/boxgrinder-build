require 'rake/tasklib'

module JBossCloud
  class Topdir < Rake::TaskLib

    def initialize( config )
      @config = config
      
      @topdir = @config.dir_top
      @arches = SUPPORTED_ARCHES + [ "noarch" ]
      @oses   = SUPPORTED_OSES

      define
    end

    def define

      for os in @oses.keys
        for version in @oses[os]
          directory "#{@topdir}/#{os}/#{version}/tmp"
          directory "#{@topdir}/#{os}/#{version}/SPECS"
          directory "#{@topdir}/#{os}/#{version}/SOURCES"
          directory "#{@topdir}/#{os}/#{version}/BUILD"
          directory "#{@topdir}/#{os}/#{version}/RPMS"
          directory "#{@topdir}/#{os}/#{version}/SRPMS"

          #desc "Create the RPM build topdir"
          task "rpm:topdir" => [
            "#{@topdir}/#{os}/#{version}/tmp",
            "#{@topdir}/#{os}/#{version}/SPECS",
            "#{@topdir}/#{os}/#{version}/SOURCES",
            "#{@topdir}/#{os}/#{version}/BUILD",
            "#{@topdir}/#{os}/#{version}/RPMS",
            "#{@topdir}/#{os}/#{version}/SRPMS",
          ]

          for arch in @arches
            directory "#{@topdir}/#{os}/#{version}/RPMS/#{arch}"

            task "rpm:topdir" => [ "#{@topdir}/#{os}/#{version}/RPMS/#{arch}" ]
          end
        end
      end    

      JBossCloud::Repodata.new( @config )
    end
  end
end
